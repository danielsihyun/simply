import SwiftUI

// MARK: - Colors (matching MVP)
extension Color {
    // Backgrounds
    static let bgPrimary = Color(hex: "0A0A0C")
    static let bgCard = Color.white.opacity(0.025)
    static let bgDropdown = Color(hex: "1A1A1C")
    static let bgStreakBadge = Color(red: 1, green: 0.63, blue: 0.2).opacity(0.12)

    // Text
    static let textPrimary = Color.white.opacity(0.88)
    static let textSecondary = Color.white.opacity(0.3)
    static let textMuted = Color.white.opacity(0.2)
    static let textVeryMuted = Color.white.opacity(0.15)
    static let textFaint = Color.white.opacity(0.08)

    // Macro colors
    static let proteinColor = Color(hex: "4ADE80")
    static let carbColor = Color(hex: "60A5FA")
    static let fatColor = Color(hex: "FBBF24")
    static let streakColor = Color(hex: "FFA032")

    // Calorie bar
    static let calBarBlue = Color(hex: "60A5FA")
    static let calBarPurple = Color(hex: "818CF8")
    static let calBarGreen = Color(hex: "4ADE80")
    static let calBarGreenDark = Color(hex: "22C55E")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Fonts
extension Font {
    static let headerDay = Font.system(size: 24, weight: .bold, design: .default)
    static let headerDate = Font.system(size: 13, weight: .regular, design: .default)
    static let summaryCalorie = Font.system(size: 22, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let monoTiny = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let bodyFood = Font.system(size: 15, weight: .regular, design: .default)
    static let labelSmall = Font.system(size: 11, weight: .regular, design: .default)
    static let labelMealHeader = Font.system(size: 11, weight: .semibold, design: .default)
    static let inputSearch = Font.system(size: 15, weight: .regular, design: .default)
    static let inputGrams = Font.system(size: 11, weight: .regular, design: .default)
}
