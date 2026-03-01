import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var calText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""
    @State private var isSaving = false

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
                    VStack(alignment: .leading, spacing: 24) {
                        // Daily Goals section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Daily Goals")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.textMuted)
                                .textCase(.uppercase)
                                .tracking(0.8)

                            GoalRow(label: "Calories", unit: "kcal", text: $calText, color: .white)
                            GoalRow(label: "Protein", unit: "g", text: $proteinText, color: .proteinColor)
                            GoalRow(label: "Carbs", unit: "g", text: $carbsText, color: .carbColor)
                            GoalRow(label: "Fat", unit: "g", text: $fatText, color: .fatColor)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color.bgCard)
                        .cornerRadius(14)

                        // Account section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Account")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.textMuted)
                                .textCase(.uppercase)
                                .tracking(0.8)

                            Button {
                                Task {
                                    await authService.signOut()
                                }
                            } label: {
                                Text("Sign Out")
                                    .font(.system(size: 15))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(Color.bgCard)
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
        .onAppear {
            if let p = authService.profile {
                calText = "\(p.calGoal)"
                proteinText = "\(p.proteinGoal)"
                carbsText = "\(p.carbGoal)"
                fatText = "\(p.fatGoal)"
            }
        }
    }

    private func save() {
        let cal = Int(calText) ?? authService.profile?.calGoal ?? 2200
        let protein = Int(proteinText) ?? authService.profile?.proteinGoal ?? 160
        let carbs = Int(carbsText) ?? authService.profile?.carbGoal ?? 250
        let fat = Int(fatText) ?? authService.profile?.fatGoal ?? 70

        isSaving = true
        Task {
            await authService.updateGoals(cal: cal, protein: protein, carbs: carbs, fat: fat)
            isSaving = false
            dismiss()
        }
    }
}

// MARK: - Goal Row
struct GoalRow: View {
    let label: String
    let unit: String
    @Binding var text: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.textPrimary)

            Spacer()

            HStack(spacing: 4) {
                TextField("0", text: $text)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundColor(color)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)

                Text(unit)
                    .font(.system(size: 12))
                    .foregroundColor(.textMuted)
                    .frame(width: 28, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
    }
}
