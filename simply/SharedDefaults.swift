import Foundation
import WidgetKit

// MARK: - Shared data model between app and widget
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
        proteinColorR: 0.47, proteinColorG: 0.75, proteinColorB: 1.0,
        carbsColorR: 1.0, carbsColorG: 0.78, carbsColorB: 0.35,
        fatColorR: 1.0, fatColorG: 0.47, fatColorB: 0.47
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
