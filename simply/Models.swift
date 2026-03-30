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
    let isCount: Bool

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
        case isCount = "is_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        externalId = try container.decode(String.self, forKey: .externalId)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        servingLabel = try container.decode(String.self, forKey: .servingLabel)
        servingGrams = try container.decode(Float.self, forKey: .servingGrams)
        calPerServing = try container.decode(Float.self, forKey: .calPerServing)
        proteinPerServing = try container.decode(Float.self, forKey: .proteinPerServing)
        carbsPerServing = try container.decode(Float.self, forKey: .carbsPerServing)
        fatPerServing = try container.decode(Float.self, forKey: .fatPerServing)
        isCount = try container.decodeIfPresent(Bool.self, forKey: .isCount) ?? false
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

    /// Returns 0 if the streak is stale (last log older than yesterday)
    var effectiveStreak: Int {
        guard let dateString = streakLastLogDate else { return 0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current

        guard let lastLog = formatter.date(from: dateString) else { return 0 }

        let cal = Calendar.current
        if cal.isDateInToday(lastLog) || cal.isDateInYesterday(lastLog) || cal.isDateInTomorrow(lastLog) {
            return streakCurrent
        }
        return 0
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
    let isCount: Bool

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
        case isCount = "is_count"
    }

    // Memberwise init (needed because custom Decodable init replaces the auto-generated one)
    init(id: UUID? = nil, userId: UUID, logDate: String, mealIndex: Int, sortOrder: Int, foodId: UUID? = nil, customFoodId: UUID? = nil, foodName: String, grams: Float, calories: Float, protein: Float, carbs: Float, fat: Float, isCount: Bool = false) {
        self.id = id
        self.userId = userId
        self.logDate = logDate
        self.mealIndex = mealIndex
        self.sortOrder = sortOrder
        self.foodId = foodId
        self.customFoodId = customFoodId
        self.foodName = foodName
        self.grams = grams
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.isCount = isCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        logDate = try container.decode(String.self, forKey: .logDate)
        mealIndex = try container.decode(Int.self, forKey: .mealIndex)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        foodId = try container.decodeIfPresent(UUID.self, forKey: .foodId)
        customFoodId = try container.decodeIfPresent(UUID.self, forKey: .customFoodId)
        foodName = try container.decode(String.self, forKey: .foodName)
        grams = try container.decode(Float.self, forKey: .grams)
        calories = try container.decode(Float.self, forKey: .calories)
        protein = try container.decode(Float.self, forKey: .protein)
        carbs = try container.decode(Float.self, forKey: .carbs)
        fat = try container.decode(Float.self, forKey: .fat)
        isCount = try container.decodeIfPresent(Bool.self, forKey: .isCount) ?? false
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
    let isCount: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case logDate = "log_date"
        case mealIndex = "meal_index"
        case sortOrder = "sort_order"
        case foodId = "food_id"
        case customFoodId = "custom_food_id"
        case foodName = "food_name"
        case grams, calories, protein, carbs, fat
        case isCount = "is_count"
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

// MARK: - Position Update DTO (for drag-and-drop reordering)
struct PositionUpdate: Encodable {
    let mealIndex: Int
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case mealIndex = "meal_index"
        case sortOrder = "sort_order"
    }
}

// MARK: - Custom Food Insert DTO
struct CustomFoodInsert: Encodable {
    let externalId: String
    let name: String
    let brand: String?
    let servingLabel: String
    let servingGrams: Float
    let calPerServing: Float
    let proteinPerServing: Float
    let carbsPerServing: Float
    let fatPerServing: Float
    let isCount: Bool

    enum CodingKeys: String, CodingKey {
        case externalId = "external_id"
        case name, brand
        case servingLabel = "serving_label"
        case servingGrams = "serving_grams"
        case calPerServing = "cal_per_serving"
        case proteinPerServing = "protein_per_serving"
        case carbsPerServing = "carbs_per_serving"
        case fatPerServing = "fat_per_serving"
        case isCount = "is_count"
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
