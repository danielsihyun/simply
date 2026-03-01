import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var calText: String = ""
    @State private var proteinPct: Double = 30
    @State private var carbsPct: Double = 40
    @State private var fatPct: Double = 30
    @State private var isSaving = false
    @State private var splitMode: SplitMode = .waterfall

    enum SplitMode: String, CaseIterable {
        case waterfall = "Waterfall"
        case lockable = "Lock"
    }

    // Lock state for lockable mode
    @State private var proteinLocked = false
    @State private var carbsLocked = false
    @State private var fatLocked = false

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

                    Button("Done") { save() }
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

                                Text("kcal")
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
                            HStack {
                                Text("MACRO SPLIT")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.textMuted)
                                    .tracking(0.8)

                                Spacer()

                                // Mode toggle
                                HStack(spacing: 0) {
                                    ForEach(SplitMode.allCases, id: \.self) { mode in
                                        Button {
                                            withAnimation(.easeOut(duration: 0.2)) {
                                                splitMode = mode
                                            }
                                        } label: {
                                            Text(mode.rawValue)
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(splitMode == mode ? .white : .textMuted)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(splitMode == mode ? Color.white.opacity(0.08) : Color.clear)
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(8)
                            }
                            .padding(.bottom, 14)

                            // Stacked bar preview
                            stackedBar
                                .padding(.bottom, 18)

                            // Sliders
                            if splitMode == .waterfall {
                                waterfallSliders
                            } else {
                                lockableSliders
                            }
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
                let totalCal = Double(p.calGoal)
                if totalCal > 0 {
                    let pCal = Double(p.proteinGoal) * 4.0
                    let cCal = Double(p.carbGoal) * 4.0
                    proteinPct = round(pCal / totalCal * 100.0)
                    carbsPct = round(cCal / totalCal * 100.0)
                    fatPct = 100.0 - proteinPct - carbsPct
                }
            }
        }
    }

    // MARK: - Stacked bar
    private var stackedBar: some View {
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
    }

    // MARK: - Waterfall mode (P → C → F auto-fills)
    private var waterfallSliders: some View {
        VStack(spacing: 0) {
            MacroSliderRow(
                label: "Protein",
                pct: $proteinPct,
                grams: proteinGrams,
                color: .proteinColor,
                locked: false,
                onLockTap: nil,
                onChanged: {
                    proteinPct = min(max(round(proteinPct), 5), 90)
                    let remaining = 100.0 - proteinPct
                    if carbsPct > remaining - 5 {
                        carbsPct = max(remaining - 5, 5)
                    }
                    fatPct = 100.0 - proteinPct - carbsPct
                }
            )

            macroDiv

            MacroSliderRow(
                label: "Carbs",
                pct: $carbsPct,
                grams: carbsGrams,
                color: .carbColor,
                locked: false,
                onLockTap: nil,
                onChanged: {
                    let maxCarbs = 100.0 - proteinPct - 5
                    carbsPct = min(max(round(carbsPct), 5), maxCarbs)
                    fatPct = 100.0 - proteinPct - carbsPct
                }
            )

            macroDiv

            // Fat is always the remainder
            MacroReadonlyRow(
                label: "Fat",
                pct: fatPct,
                grams: fatGrams,
                color: .fatColor,
                hint: "remainder"
            )
        }
    }

    // MARK: - Lockable mode (lock any, others adjust)
    private var lockableSliders: some View {
        VStack(spacing: 0) {
            MacroSliderRow(
                label: "Protein",
                pct: $proteinPct,
                grams: proteinGrams,
                color: .proteinColor,
                locked: proteinLocked,
                onLockTap: { proteinLocked.toggle() },
                onChanged: { adjustLockable(changed: .protein) }
            )

            macroDiv

            MacroSliderRow(
                label: "Carbs",
                pct: $carbsPct,
                grams: carbsGrams,
                color: .carbColor,
                locked: carbsLocked,
                onLockTap: { carbsLocked.toggle() },
                onChanged: { adjustLockable(changed: .carbs) }
            )

            macroDiv

            MacroSliderRow(
                label: "Fat",
                pct: $fatPct,
                grams: fatGrams,
                color: .fatColor,
                locked: fatLocked,
                onLockTap: { fatLocked.toggle() },
                onChanged: { adjustLockable(changed: .fat) }
            )
        }
    }

    enum MacroType { case protein, carbs, fat }

    private func adjustLockable(changed: MacroType) {
        let minPct: Double = 5

        // Clamp the changed one
        switch changed {
        case .protein: proteinPct = min(max(round(proteinPct), minPct), 90)
        case .carbs: carbsPct = min(max(round(carbsPct), minPct), 90)
        case .fat: fatPct = min(max(round(fatPct), minPct), 90)
        }

        // Determine which are free to move
        var free: [MacroType] = []
        if changed != .protein && !proteinLocked { free.append(.protein) }
        if changed != .carbs && !carbsLocked { free.append(.carbs) }
        if changed != .fat && !fatLocked { free.append(.fat) }

        let changedVal: Double = {
            switch changed {
            case .protein: return proteinPct
            case .carbs: return carbsPct
            case .fat: return fatPct
            }
        }()

        // Locked values (excluding the one being changed)
        var lockedTotal: Double = 0
        if changed != .protein && proteinLocked { lockedTotal += proteinPct }
        if changed != .carbs && carbsLocked { lockedTotal += carbsPct }
        if changed != .fat && fatLocked { lockedTotal += fatPct }

        let remainder = 100.0 - changedVal - lockedTotal

        if free.count == 2 {
            let freeTotal = free.reduce(0.0) { sum, m in
                switch m {
                case .protein: return sum + proteinPct
                case .carbs: return sum + carbsPct
                case .fat: return sum + fatPct
                }
            }
            for m in free {
                let currentVal: Double = {
                    switch m {
                    case .protein: return proteinPct
                    case .carbs: return carbsPct
                    case .fat: return fatPct
                    }
                }()
                let newVal = freeTotal > 0
                    ? max(round(remainder * currentVal / freeTotal), minPct)
                    : max(round(remainder / 2), minPct)
                switch m {
                case .protein: proteinPct = newVal
                case .carbs: carbsPct = newVal
                case .fat: fatPct = newVal
                }
            }
            // Fix rounding
            let total = proteinPct + carbsPct + fatPct
            if total != 100, let last = free.last {
                switch last {
                case .protein: proteinPct += (100.0 - total)
                case .carbs: carbsPct += (100.0 - total)
                case .fat: fatPct += (100.0 - total)
                }
            }
        } else if free.count == 1 {
            let newVal = max(remainder, minPct)
            switch free[0] {
            case .protein: proteinPct = newVal
            case .carbs: carbsPct = newVal
            case .fat: fatPct = newVal
            }
        }
    }

    private var macroDiv: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 1)
            .padding(.vertical, 10)
    }

    private func save() {
        let total = proteinPct + carbsPct + fatPct
        if total != 100 { fatPct += (100.0 - total) }

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
    let color: Color
    let locked: Bool
    let onLockTap: (() -> Void)?
    let onChanged: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                if let onLockTap {
                    Button(action: onLockTap) {
                        Image(systemName: locked ? "lock.fill" : "lock.open")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(locked ? color.opacity(0.8) : .white.opacity(0.15))
                            .frame(width: 20, height: 20)
                    }
                }

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
                    Text("\(grams)g")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(locked ? color.opacity(0.25) : color.opacity(0.5))
                        .frame(width: geo.size.width * pct / 100.0)
                }
                .frame(height: 4)
                .contentShape(Rectangle())
                .gesture(
                    locked ? nil :
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
        .opacity(locked ? 0.7 : 1.0)
    }
}

// MARK: - Macro Readonly Row (for waterfall remainder)
struct MacroReadonlyRow: View {
    let label: String
    let pct: Double
    let grams: Int
    let color: Color
    let hint: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(.textPrimary)

                Text(hint)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.12))
                    .italic()

                Spacer()

                HStack(spacing: 3) {
                    Text("\(Int(pct))%")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(color)
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.1))
                    Text("\(grams)g")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(color.opacity(0.35))
                        .frame(width: geo.size.width * pct / 100.0)
                        .animation(.easeOut(duration: 0.15), value: pct)
                }
            }
            .frame(height: 4)
        }
    }
}
