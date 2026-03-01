import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var calText: String = ""
    @State private var proteinPct: Double = 30
    @State private var carbsPct: Double = 40
    @State private var fatPct: Double = 30
    @State private var activeSlider: MacroType? = nil
    @State private var isSaving = false

    enum MacroType { case protein, carbs, fat }

    private var calGoal: Int { Int(calText) ?? 2200 }
    private var proteinGrams: Int { Int(Double(calGoal) * proteinPct / 100.0 / 4.0) }
    private var carbsGrams: Int { Int(Double(calGoal) * carbsPct / 100.0 / 4.0) }
    private var fatGrams: Int { Int(Double(calGoal) * fatPct / 100.0 / 9.0) }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.headerDay)
                        .foregroundColor(.white)
                        .tracking(-0.8)

                    Spacer()

                    Button("Done") {
                        save()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.calBarBlue)
                    .disabled(isSaving)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Calorie goal
                        VStack(alignment: .leading, spacing: 0) {
                            Text("CALORIE GOAL")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textMuted)
                                .tracking(0.8)
                                .padding(.bottom, 12)

                            HStack {
                                TextField("2200", text: $calText)
                                    .font(.system(size: 28, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                Text("cal")
                                    .font(.system(size: 14))
                                    .foregroundColor(.textMuted)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.bgCard)
                        .cornerRadius(14)

                        // Macro split
                        VStack(alignment: .leading, spacing: 0) {
                            Text("MACRO SPLIT")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textMuted)
                                .tracking(0.8)
                                .padding(.bottom, 14)

                            // Stacked bar preview
                            GeometryReader { geo in
                                HStack(spacing: 1.5) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.proteinColor.opacity(0.8))
                                        .frame(width: max(geo.size.width * proteinPct / 100.0, 4))

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.carbColor.opacity(0.8))
                                        .frame(width: max(geo.size.width * carbsPct / 100.0, 4))

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.fatColor.opacity(0.8))
                                        .frame(width: max(geo.size.width * fatPct / 100.0, 4))
                                }
                                .animation(.easeOut(duration: 0.15), value: proteinPct)
                                .animation(.easeOut(duration: 0.15), value: carbsPct)
                                .animation(.easeOut(duration: 0.15), value: fatPct)
                            }
                            .frame(height: 6)
                            .padding(.bottom, 18)

                            // Sliders
                            MacroSliderRow(
                                label: "Protein",
                                pct: $proteinPct,
                                grams: proteinGrams,
                                unit: "g  ·  4 cal/g",
                                color: .proteinColor,
                                onChanged: { adjustOthers(changed: .protein) }
                            )

                            macroDiv

                            MacroSliderRow(
                                label: "Carbs",
                                pct: $carbsPct,
                                grams: carbsGrams,
                                unit: "g  ·  4 cal/g",
                                color: .carbColor,
                                onChanged: { adjustOthers(changed: .carbs) }
                            )

                            macroDiv

                            MacroSliderRow(
                                label: "Fat",
                                pct: $fatPct,
                                grams: fatGrams,
                                unit: "g  ·  9 cal/g",
                                color: .fatColor,
                                onChanged: { adjustOthers(changed: .fat) }
                            )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.bgCard)
                        .cornerRadius(14)

                        // Account section
                        VStack(alignment: .leading, spacing: 0) {
                            Text("ACCOUNT")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textMuted)
                                .tracking(0.8)
                                .padding(.bottom, 12)

                            Button {
                                Task { await authService.signOut() }
                            } label: {
                                HStack {
                                    Text("Sign Out")
                                        .font(.system(size: 15))
                                        .foregroundColor(.red.opacity(0.8))
                                    Spacer()
                                    Image(systemName: "arrow.right.square")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red.opacity(0.4))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.bgCard)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            if let p = authService.profile {
                calText = "\(p.calGoal)"
                // Reverse-calc percentages from stored grams
                let totalCal = Double(p.calGoal)
                if totalCal > 0 {
                    let pCal = Double(p.proteinGoal) * 4.0
                    let cCal = Double(p.carbGoal) * 4.0
                    let fCal = Double(p.fatGoal) * 9.0
                    proteinPct = round(pCal / totalCal * 100.0)
                    carbsPct = round(cCal / totalCal * 100.0)
                    fatPct = 100.0 - proteinPct - carbsPct
                }
            }
        }
    }

    private var macroDiv: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 1)
            .padding(.vertical, 10)
    }

    // When one slider moves, redistribute the remainder to the other two proportionally
    private func adjustOthers(changed: MacroType) {
        let minPct: Double = 5

        switch changed {
        case .protein:
            proteinPct = min(max(proteinPct, minPct), 90)
            let remainder = 100.0 - proteinPct
            let otherTotal = carbsPct + fatPct
            if otherTotal > 0 {
                carbsPct = max(round(remainder * carbsPct / otherTotal), minPct)
                fatPct = max(100.0 - proteinPct - carbsPct, minPct)
            } else {
                carbsPct = remainder / 2
                fatPct = remainder / 2
            }
        case .carbs:
            carbsPct = min(max(carbsPct, minPct), 90)
            let remainder = 100.0 - carbsPct
            let otherTotal = proteinPct + fatPct
            if otherTotal > 0 {
                proteinPct = max(round(remainder * proteinPct / otherTotal), minPct)
                fatPct = max(100.0 - carbsPct - proteinPct, minPct)
            } else {
                proteinPct = remainder / 2
                fatPct = remainder / 2
            }
        case .fat:
            fatPct = min(max(fatPct, minPct), 90)
            let remainder = 100.0 - fatPct
            let otherTotal = proteinPct + carbsPct
            if otherTotal > 0 {
                proteinPct = max(round(remainder * proteinPct / otherTotal), minPct)
                carbsPct = max(100.0 - fatPct - proteinPct, minPct)
            } else {
                proteinPct = remainder / 2
                carbsPct = remainder / 2
            }
        }

        // Clamp to ensure exactly 100
        let total = proteinPct + carbsPct + fatPct
        if total != 100 {
            fatPct += (100.0 - total)
        }
    }

    private func save() {
        isSaving = true
        Task {
            await authService.updateGoals(
                cal: calGoal,
                protein: proteinGrams,
                carbs: carbsGrams,
                fat: fatGrams
            )
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Macro Slider Row
struct MacroSliderRow: View {
    let label: String
    @Binding var pct: Double
    let grams: Int
    let unit: String
    let color: Color
    let onChanged: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(.textPrimary)

                Spacer()

                HStack(spacing: 3) {
                    Text("\(Int(pct))%")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(color)

                    Text("·")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.1))

                    Text("\(grams)")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))

                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundColor(.textMuted)
                }
            }

            // Custom slider
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))

                    Capsule()
                        .fill(color.opacity(0.5))
                        .frame(width: geo.size.width * pct / 100.0)
                }
                .frame(height: 4)
                .contentShape(Rectangle().size(width: geo.size.width, height: 40))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newPct = Double(value.location.x / geo.size.width) * 100.0
                            pct = min(max(round(newPct), 5), 90)
                            onChanged()
                        }
                )
            }
            .frame(height: 4)
        }
    }
}
