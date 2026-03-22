import SwiftUI
import Charts
import Supabase

// MARK: - Data model for daily macro breakdown
struct DayMacroData: Identifiable {
    let id = UUID()
    let date: Date
    let totalCal: Float
    let proteinCal: Float  // protein grams × 4
    let carbCal: Float     // carb grams × 4
    let fatCal: Float      // fat grams × 9
}

// MARK: - Stacked series entry for the chart
struct MacroStackEntry: Identifiable {
    let id = UUID()
    let date: Date
    let macro: String     // "Protein", "Carbs", "Fat"
    let caloriesFrom: Float
    let stackBase: Float  // bottom of this band
    let stackTop: Float   // top of this band
}

// MARK: - Analytics View
struct AnalyticsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var days: [DayMacroData] = []
    @State private var stackEntries: [MacroStackEntry] = []
    @State private var isLoading = true
    @State private var selectedDay: DayMacroData?

    private var calGoal: Float { Float(authService.profile?.calGoal ?? 2200) }
    private var streak: Int { authService.profile?.effectiveStreak ?? 0 }
    private var longestStreak: Int { authService.profile?.streakLongest ?? 0 }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header — matches SettingsView
                HStack {
                    Text("Analytics")
                        .font(.headerDay)
                        .foregroundColor(.white)
                        .tracking(-0.8)

                    Spacer()

                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.calBarBlue)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Streak card
                        streakCard

                        // Chart card
                        if isLoading {
                            loadingCard
                        } else if days.isEmpty {
                            emptyCard
                        } else {
                            chartCard

                            // Selected day breakdown
                            if let day = selectedDay {
                                breakdownCard(day)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Streak card
    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("STREAK")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textMuted)
                .tracking(0.8)
                .padding(.bottom, 12)

            HStack(spacing: 0) {
                // Current
                HStack(spacing: 5) {
                    Text("🔥")
                        .font(.system(size: 20))
                    Text("\(streak)")
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .foregroundColor(.streakColor)
                }

                Spacer()

                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 1, height: 32)

                Spacer()

                // Longest
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(longestStreak)")
                        .font(.system(size: 28, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text("longest")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.textVeryMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    // MARK: - Loading card
    private var loadingCard: some View {
        VStack {
            ProgressView()
                .tint(.textMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    // MARK: - Empty card
    private var emptyCard: some View {
        VStack(spacing: 6) {
            Text("No data yet")
                .font(.system(size: 14))
                .foregroundColor(.textMuted)
            Text("Start logging to see your trends")
                .font(.system(size: 12))
                .foregroundColor(.textVeryMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    // MARK: - Chart card
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CALORIES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .tracking(0.8)

                Spacer()

                // Legend
                HStack(spacing: 10) {
                    legendDot("Protein", color: .proteinColor)
                    legendDot("Carbs", color: .carbColor)
                    legendDot("Fat", color: .fatColor)
                }
            }
            .padding(.bottom, 14)

            // Chart
            Chart {
                // Goal line
                RuleMark(y: .value("Goal", calGoal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.white.opacity(0.12))

                // Stacked areas — fat bottom, carbs middle, protein top
                ForEach(stackEntries) { entry in
                    AreaMark(
                        x: .value("Date", entry.date, unit: .day),
                        yStart: .value("Base", entry.stackBase),
                        yEnd: .value("Top", entry.stackTop)
                    )
                    .foregroundStyle(colorForMacro(entry.macro).opacity(0.4))
                    .interpolationMethod(.catmullRom)
                }

                // Top line (total calories)
                ForEach(days) { day in
                    LineMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Cal", day.proteinCal + day.carbCal + day.fatCal)
                    )
                    .foregroundStyle(.white.opacity(0.5))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }

                // Selected day indicator
                if let sel = selectedDay {
                    RuleMark(x: .value("Sel", sel.date, unit: .day))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .foregroundStyle(.white.opacity(0.15))
                }
            }
            .chartYScale(domain: 0 ... chartYMax)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(shortDateLabel(date))
                                .font(.system(size: 9))
                                .foregroundColor(.textVeryMuted)
                        }
                    }
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.03))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel {
                        if let cal = value.as(Double.self) {
                            Text("\(Int(cal))")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.textVeryMuted)
                        }
                    }
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.03))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x
                                    if let date: Date = proxy.value(atX: x) {
                                        let cal = Calendar.current
                                        selectedDay = days.first { d in
                                            cal.isDate(d.date, inSameDayAs: date)
                                        }
                                    }
                                }
                        )
                }
            }
            .frame(height: 200)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    private var chartYMax: Float {
        let dataMax = days.map { $0.proteinCal + $0.carbCal + $0.fatCal }.max() ?? calGoal
        return max(calGoal, dataMax) * 1.2
    }

    // MARK: - Breakdown card for selected day
    private func breakdownCard(_ day: DayMacroData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(fullDateLabel(day.date).uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .tracking(0.8)

                Spacer()

                HStack(spacing: 3) {
                    Text("\(Int(day.totalCal))")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("cal")
                        .font(.system(size: 11))
                        .foregroundColor(.textMuted)
                }
            }
            .padding(.bottom, 14)

            // Stacked bar — same style as SettingsView
            stackedBar(day)
                .padding(.bottom, 16)

            // Macro rows — same divider pattern as SettingsView
            macroRow(
                label: "Protein",
                grams: day.proteinCal / 4,
                cals: day.proteinCal,
                color: .proteinColor
            )

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .padding(.vertical, 10)

            macroRow(
                label: "Carbs",
                grams: day.carbCal / 4,
                cals: day.carbCal,
                color: .carbColor
            )

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .padding(.vertical, 10)

            macroRow(
                label: "Fat",
                grams: day.fatCal / 9,
                cals: day.fatCal,
                color: .fatColor
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    private func stackedBar(_ day: DayMacroData) -> some View {
        let total = max(day.proteinCal + day.carbCal + day.fatCal, 1)
        return GeometryReader { geo in
            HStack(spacing: 1.5) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.proteinColor.opacity(0.8))
                    .frame(width: max(geo.size.width * CGFloat(day.proteinCal / total), 4))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.carbColor.opacity(0.8))
                    .frame(width: max(geo.size.width * CGFloat(day.carbCal / total), 4))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.fatColor.opacity(0.8))
                    .frame(width: max(geo.size.width * CGFloat(day.fatCal / total), 4))
            }
        }
        .frame(height: 6)
    }

    // Macro row — mirrors SettingsView's slider row layout (label left, values right)
    private func macroRow(label: String, grams: Float, cals: Float, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.textPrimary)

            Spacer()

            HStack(spacing: 3) {
                Text("\(Int(cals))")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(color)
                Text("·")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.1))
                Text("\(Int(grams))g")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Legend dot
    private func legendDot(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.7))
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.textVeryMuted)
        }
    }

    // MARK: - Helpers
    private func colorForMacro(_ macro: String) -> Color {
        switch macro {
        case "Protein": return .proteinColor
        case "Carbs": return .carbColor
        case "Fat": return .fatColor
        default: return .white
        }
    }

    private func shortDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        let f = DateFormatter()
        f.dateFormat = "E"
        return f.string(from: date)
    }

    private func fullDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date)
    }

    // MARK: - Load data
    private func loadData() async {
        guard let userId = authService.userId else { return }

        do {
            let entries: [FoodLogEntry] = try await supabase
                .from("food_log")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("log_date", value: dateString(daysAgo: 13))
                .order("log_date", ascending: true)
                .execute()
                .value

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current

            var grouped: [String: (cal: Float, protein: Float, carbs: Float, fat: Float)] = [:]
            for entry in entries {
                var current = grouped[entry.logDate] ?? (0, 0, 0, 0)
                current.cal += entry.calories
                current.protein += entry.protein
                current.carbs += entry.carbs
                current.fat += entry.fat
                grouped[entry.logDate] = current
            }

            let cal = Calendar.current
            var result: [DayMacroData] = []
            for daysAgo in stride(from: 13, through: 0, by: -1) {
                let date = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
                let key = formatter.string(from: date)
                guard let data = grouped[key] else { continue }

                let proteinCal = data.protein * 4
                let carbCal = data.carbs * 4
                let fatCal = data.fat * 9

                result.append(DayMacroData(
                    date: date,
                    totalCal: data.cal,
                    proteinCal: proteinCal,
                    carbCal: carbCal,
                    fatCal: fatCal
                ))
            }

            var stacked: [MacroStackEntry] = []
            for day in result {
                let fatTop = day.fatCal
                let carbTop = fatTop + day.carbCal
                let proteinTop = carbTop + day.proteinCal

                stacked.append(MacroStackEntry(date: day.date, macro: "Fat", caloriesFrom: day.fatCal, stackBase: 0, stackTop: fatTop))
                stacked.append(MacroStackEntry(date: day.date, macro: "Carbs", caloriesFrom: day.carbCal, stackBase: fatTop, stackTop: carbTop))
                stacked.append(MacroStackEntry(date: day.date, macro: "Protein", caloriesFrom: day.proteinCal, stackBase: carbTop, stackTop: proteinTop))
            }

            await MainActor.run {
                self.days = result
                self.stackEntries = stacked
                self.isLoading = false
                self.selectedDay = result.last
            }
        } catch {
            print("Analytics load error: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func dateString(daysAgo: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
