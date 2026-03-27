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
    @EnvironmentObject var macroColors: MacroColors
    @Environment(\.dismiss) var dismiss

    @State private var chartEntries: [MacroChartEntry] = []
    @State private var goalMetDays: Set<Int> = []
    @State private var isLoading = true

    private var calGoal: Float { Float(authService.profile?.calGoal ?? 2200) }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
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
                        streakCard
                        chartCard
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

    // MARK: - Chart card
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("CALORIES")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .tracking(0.8)

                Spacer()

                if !chartEntries.isEmpty {
                    HStack(spacing: 10) {
                        legendDot("Protein", color: macroColors.protein)
                        legendDot("Carbs", color: macroColors.carbs)
                        legendDot("Fat", color: macroColors.fat)
                    }
                }
            }
            .padding(.bottom, 14)

            if isLoading {
                VStack {
                    ProgressView()
                        .tint(.textMuted)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
            } else if chartEntries.isEmpty {
                VStack(spacing: 6) {
                    Text("No data yet")
                        .font(.system(size: 14))
                        .foregroundColor(.textMuted)
                    Text("Start logging to see your trends")
                        .font(.system(size: 12))
                        .foregroundColor(.textVeryMuted)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 240)
            } else {
                Chart(chartEntries) { entry in
                    AreaMark(
                        x: .value("Date", entry.date, unit: .day),
                        y: .value("Calories", entry.calories)
                    )
                    .foregroundStyle(by: .value("Macro", entry.macro))
                }
                .chartForegroundStyleScale([
                    "Protein": macroColors.protein.opacity(0.6),
                    "Carbs": macroColors.carbs.opacity(0.6),
                    "Fat": macroColors.fat.opacity(0.6)
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

    // MARK: - Streak card
    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("STREAK")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textMuted)
                .tracking(0.8)
                .padding(.bottom, 12)

            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.system(size: 16))
                    Text("\(authService.profile?.effectiveStreak ?? 0)")
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundColor(.streakColor)
                    Text("days")
                        .font(.system(size: 12))
                        .foregroundColor(.textMuted)
                }

                Spacer()

                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 1, height: 24)

                Spacer()

                HStack(spacing: 6) {
                    Text("\(authService.profile?.streakLongest ?? 0)")
                        .font(.system(size: 22, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                    Text("longest")
                        .font(.system(size: 12))
                        .foregroundColor(.textVeryMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    // MARK: - Goal Met card
    private var goalMetCard: some View {
        let cal = Calendar.current
        let today = Date()
        let components = cal.dateComponents([.year, .month], from: today)
        let firstOfMonth = cal.date(from: components)!
        let range = cal.range(of: .day, in: .month, for: firstOfMonth)!
        let daysInMonth = range.count
        let firstWeekday = cal.component(.weekday, from: firstOfMonth)
        let todayDay = cal.component(.day, from: today)

        return VStack(alignment: .leading, spacing: 0) {
            Text("GOAL MET")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.textMuted)
                .tracking(0.8)
                .padding(.bottom, 14)

            HStack(alignment: .top, spacing: 0) {
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
        let offset = firstWeekday - 1

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<offset, id: \.self) { _ in
                Color.clear.frame(width: 10, height: 10)
            }

            ForEach(1...daysInMonth, id: \.self) { day in
                let isMet = goalMetDays.contains(day)
                let isToday = day == todayDay
                let isFuture = day > todayDay

                ZStack {
                    if isToday {
                        Circle()
                            .strokeBorder(isMet ? Color.white : Color.white.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 10, height: 10)
                        if isMet {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 5, height: 5)
                        }
                    } else if isMet {
                        Circle()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 10, height: 10)
                    } else {
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

            var grouped: [String: (protein: Float, carbs: Float, fat: Float, cal: Float)] = [:]
            for entry in entries {
                var current = grouped[entry.logDate] ?? (0, 0, 0, 0)
                current.protein += entry.protein
                current.carbs += entry.carbs
                current.fat += entry.fat
                current.cal += entry.calories
                grouped[entry.logDate] = current
            }

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

            let goal = calGoal
            var metDays: Set<Int> = []
            let monthString = formatter.string(from: firstOfMonth).prefix(7)

            for (dateStr, data) in grouped {
                guard dateStr.hasPrefix(String(monthString)) else { continue }
                if abs(data.cal - goal) <= 100 {
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
