import Foundation
import Supabase
import Combine

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

    // MARK: - Total macros from entries (real-time, no server round-trip)
    var totalCalories: Float { todayEntries.reduce(0) { $0 + $1.calories } }
    var totalProtein: Float { todayEntries.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Float { todayEntries.reduce(0) { $0 + $1.carbs } }
    var totalFat: Float { todayEntries.reduce(0) { $0 + $1.fat } }

    // MARK: - Load today's entries
    @MainActor
    func loadToday(userId: UUID) async {
        isLoading = true
        do {
            let entries: [FoodLogEntry] = try await supabase
                .from("food_log")
                .select()
                .eq("user_id", value: userId.uuidString)
                .eq("log_date", value: today)
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

    // MARK: - Add entry
    @MainActor
    func addEntry(userId: UUID, food: Food, grams: Float) async {
        let macros = food.macros(forGrams: grams)
        let nextSort = (todayEntries.last?.sortOrder ?? -1) + 1

        let insert = FoodLogInsert(
            userId: userId,
            logDate: today,
            mealIndex: 0,
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

        do {
            let entry: FoodLogEntry = try await supabase
                .from("food_log")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            todayEntries.append(entry)

            // Fire and forget: update streak
            Task {
                await updateStreak(logDate: today)
            }
        } catch {
            print("Add entry error: \(error)")
        }
    }

    // MARK: - Quick add (manual macros, no food reference)
    @MainActor
    func quickAdd(userId: UUID, name: String, calories: Float, protein: Float, carbs: Float, fat: Float) async {
        let nextSort = (todayEntries.last?.sortOrder ?? -1) + 1

        let insert = FoodLogInsert(
            userId: userId,
            logDate: today,
            mealIndex: 0,
            sortOrder: nextSort,
            foodId: nil,
            customFoodId: nil,
            foodName: name,
            grams: 0,
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
}
