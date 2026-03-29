import Foundation
import Combine
import Supabase

// MARK: - Order Update DTO
struct OrderUpdate: Encodable {
    let mealIndex: Int
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case mealIndex = "meal_index"
        case sortOrder = "sort_order"
    }
}

final class LogService: ObservableObject {
    @Published var todayEntries: [FoodLogEntry] = []
    @Published var summary: DailySummary?
    @Published var isLoading = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var today: String {
        dateFormatter.string(from: Date())
    }

    func dateString(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Total macros from entries (real-time, no server round-trip)
    var totalCalories: Float { todayEntries.reduce(0) { $0 + $1.calories } }
    var totalProtein: Float { todayEntries.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Float { todayEntries.reduce(0) { $0 + $1.carbs } }
    var totalFat: Float { todayEntries.reduce(0) { $0 + $1.fat } }

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
        isLoading = true
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
        isLoading = false
    }

    // MARK: - Load today's entries
    @MainActor
    func loadToday(userId: UUID) async {
        await loadEntries(userId: userId, date: Date())
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
            fat: macros.fat
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
            fat: macros.fat
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
            fat: fat
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

    // MARK: - Update streak via Edge Function
    private func updateStreak(logDate: String) async {
        do {
            let _: Data = try await supabase.functions.invoke(
                "update-streak",
                options: .init(body: ["log_date": logDate])
            )
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
            "log_date": .string(dateStr)
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
                var updated = todayEntries[idx]
                updated = FoodLogEntry(
                    id: updated.id,
                    userId: updated.userId,
                    logDate: updated.logDate,
                    mealIndex: updated.mealIndex,
                    sortOrder: updated.sortOrder,
                    foodId: updated.foodId,
                    customFoodId: updated.customFoodId,
                    foodName: updated.foodName,
                    grams: newGrams,
                    calories: newCal,
                    protein: newProtein,
                    carbs: newCarbs,
                    fat: newFat
                )
                todayEntries[idx] = updated
            }
        } catch {
            print("Update grams error: \(error)")
        }
    }
}
