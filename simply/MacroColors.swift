import SwiftUI
import Combine
import WidgetKit

class MacroColors: ObservableObject {
    @AppStorage("macro_calories_hex") private var caloriesHex: String = "#A8D8F0"
    @AppStorage("macro_protein_hex")  private var proteinHex: String  = "#B5E8A8"
    @AppStorage("macro_carbs_hex")    private var carbsHex: String    = "#C8A8E9"
    @AppStorage("macro_fat_hex")      private var fatHex: String      = "#FF9AA2"

    static let palette: [(name: String, hex: String)] = [
        ("Red",      "#FF9AA2"),
        ("Coral",    "#FFB3A7"),
        ("Orange",   "#FFCBA4"),
        ("Peach",    "#FFDAB9"),
        ("Amber",    "#FFE5A0"),
        ("Yellow",   "#FFF4B3"),
        ("Lime",     "#DCEDA1"),
        ("Green",    "#B5E8A8"),
        ("Mint",     "#A8E6CF"),
        ("Teal",     "#A0E7E5"),
        ("Sky",      "#A8D8F0"),
        ("Blue",     "#A2C4F5"),
        ("Indigo",   "#B5B5F0"),
        ("Violet",   "#C8A8E9"),
        ("Lavender", "#D8BFD8"),
        ("Pink",     "#F7B9D0"),
    ]

    var calories: Color { Color(hex: caloriesHex) }
    var protein: Color  { Color(hex: proteinHex) }
    var carbs: Color    { Color(hex: carbsHex) }
    var fat: Color      { Color(hex: fatHex) }

    var caloriesHexValue: String {
        get { caloriesHex }
        set { objectWillChange.send(); caloriesHex = newValue; reloadWidget() }
    }
    var proteinHexValue: String {
        get { proteinHex }
        set { objectWillChange.send(); proteinHex = newValue; reloadWidget() }
    }
    var carbsHexValue: String {
        get { carbsHex }
        set { objectWillChange.send(); carbsHex = newValue; reloadWidget() }
    }
    var fatHexValue: String {
        get { fatHex }
        set { objectWillChange.send(); fatHex = newValue; reloadWidget() }
    }

    private func reloadWidget() {
        SharedDefaults.updateColors(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
    }
}
