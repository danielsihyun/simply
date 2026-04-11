import Foundation
import SwiftUI
import UIKit
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
        caloriesColorR: 0.66, caloriesColorG: 0.85, caloriesColorB: 0.94,
        proteinColorR: 0.71, proteinColorG: 0.91, proteinColorB: 0.66,
        carbsColorR: 0.78, carbsColorG: 0.66, carbsColorB: 0.91,
        fatColorR: 1.0, fatColorG: 0.60, fatColorB: 0.64
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

    /// Update only the color fields on the existing snapshot, preserving all macro values.
    /// Called whenever the user changes a color in settings so the widget picks it up immediately.
    static func updateColors(calories: Color, protein: Color, carbs: Color, fat: Color) {
        let existing = load()
        let calC = UIColor(calories).cgColor.components ?? [0.66, 0.85, 0.94, 1.0]
        let pC   = UIColor(protein).cgColor.components  ?? [0.71, 0.91, 0.66, 1.0]
        let cC   = UIColor(carbs).cgColor.components    ?? [0.78, 0.66, 0.91, 1.0]
        let fC   = UIColor(fat).cgColor.components      ?? [1.0, 0.60, 0.64, 1.0]

        let updated = MacroSnapshot(
            calories: existing.calories,
            calGoal: existing.calGoal,
            protein: existing.protein,
            proteinGoal: existing.proteinGoal,
            carbs: existing.carbs,
            carbGoal: existing.carbGoal,
            fat: existing.fat,
            fatGoal: existing.fatGoal,
            lastUpdated: existing.lastUpdated,
            caloriesColorR: Double(calC[0]), caloriesColorG: Double(calC[1]), caloriesColorB: Double(calC[2]),
            proteinColorR: Double(pC[0]), proteinColorG: Double(pC[1]), proteinColorB: Double(pC[2]),
            carbsColorR: Double(cC[0]), carbsColorG: Double(cC[1]), carbsColorB: Double(cC[2]),
            fatColorR: Double(fC[0]), fatColorG: Double(fC[1]), fatColorB: Double(fC[2])
        )
        save(updated)
    }
}
