import Foundation
import Combine
import Supabase
import SwiftUI

// MARK: - Order Update DTO
struct OrderUpdate: Encodable {
    let mealIndex: Int
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case mealIndex = "meal_index"
        case sortOrder = "sort_order"
    }
}

private struct LoggedFoodIdRow: Decodable {
    let foodId: UUID?
    enum CodingKeys: String, CodingKey { case foodId = "food_id" }
}

final class LogService: ObservableObject {
    @Published var todayEntries: [FoodLogEntry] = []
    @Published var loggedFoodIds: Set<UUID> = []

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func dateString(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Total macros from entries (real-time, no server round-trip)
    var totalCalories: Float { todayEntries.reduce(0) { $0 + $1.calories } }
    var totalProtein: Float { todayEntries.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Float { todayEntries.reduce(0) { $0 + $1.carbs } }
    var totalFat: Float { todayEntries.reduce(0) { $0 + $1.fat } }

    // MARK: - Push snapshot to widget
    func pushToWidget(profile: Profile?, macroColors: MacroColors) {
        let calComps = UIColor(macroColors.calories).cgColor.components ?? [0.36, 0.61, 0.96, 1.0]
        let pComps   = UIColor(macroColors.protein).cgColor.components  ?? [0.42, 0.87, 0.72, 1.0]
        let cComps   = UIColor(macroColors.carbs).cgColor.components    ?? [0.69, 0.49, 1.0, 1.0]
        let fComps   = UIColor(macroColors.fat).cgColor.components      ?? [0.96, 0.64, 0.38, 1.0]

        let snapshot = MacroSnapshot(
            calories: totalCalories,
            calGoal: Float(profile?.calGoal ?? 2200),
            protein: totalProtein,
            proteinGoal: Float(profile?.proteinGoal ?? 160),
            carbs: totalCarbs,
            carbGoal: Float(profile?.carbGoal ?? 250),
            fat: totalFat,
            fatGoal: Float(profile?.fatGoal ?? 70),
            lastUpdated: Date(),
            caloriesColorR: Double(calComps[0]), caloriesColorG: Double(calComps[1]), caloriesColorB: Double(calComps[2]),
            proteinColorR: Double(pComps[0]), proteinColorG: Double(pComps[1]), proteinColorB: Double(pComps[2]),
            carbsColorR: Double(cComps[0]), carbsColorG: Double(cComps[1]), carbsColorB: Double(cComps[2]),
            fatColorR: Double(fComps[0]), fatColorG: Double(fComps[1]), fatColorB: Double(fComps[2])
        )
        SharedDefaults.save(snapshot)
    }

    // MARK: - Preload entries (returns without updating @Published)
    func preloadEntries(userId: UUID, date: Date) async -> [FoodLogEntry] {
        do {
            let entries: [FoodLogEntry] = try await supabase
                .from("food_log")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("log_date", value: dateString(for: date))
                .order("meal_index")
                .order("sort_order")
                .execute()
                .value
            return entries
        } catch {
            print("Preload entries error: \(error)")
            return []
        }
    }

    // MARK: - Load entries for a date
    @MainActor
    func loadEntries(userId: UUID, date: Date) async {
        do {
            let entries: [FoodLogEntry] = try await supabase
                .from("food_log")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("log_date", value: dateString(for: date))
                .order("meal_index")
                .order("sort_order")
                .execute()
                .value

            self.todayEntries = entries
        } catch {
            print("Load entries error: \(error)")
        }
    }

    // MARK: - Load distinct food_ids the user has ever logged
    @MainActor
    func loadLoggedFoodIds(userId: UUID) async {
        do {
            let rows: [LoggedFoodIdRow] = try await supabase
                .from("food_log")
                .select("food_id")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            self.loggedFoodIds = Set(rows.compactMap { $0.foodId })
        } catch {
            print("Load logged food ids error: \(error)")
        }
    }

    // MARK: - Add entry
    @MainActor
    func addEntry(userId: UUID, food: Food, grams: Float, mealIndex: Int = 0, date: Date = Date()) async {
        let macros = food.macros(forGrams: grams)
        let nextSort = (todayEntries.last?.sortOrder ?? -1) + 1
        let tempId = UUID()

        let insert = FoodLogInsert(
            userId: userId,
            logDate: dateString(for: date),
            mealIndex: mealIndex,
            sortOrder: nextSort,
            foodId: food.id,
            customFoodId: nil,
            foodName: food.name,
            grams: grams,
            calories: macros.calories,
            protein: macros.protein,
            carbs: macros.carbs,
            fat: macros.fat,
            isCount: food.isCount
        )

        // Optimistic insert — shows immediately
        let optimistic = FoodLogEntry(
            id: tempId,
            userId: userId,
            logDate: dateString(for: date),
            mealIndex: mealIndex,
            sortOrder: nextSort,
            foodId: food.id,
            customFoodId: nil,
            foodName: food.name,
            grams: grams,
            calories: macros.calories,
            protein: macros.protein,
            carbs: macros.carbs,
            fat: macros.fat,
            isCount: food.isCount
        )
        todayEntries.append(optimistic)

        do {
            let entry: FoodLogEntry = try await supabase
                .from("food_log")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            // Replace optimistic with real entry
            if let idx = todayEntries.firstIndex(where: { $0.id == tempId }) {
                todayEntries[idx] = entry
            }
            loggedFoodIds.insert(food.id)

            Task {
                await updateStreak(logDate: dateString(for: date))
            }
        } catch {
            // Remove optimistic on failure
            todayEntries.removeAll { $0.id == tempId }
            print("Add entry error: \(error)")
        }
    }

    // MARK: - Quick add (manual macros, no food reference)
    @MainActor
    func quickAdd(userId: UUID, name: String, calories: Float, protein: Float, carbs: Float, fat: Float, grams: Float = 0, mealIndex: Int = 0, date: Date = Date()) async {
        let nextSort = (todayEntries.last?.sortOrder ?? -1) + 1

        let insert = FoodLogInsert(
            userId: userId,
            logDate: dateString(for: date),
            mealIndex: mealIndex,
            sortOrder: nextSort,
            foodId: nil,
            customFoodId: nil,
            foodName: name,
            grams: grams,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            isCount: false
        )

        do {
            let entry: FoodLogEntry = try await supabase
                .from("food_log")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            todayEntries.append(entry)
        } catch {
            print("Quick add error: \(error)")
        }
    }

    // MARK: - Batch update positions (for drag-and-drop reordering)
    @MainActor
    func updatePositions(_ entries: [FoodLogEntry]) async {
        for entry in entries {
            guard let id = entry.id else { continue }
            let update = OrderUpdate(mealIndex: entry.mealIndex, sortOrder: entry.sortOrder)
            do {
                _ = try await supabase
                    .from("food_log")
                    .update(update)
                    .eq("id", value: id.uuidString)
                    .execute()
            } catch {
                print("Update position error for \(id): \(error)")
            }
        }
    }

    // MARK: - Delete entry
    @MainActor
    func deleteEntry(_ entry: FoodLogEntry) async {
        guard let id = entry.id else { return }
        do {
            try await supabase
                .from("food_log")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            todayEntries.removeAll { $0.id == id }
        } catch {
            print("Delete error: \(error)")
        }
    }

    // MARK: - Delete an entire meal and shift later meals down by one
    @MainActor
    func deleteMeal(userId: UUID, date: Date, mealIndex: Int) async {
        let dateStr = dateString(for: date)

        let originalEntries = todayEntries
        todayEntries = todayEntries.compactMap { entry in
            if entry.mealIndex == mealIndex { return nil }
            if entry.mealIndex > mealIndex {
                return FoodLogEntry(
                    id: entry.id,
                    userId: entry.userId,
                    logDate: entry.logDate,
                    mealIndex: entry.mealIndex - 1,
                    sortOrder: entry.sortOrder,
                    foodId: entry.foodId,
                    customFoodId: entry.customFoodId,
                    foodName: entry.foodName,
                    grams: entry.grams,
                    calories: entry.calories,
                    protein: entry.protein,
                    carbs: entry.carbs,
                    fat: entry.fat,
                    isCount: entry.isCount
                )
            }
            return entry
        }

        do {
            try await supabase
                .from("food_log")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .eq("log_date", value: dateStr)
                .eq("meal_index", value: mealIndex)
                .execute()

            let toShift = originalEntries.filter { $0.mealIndex > mealIndex }
            for entry in toShift {
                guard let id = entry.id else { continue }
                let update = OrderUpdate(mealIndex: entry.mealIndex - 1, sortOrder: entry.sortOrder)
                _ = try await supabase
                    .from("food_log")
                    .update(update)
                    .eq("id", value: id.uuidString)
                    .execute()
            }
        } catch {
            todayEntries = originalEntries
            print("Delete meal error: \(error)")
        }
    }

    // MARK: - Update streak via Postgres function
    private func updateStreak(logDate: String) async {
        do {
            let _: AnyJSON = try await supabase
                .rpc("update_streak", params: ["p_log_date": logDate])
                .execute()
                .value
        } catch {
            print("Streak update error: \(error)")
        }
    }

    // MARK: - Copy a single entry to a new date/meal
    @MainActor
    func copyEntry(_ entry: FoodLogEntry, userId: UUID, toDate: Date, mealIndex: Int) async {
        let dateStr = dateString(for: toDate)

        let newEntry: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "food_id": entry.foodId.map { .string($0.uuidString) } ?? .null,
            "food_name": .string(entry.foodName),
            "grams": .double(Double(entry.grams)),
            "calories": .double(Double(entry.calories)),
            "protein": .double(Double(entry.protein)),
            "carbs": .double(Double(entry.carbs)),
            "fat": .double(Double(entry.fat)),
            "meal_index": .integer(mealIndex),
            "log_date": .string(dateStr),
            "is_count": .bool(entry.isCount)
        ]

        do {
            try await supabase
                .from("food_log")
                .insert(newEntry)
                .execute()
        } catch {
            print("Copy entry error: \(error)")
        }
    }

    // MARK: - Change grams afterwards
    @MainActor
    func updateEntryGrams(_ entry: FoodLogEntry, newGrams: Float) async {
        guard let id = entry.id, entry.grams > 0 else { return }
        let ratio = newGrams / entry.grams

        let newCal = entry.calories * ratio
        let newProtein = entry.protein * ratio
        let newCarbs = entry.carbs * ratio
        let newFat = entry.fat * ratio

        let updated: [String: AnyJSON] = [
            "grams": .double(Double(newGrams)),
            "calories": .double(Double(newCal)),
            "protein": .double(Double(newProtein)),
            "carbs": .double(Double(newCarbs)),
            "fat": .double(Double(newFat))
        ]

        do {
            try await supabase.from("food_log")
                .update(updated)
                .eq("id", value: id.uuidString)
                .execute()

            if let idx = todayEntries.firstIndex(where: { $0.id == id }) {
                let old = todayEntries[idx]
                let replaced = FoodLogEntry(
                    id: old.id,
                    userId: old.userId,
                    logDate: old.logDate,
                    mealIndex: old.mealIndex,
                    sortOrder: old.sortOrder,
                    foodId: old.foodId,
                    customFoodId: old.customFoodId,
                    foodName: old.foodName,
                    grams: newGrams,
                    calories: newCal,
                    protein: newProtein,
                    carbs: newCarbs,
                    fat: newFat,
                    isCount: old.isCount
                )
                todayEntries[idx] = replaced
            }
        } catch {
            print("Update grams error: \(error)")
        }
    }
}
