import SwiftUI
import Combine

/// Persisted macro colors backed by @AppStorage.
/// Inject as .environmentObject(macroColors) at the app root.
class MacroColors: ObservableObject {
    @AppStorage("macro_protein_hex") private var proteinHex: String = "#6BDFB8"
    @AppStorage("macro_carbs_hex")   private var carbsHex: String   = "#7EB6FF"
    @AppStorage("macro_fat_hex")     private var fatHex: String     = "#F4A261"

    static let palette: [(name: String, hex: String)] = [
        ("Mint",    "#6BDFB8"),
        ("Teal",    "#4DD8C0"),
        ("Green",   "#66D97F"),
        ("Sky",     "#7EB6FF"),
        ("Blue",    "#5B9CF5"),
        ("Indigo",  "#8B8CFF"),
        ("Violet",  "#B07EFF"),
        ("Pink",    "#F27BAA"),
        ("Rose",    "#FF6B8A"),
        ("Orange",  "#F4A261"),
        ("Amber",   "#FFB84D"),
        ("Yellow",  "#F0D56E"),
        ("Red",     "#FF6F61"),
        ("Coral",   "#FF8A73"),
    ]

    var protein: Color { Color(hex: proteinHex) }
    var carbs: Color   { Color(hex: carbsHex) }
    var fat: Color     { Color(hex: fatHex) }

    var proteinHexValue: String {
        get { proteinHex }
        set { objectWillChange.send(); proteinHex = newValue }
    }
    var carbsHexValue: String {
        get { carbsHex }
        set { objectWillChange.send(); carbsHex = newValue }
    }
    var fatHexValue: String {
        get { fatHex }
        set { objectWillChange.send(); fatHex = newValue }
    }
}
