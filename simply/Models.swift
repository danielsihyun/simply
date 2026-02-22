import Foundation

// MARK: - Food (from foods table)
struct Food: Codable, Identifiable, Hashable {
    let id: UUID
    let externalId: String
    let name: String
    let brand: String?
    let servingLabel: String
    let servingGrams: Float
    let calPerServing: Float
    let proteinPerServing: Float
    let carbsPerServing: Float
    let fatPerServing: Float

    enum CodingKeys: String, CodingKey {
        case id
        case externalId = "external_id"
        case name, brand
        case servingLabel = "serving_label"
        case servingGrams = "serving_grams"
        case calPerServing = "cal_per_serving"
        case proteinPerServing = "protein_per_serving"
        case carbsPerServing = "carbs_per_serving"
        case fatPerServing = "fat_per_serving"
    }

    /// Calculate macros for a given weight in grams
    func macros(forGrams grams: Float) -> Macros {
        let factor = grams / servingGrams
        return Macros(
            calories: calPerServing * factor,
            protein: proteinPerServing * factor,
            carbs: carbsPerServing * factor,
            fat: fatPerServing * factor
        )
    }
}

// MARK: - Profile
struct Profile: Codable {
    let id: UUID
    var displayName: String?
    var calGoal: Int
    var proteinGoal: Int
    var carbGoal: Int
    var fatGoal: Int
    var streakCurrent: Int
    var streakLongest: Int
    var streakLastLogDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case calGoal = "cal_goal"
        case proteinGoal = "protein_goal"
        case carbGoal = "carb_goal"
        case fatGoal = "fat_goal"
        case streakCurrent = "streak_current"
        case streakLongest = "streak_longest"
        case streakLastLogDate = "streak_last_log_date"
    }
}

// MARK: - Food Log Entry
struct FoodLogEntry: Codable, Identifiable {
    var id: UUID?
    let userId: UUID
    let logDate: String          // "YYYY-MM-DD"
    var mealIndex: Int
    var sortOrder: Int
    var foodId: UUID?
    var customFoodId: UUID?
    let foodName: String
    let grams: Float
    let calories: Float
    let protein: Float
    let carbs: Float
    let fat: Float

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case logDate = "log_date"
        case mealIndex = "meal_index"
        case sortOrder = "sort_order"
        case foodId = "food_id"
        case customFoodId = "custom_food_id"
        case foodName = "food_name"
        case grams, calories, protein, carbs, fat
    }
}

// MARK: - Insert DTO (without id, let Postgres generate it)
struct FoodLogInsert: Codable {
    let userId: UUID
    let logDate: String
    let mealIndex: Int
    let sortOrder: Int
    let foodId: UUID?
    let customFoodId: UUID?
    let foodName: String
    let grams: Float
    let calories: Float
    let protein: Float
    let carbs: Float
    let fat: Float

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case logDate = "log_date"
        case mealIndex = "meal_index"
        case sortOrder = "sort_order"
        case foodId = "food_id"
        case customFoodId = "custom_food_id"
        case foodName = "food_name"
        case grams, calories, protein, carbs, fat
    }
}

// MARK: - Daily Summary
struct DailySummary: Codable {
    let userId: UUID
    let logDate: String
    let totalCal: Float
    let totalProtein: Float
    let totalCarbs: Float
    let totalFat: Float
    let mealCount: Int
    let entryCount: Int

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case logDate = "log_date"
        case totalCal = "total_cal"
        case totalProtein = "total_protein"
        case totalCarbs = "total_carbs"
        case totalFat = "total_fat"
        case mealCount = "meal_count"
        case entryCount = "entry_count"
    }
}

// MARK: - Macros helper
struct Macros {
    let calories: Float
    let protein: Float
    let carbs: Float
    let fat: Float

    static let zero = Macros(calories: 0, protein: 0, carbs: 0, fat: 0)
}
