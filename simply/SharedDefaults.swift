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

    static let empty = MacroSnapshot(
        calories: 0, calGoal: 2200,
        protein: 0, proteinGoal: 160,
        carbs: 0, carbGoal: 250,
        fat: 0, fatGoal: 70,
        lastUpdated: Date()
    )
}

// MARK: - Shared UserDefaults accessor
enum SharedDefaults {
    // Replace with your actual App Group identifier
    static let suiteName = "group.com.simply.macros"
    static let key = "macroSnapshot"

    static var shared: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Called from the main app after every log change
    static func save(_ snapshot: MacroSnapshot) {
        guard let defaults = shared,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)

        // Tell WidgetKit to refresh
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
