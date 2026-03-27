import SwiftUI

/// Settings section with swatch-based color pickers for each macro.
struct MacroColorPickerSection: View {
    @EnvironmentObject var macroColors: MacroColors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("MACRO COLORS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textMuted)
                .tracking(0.8)
                .padding(.bottom, 14)

            MacroSwatchRow(
                label: "Protein",
                selectedHex: macroColors.proteinHexValue,
                onSelect: { macroColors.proteinHexValue = $0 }
            )

            sectionDivider

            MacroSwatchRow(
                label: "Carbs",
                selectedHex: macroColors.carbsHexValue,
                onSelect: { macroColors.carbsHexValue = $0 }
            )

            sectionDivider

            MacroSwatchRow(
                label: "Fat",
                selectedHex: macroColors.fatHexValue,
                onSelect: { macroColors.fatHexValue = $0 }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 1)
            .padding(.vertical, 10)
    }
}

struct MacroSwatchRow: View {
    let label: String
    let selectedHex: String
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(.textPrimary)

                Spacer()

                Circle()
                    .fill(Color(hex: selectedHex))
                    .frame(width: 12, height: 12)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MacroColors.palette, id: \.hex) { swatch in
                        let isSelected = swatch.hex.lowercased() == selectedHex.lowercased()
                        Circle()
                            .fill(Color(hex: swatch.hex))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                            )
                            .overlay(
                                isSelected
                                    ? Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                    : nil
                            )
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                            .animation(.easeOut(duration: 0.15), value: isSelected)
                            .onTapGesture {
                                onSelect(swatch.hex)
                            }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
