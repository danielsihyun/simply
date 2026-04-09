import SwiftUI

struct MacroColorPickerSection: View {
    @EnvironmentObject var macroColors: MacroColors
    @State private var editing: MacroTarget? = nil

    enum MacroTarget: String, CaseIterable {
        case calories, protein, carbs, fat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("COLORS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textMuted)
                .tracking(0.8)
                .padding(.bottom, 14)

            HStack(spacing: 0) {
                colorCircle(label: "Calories", target: .calories, hex: macroColors.caloriesHexValue)
                Spacer()

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1, height: 28)

                Spacer()
                colorCircle(label: "Protein", target: .protein, hex: macroColors.proteinHexValue)
                Spacer()
                colorCircle(label: "Carbs", target: .carbs, hex: macroColors.carbsHexValue)
                Spacer()
                colorCircle(label: "Fat", target: .fat, hex: macroColors.fatHexValue)
            }
            .padding(.horizontal, 16)

            if let target = editing {
                let selectedHex = hexFor(target)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(MacroColors.palette, id: \.hex) { swatch in
                            let isSelected = swatch.hex.lowercased() == selectedHex.lowercased()
                            Circle()
                                .fill(Color(hex: swatch.hex))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                                )
                                .overlay(
                                    isSelected
                                        ? Image(systemName: "checkmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                        : nil
                                )
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                .animation(.easeOut(duration: 0.15), value: isSelected)
                                .onTapGesture {
                                    setHex(swatch.hex, for: target)
                                }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .padding(.top, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgCard)
        .cornerRadius(14)
        .animation(.easeOut(duration: 0.2), value: editing)
    }

    private func colorCircle(label: String, target: MacroTarget, hex: String) -> some View {
        let isEditing = editing == target

        return VStack(spacing: 6) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isEditing ? 0.6 : 0), lineWidth: 2)
                )
                .scaleEffect(isEditing ? 1.1 : 1.0)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(isEditing ? .white.opacity(0.7) : .textMuted)
        }
        .onTapGesture {
            withAnimation {
                editing = editing == target ? nil : target
            }
        }
    }

    private func hexFor(_ target: MacroTarget) -> String {
        switch target {
        case .calories: return macroColors.caloriesHexValue
        case .protein:  return macroColors.proteinHexValue
        case .carbs:    return macroColors.carbsHexValue
        case .fat:      return macroColors.fatHexValue
        }
    }

    private func setHex(_ hex: String, for target: MacroTarget) {
        switch target {
        case .calories: macroColors.caloriesHexValue = hex
        case .protein:  macroColors.proteinHexValue = hex
        case .carbs:    macroColors.carbsHexValue = hex
        case .fat:      macroColors.fatHexValue = hex
        }
    }
}
