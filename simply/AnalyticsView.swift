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
    @Environment(\.dismiss) private var dismiss

    @State private var days: [DayMacroData] = []
    @State private var stackEntries: [MacroStackEntry] = []
    @State private var isLoading = true
    @State private var selectedDay: DayMacroData?

    private var calGoal: Float { Float(authService.profile?.calGoal ?? 2200) }
    private var streak: Int { authService.profile?.effectiveStreak ?? 0 }
    private var longestStreak: Int { authService.profile?.streakLongest ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Streak header
                    streakHeader
                        .padding(.horizontal, 18)

                    // Chart
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if days.isEmpty {
                        Text("No data yet — start logging to see your trends.")
                            .font(.system(size: 14))
                            .foregroundColor(.textMuted)
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        calorieChart
                            .padding(.horizontal, 18)

                        // Selected day detail
                        if let day = selectedDay {
                            selectedDayDetail(day)
                                .padding(.horizontal, 18)
                        }

                        // Legend
                        legendView
                            .padding(.horizontal, 18)
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
            .background(Color.bgPrimary.ignoresSafeArea())
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Streak header
    private var streakHeader: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.system(size: 22))
                    Text("\(streak)")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.streakColor)
                }
                Text("current streak")
                    .font(.system(size: 11))
                    .foregroundColor(.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 1, height: 36)

            VStack(spacing: 4) {
                Text("\(longestStreak)")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Text("longest streak")
                    .font(.system(size: 11))
                    .foregroundColor(.textMuted)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    // MARK: - Calorie chart with stacked macro areas
    private var calorieChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Calories")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            Chart {
                // Goal line
                RuleMark(y: .value("Goal", calGoal))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.white.opacity(0.15))
                    .annotation(position: .topTrailing, alignment: .trailing) {
                        Text("goal")
                            .font(.system(size: 9))
                            .foregroundColor(.textVeryMuted)
                    }

                // Stacked areas — draw fat first (bottom), then carbs, then protein (top)
                ForEach(stackEntries) { entry in
                    AreaMark(
                        x: .value("Date", entry.date, unit: .day),
                        yStart: .value("Base", entry.stackBase),
                        yEnd: .value("Top", entry.stackTop)
                    )
                    .foregroundStyle(colorForMacro(entry.macro).opacity(0.45))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Top", entry.stackTop)
                    )
                    .foregroundStyle(colorForMacro(entry.macro).opacity(
                        entry.macro == "Protein" ? 0.7 : 0.0
                    ))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: entry.macro == "Protein" ? 2 : 0))
                }
            }
            .chartYScale(domain: 0 ... max(calGoal * 1.3, (days.map(\.totalCal).max() ?? calGoal) * 1.15))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(shortDateLabel(date))
                                .font(.system(size: 9))
                                .foregroundColor(.textMuted)
                        }
                    }
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.04))
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
                        .foregroundStyle(.white.opacity(0.04))
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
                                .onEnded { _ in }
                        )
                }
            }
            .frame(height: 220)
        }
        .padding(14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    // MARK: - Selected day detail
    private func selectedDayDetail(_ day: DayMacroData) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(fullDateLabel(day.date))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textPrimary)
                Spacer()
                Text("\(Int(day.totalCal)) cal")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            }

            HStack(spacing: 0) {
                let total = max(day.proteinCal + day.carbCal + day.fatCal, 1)
                macroSegment(
                    label: "\(Int(day.proteinCal / 4))g protein",
                    fraction: CGFloat(day.proteinCal / total),
                    color: .proteinColor
                )
                macroSegment(
                    label: "\(Int(day.carbCal / 4))g carbs",
                    fraction: CGFloat(day.carbCal / total),
                    color: .carbColor
                )
                macroSegment(
                    label: "\(Int(day.fatCal / 9))g fat",
                    fraction: CGFloat(day.fatCal / total),
                    color: .fatColor
                )
            }
            .frame(height: 6)
            .clipShape(Capsule())

            HStack(spacing: 16) {
                macroStat("Protein", grams: day.proteinCal / 4, cals: day.proteinCal, color: .proteinColor)
                macroStat("Carbs", grams: day.carbCal / 4, cals: day.carbCal, color: .carbColor)
                macroStat("Fat", grams: day.fatCal / 9, cals: day.fatCal, color: .fatColor)
            }
        }
        .padding(14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    private func macroSegment(label: String, fraction: CGFloat, color: Color) -> some View {
        GeometryReader { geo in
            Rectangle()
                .fill(color.opacity(0.7))
                .frame(width: geo.size.width * fraction)
        }
    }

    private func macroStat(_ label: String, grams: Float, cals: Float, color: Color) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Text("\(Int(grams))g")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(color)
            }
            Text("\(Int(cals)) cal")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.textVeryMuted)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Legend
    private var legendView: some View {
        HStack(spacing: 16) {
            legendDot("Protein", color: .proteinColor)
            legendDot("Carbs", color: .carbColor)
            legendDot("Fat", color: .fatColor)
            Spacer()
        }
    }

    private func legendDot(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color.opacity(0.7))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.textMuted)
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
            struct DayRow: Decodable {
                let logDate: String
                let totalCal: Float
                let totalProtein: Float
                let totalCarbs: Float
                let totalFat: Float

                enum CodingKeys: String, CodingKey {
                    case logDate = "log_date"
                    case totalCal = "total_cal"
                    case totalProtein = "total_protein"
                    case totalCarbs = "total_carbs"
                    case totalFat = "total_fat"
                }
            }

            // Fetch last 14 days of aggregated data using RPC or raw query via the food_log table
            // We'll aggregate client-side from food_log entries
            let entries: [FoodLogEntry] = try await supabase
                .from("food_log")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("log_date", value: dateString(daysAgo: 13))
                .order("log_date", ascending: true)
                .execute()
                .value

            // Group by date
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

            // Build day data, filling in empty days with zeros
            var result: [DayMacroData] = []
            let cal = Calendar.current
            for daysAgo in stride(from: 13, through: 0, by: -1) {
                let date = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
                let key = formatter.string(from: date)
                let data = grouped[key]
                let proteinCal = (data?.protein ?? 0) * 4
                let carbCal = (data?.carbs ?? 0) * 4
                let fatCal = (data?.fat ?? 0) * 9

                result.append(DayMacroData(
                    date: date,
                    totalCal: data?.cal ?? 0,
                    proteinCal: proteinCal,
                    carbCal: carbCal,
                    fatCal: fatCal
                ))
            }

            // Build stacked entries: fat on bottom, carbs in middle, protein on top
            var stacked: [MacroStackEntry] = []
            for day in result {
                let fatBase: Float = 0
                let fatTop = fatBase + day.fatCal
                let carbTop = fatTop + day.carbCal
                let proteinTop = carbTop + day.proteinCal

                stacked.append(MacroStackEntry(date: day.date, macro: "Fat", caloriesFrom: day.fatCal, stackBase: fatBase, stackTop: fatTop))
                stacked.append(MacroStackEntry(date: day.date, macro: "Carbs", caloriesFrom: day.carbCal, stackBase: fatTop, stackTop: carbTop))
                stacked.append(MacroStackEntry(date: day.date, macro: "Protein", caloriesFrom: day.proteinCal, stackBase: carbTop, stackTop: proteinTop))
            }

            await MainActor.run {
                self.days = result
                self.stackEntries = stacked
                self.isLoading = false
                // Auto-select today
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
