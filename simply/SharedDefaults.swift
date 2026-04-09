import Foundation
import WidgetKit

struct MacroSnapshot: Codable {
    let calories: Float
    let calGoal: Float
    let protein: Float
    let proteinGoal: Float
    let carbs: Float
    let carbGoal: Float
    let fat: Float
    let fatGoal: Float
    let lastUpdated: Date

    // Macro colors (stored as RGB)
    let caloriesColorR: Double
    let caloriesColorG: Double
    let caloriesColorB: Double
    let proteinColorR: Double
    let proteinColorG: Double
    let proteinColorB: Double
    let carbsColorR: Double
    let carbsColorG: Double
    let carbsColorB: Double
    let fatColorR: Double
    let fatColorG: Double
    let fatColorB: Double

    static let empty = MacroSnapshot(
        calories: 0, calGoal: 2200,
        protein: 0, proteinGoal: 160,
        carbs: 0, carbGoal: 250,
        fat: 0, fatGoal: 70,
        lastUpdated: Date(),
        caloriesColorR: 0.36, caloriesColorG: 0.61, caloriesColorB: 0.96,
        proteinColorR: 0.42, proteinColorG: 0.87, proteinColorB: 0.72,
        carbsColorR: 0.69, carbsColorG: 0.49, carbsColorB: 1.0,
        fatColorR: 0.96, fatColorG: 0.64, fatColorB: 0.38
    )
}

// MARK: - Shared UserDefaults accessor
enum SharedDefaults {
    static let suiteName = "group.com.simply.macros"
    static let key = "macroSnapshot"

    static var shared: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Called from the main app after every log change
    static func save(_ snapshot: MacroSnapshot) {
        guard let defaults = shared,
              let data = try? JSONEncoder().encode(snapshot) else {
            print("⚠️ Widget: Failed to get shared defaults — check App Group ID")
            return
        }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: "MacroWidget")
    }

    /// Called from the widget's TimelineProvider
    static func load() -> MacroSnapshot {
        guard let defaults = shared,
              let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(MacroSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
