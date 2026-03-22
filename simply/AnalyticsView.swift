import SwiftUI
import Charts
import Supabase

// MARK: - One entry per macro per day
struct MacroChartEntry: Identifiable {
    let id = UUID()
    let date: Date
    let macro: String
    let calories: Float
}

// MARK: - Analytics View
struct AnalyticsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var chartEntries: [MacroChartEntry] = []
    @State private var goalMetDays: Set<Int> = []   // day-of-month ints where goal was met
    @State private var isLoading = true

    private var calGoal: Float { Float(authService.profile?.calGoal ?? 2200) }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
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
                        if isLoading {
                            loadingCard
                        } else if chartEntries.isEmpty {
                            emptyCard
                        } else {
                            chartCard
                        }

                        goalMetCard
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

                HStack(spacing: 10) {
                    legendDot("Protein", color: .proteinColor)
                    legendDot("Carbs", color: .carbColor)
                    legendDot("Fat", color: .fatColor)
                }
            }
            .padding(.bottom, 14)

            Chart(chartEntries) { entry in
                AreaMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Calories", entry.calories)
                )
                .foregroundStyle(by: .value("Macro", entry.macro))
            }
            .chartForegroundStyleScale([
                "Protein": Color.proteinColor.opacity(0.6),
                "Carbs": Color.carbColor.opacity(0.6),
                "Fat": Color.fatColor.opacity(0.6)
            ])
            .chartYScale(domain: 0 ... chartYMax)
            .chartXAxis {
                AxisMarks(values: xAxisDates) { value in
                    AxisValueLabel(anchor: value.index == 4 ? .topTrailing : .top) {
                        if let date = value.as(Date.self) {
                            Text(xAxisLabel(date))
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
            .chartLegend(.hidden)
            .frame(height: 240)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    private var chartYMax: Float {
        var dailyTotals: [Date: Float] = [:]
        for entry in chartEntries {
            dailyTotals[entry.date, default: 0] += entry.calories
        }
        let dataMax = dailyTotals.values.max() ?? calGoal
        return max(calGoal, dataMax) * 1.15
    }

    private var xAxisDates: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return [28, 21, 14, 7, 0].compactMap {
            cal.date(byAdding: .day, value: -$0, to: today)
        }
    }

    private func xAxisLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f.string(from: date)
    }

    // MARK: - Goal Met card
    private var goalMetCard: some View {
        let cal = Calendar.current
        let today = Date()
        let components = cal.dateComponents([.year, .month], from: today)
        let firstOfMonth = cal.date(from: components)!
        let range = cal.range(of: .day, in: .month, for: firstOfMonth)!
        let daysInMonth = range.count
        let firstWeekday = cal.component(.weekday, from: firstOfMonth) // 1 = Sunday
        let todayDay = cal.component(.day, from: today)

        return VStack(alignment: .leading, spacing: 0) {
            Text("GOAL MET")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textMuted)
                .tracking(0.8)
                .padding(.bottom, 14)

            HStack(alignment: .top, spacing: 0) {
                // Left side — count + label
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(goalMetDays.count)")
                        .font(.system(size: 42, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)

                    Text("This Month")
                        .font(.system(size: 13))
                        .foregroundColor(.textMuted)
                }
                .frame(minWidth: 90, alignment: .leading)

                Spacer()

                // Right side — dot grid calendar
                dotGrid(
                    daysInMonth: daysInMonth,
                    firstWeekday: firstWeekday,
                    todayDay: todayDay
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    // MARK: - Dot grid
    private func dotGrid(daysInMonth: Int, firstWeekday: Int, todayDay: Int) -> some View {
        let columns = Array(repeating: GridItem(.fixed(10), spacing: 8), count: 7)
        let offset = firstWeekday - 1  // empty slots before day 1

        return LazyVGrid(columns: columns, spacing: 8) {
            // Empty cells for offset
            ForEach(0..<offset, id: \.self) { _ in
                Color.clear.frame(width: 10, height: 10)
            }

            // Day cells
            ForEach(1...daysInMonth, id: \.self) { day in
                let isMet = goalMetDays.contains(day)
                let isToday = day == todayDay
                let isFuture = day > todayDay

                ZStack {
                    if isToday {
                        // Today — ring style
                        Circle()
                            .strokeBorder(isMet ? Color.white : Color.white.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                        if isMet {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 5, height: 5)
                        }
                    } else if isMet {
                        // Goal met — bright dot
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 10, height: 10)
                    } else {
                        // Not met or future — dim dot
                        Circle()
                            .fill(Color.white.opacity(isFuture ? 0.06 : 0.12))
                            .frame(width: 10, height: 10)
                    }
                }
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

    // MARK: - Load data
    private func loadData() async {
        guard let userId = authService.userId else { return }

        do {
            // Fetch entries covering both the 30-day chart window and the current month
            let cal = Calendar.current
            let today = Date()
            let components = cal.dateComponents([.year, .month], from: today)
            let firstOfMonth = cal.date(from: components)!

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = .current

            let thirtyDaysAgo = cal.date(byAdding: .day, value: -29, to: cal.startOfDay(for: today))!
            let queryStart = min(firstOfMonth, thirtyDaysAgo)

            let entries: [FoodLogEntry] = try await supabase
                .from("food_log")
                .select()
                .eq("user_id", value: userId.uuidString)
                .gte("log_date", value: formatter.string(from: queryStart))
                .order("log_date", ascending: true)
                .execute()
                .value

            // Aggregate by date
            var grouped: [String: (protein: Float, carbs: Float, fat: Float, cal: Float)] = [:]
            for entry in entries {
                var current = grouped[entry.logDate] ?? (0, 0, 0, 0)
                current.protein += entry.protein
                current.carbs += entry.carbs
                current.fat += entry.fat
                current.cal += entry.calories
                grouped[entry.logDate] = current
            }

            // Build chart entries (last 30 days)
            var chart: [MacroChartEntry] = []
            for daysAgo in stride(from: 29, through: 0, by: -1) {
                let date = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: today))!
                let key = formatter.string(from: date)
                let data = grouped[key]

                let proteinCal = (data?.protein ?? 0) * 4
                let carbCal = (data?.carbs ?? 0) * 4
                let fatCal = (data?.fat ?? 0) * 9

                chart.append(MacroChartEntry(date: date, macro: "Fat", calories: fatCal))
                chart.append(MacroChartEntry(date: date, macro: "Carbs", calories: carbCal))
                chart.append(MacroChartEntry(date: date, macro: "Protein", calories: proteinCal))
            }

            // Build goal-met days for current month
            let goal = calGoal
            var metDays: Set<Int> = []
            let monthString = formatter.string(from: firstOfMonth).prefix(7) // "2026-03"

            for (dateStr, data) in grouped {
                guard dateStr.hasPrefix(String(monthString)) else { continue }
                if abs(data.cal - goal) <= 100 {
                    // Extract day number
                    if let date = formatter.date(from: dateStr) {
                        let day = cal.component(.day, from: date)
                        metDays.insert(day)
                    }
                }
            }

            await MainActor.run {
                self.chartEntries = chart
                self.goalMetDays = metDays
                self.isLoading = false
            }
        } catch {
            print("Analytics load error: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
