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
    @State private var currentDay: Int = 0
    @State private var isLoading = true

    @State private var weekAvgCalories: Float = 0
    @State private var weekAvgProtein: Float = 0
    @State private var weekAvgCarbs: Float = 0
    @State private var weekAvgFat: Float = 0
    @State private var caloriesDelta: Float = 0
    @State private var proteinDelta: Float = 0
    @State private var carbsDelta: Float = 0
    @State private var fatDelta: Float = 0

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
                        macroBalanceCard
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
        let todayDay = currentDay > 0 ? currentDay : cal.component(.day, from: today)

        return ZStack(alignment: .trailing) {
            // Left side content
            VStack(alignment: .leading, spacing: 0) {
                Text("GOAL MET")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .tracking(0.8)
                    .padding(.bottom, 14)

                Text("\(goalMetDays.count)")
                    .font(.system(size: 42, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.bottom, 4)

                Text("This Month")
                    .font(.system(size: 13))
                    .foregroundColor(.textMuted)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Dot grid — vertically centered in the full card
            dotGrid(
                daysInMonth: daysInMonth,
                firstWeekday: firstWeekday,
                todayDay: todayDay,
                metDays: goalMetDays
            )
            .padding(.trailing, 6)
        }
        .padding(14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    // MARK: - Macro Balance + Weekly Averages card
    private var macroBalanceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("THIS WEEK")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textMuted)
                    .tracking(0.8)

                Spacer()

                Text("vs last week")
                    .font(.system(size: 10))
                    .foregroundColor(.textVeryMuted)
            }
            .padding(.bottom, 16)

            HStack(alignment: .center, spacing: 0) {
                macroRing
                    .frame(width: 110, height: 110)
                    .padding(.leading, 8)

                Spacer()

                VStack(spacing: 10) {
                    statRow(label: "CALORIES", value: "\(Int(weekAvgCalories))", delta: caloriesDelta)
                    statRow(label: "PROTEIN", value: "\(Int(weekAvgProtein))g", delta: proteinDelta)
                    statRow(label: "CARBS", value: "\(Int(weekAvgCarbs))g", delta: carbsDelta)
                    statRow(label: "FAT", value: "\(Int(weekAvgFat))g", delta: fatDelta)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    // MARK: - Macro ring
    private var macroRing: some View {
        let total = max(weekAvgProtein * 4 + weekAvgCarbs * 4 + weekAvgFat * 9, 1)
        let proteinPct = (weekAvgProtein * 4) / total
        let carbsPct = (weekAvgCarbs * 4) / total
        let fatPct = (weekAvgFat * 9) / total

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 14)

            Circle()
                .trim(from: 0, to: CGFloat(proteinPct))
                .stroke(macroColors.protein.opacity(0.85), style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: CGFloat(proteinPct), to: CGFloat(proteinPct + carbsPct))
                .stroke(macroColors.carbs.opacity(0.85), style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: CGFloat(proteinPct + carbsPct), to: CGFloat(proteinPct + carbsPct + fatPct))
                .stroke(macroColors.fat.opacity(0.85), style: StrokeStyle(lineWidth: 14, lineCap: .butt))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(proteinPct * 100))/\(Int(carbsPct * 100))/\(Int(fatPct * 100))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                Text("P/C/F")
                    .font(.system(size: 8))
                    .foregroundColor(.textVeryMuted)
                    .tracking(0.5)
            }
        }
    }

    // MARK: - Stat row
    private func statRow(label: String, value: String, delta: Float) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.textVeryMuted)
                .tracking(0.6)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 70, alignment: .leading)

            deltaLabel(delta)
                .frame(width: 50, alignment: .trailing)
        }
    }

    // MARK: - Delta label
    private func deltaLabel(_ delta: Float) -> some View {
        Group {
            if delta != 0 {
                let arrow = delta > 0 ? "↑" : "↓"
                let color: Color = delta > 0 ? .green.opacity(0.8) : .red.opacity(0.7)
                Text("\(arrow) \(Int(abs(delta)))")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(color)
            } else {
                Text(" ")
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
            }
        }
    }

    // MARK: - Dot grid
    private func dotGrid(daysInMonth: Int, firstWeekday: Int, todayDay: Int, metDays: Set<Int>) -> some View {
        let offset = firstWeekday - 1

        // Build flat array: nil for blank offset cells, Int for day numbers
        let cells: [Int?] = Array(repeating: nil, count: offset) + (1...daysInMonth).map { $0 }
        let weeks = stride(from: 0, to: cells.count, by: 7).map {
            Array(cells[$0..<min($0 + 7, cells.count)])
        }

        return VStack(spacing: 8) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 8) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, cell in
                        if let day = cell {
                            dotCell(day: day, todayDay: todayDay, metDays: metDays)
                        } else {
                            Color.clear.frame(width: 10, height: 10)
                        }
                    }
                    // Pad trailing cells in last row
                    if week.count < 7 {
                        ForEach(0..<(7 - week.count), id: \.self) { _ in
                            Color.clear.frame(width: 10, height: 10)
                        }
                    }
                }
            }
        }
    }

    private func dotCell(day: Int, todayDay: Int, metDays: Set<Int>) -> some View {
        let isMet = metDays.contains(day)
        let isToday = day == todayDay
        let isFuture = day > todayDay

        return ZStack {
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
            let todayDay = cal.component(.day, from: today)

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = cal.timeZone

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

            // Weekly averages
            func avg(daysAgoStart: Int, daysAgoEnd: Int) -> (cal: Float, p: Float, c: Float, f: Float) {
                var totals = (cal: Float(0), p: Float(0), c: Float(0), f: Float(0))
                var count = 0
                for daysAgo in daysAgoEnd...daysAgoStart {
                    let date = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: today))!
                    let key = formatter.string(from: date)
                    if let data = grouped[key] {
                        totals.cal += data.cal
                        totals.p += data.protein
                        totals.c += data.carbs
                        totals.f += data.fat
                        count += 1
                    }
                }
                let divisor = Float(max(count, 1))
                return (totals.cal / divisor, totals.p / divisor, totals.c / divisor, totals.f / divisor)
            }

            let thisWeek = avg(daysAgoStart: 6, daysAgoEnd: 0)
            let lastWeek = avg(daysAgoStart: 13, daysAgoEnd: 7)

            let goal = calGoal
            var metDays: Set<Int> = []
            let monthPrefix = String(formatter.string(from: firstOfMonth).prefix(7))

            for (dateStr, data) in grouped {
                guard dateStr.hasPrefix(monthPrefix) else { continue }
                if abs(data.cal - goal) <= 100 {
                    // Extract day directly from "YYYY-MM-DD" string to avoid timezone shifts
                    let dayStr = dateStr.suffix(2)
                    if let day = Int(dayStr) {
                        metDays.insert(day)
                    }
                }
            }

            await MainActor.run {
                self.chartEntries = chart
                self.goalMetDays = metDays
                self.currentDay = todayDay
                self.weekAvgCalories = thisWeek.cal
                self.weekAvgProtein = thisWeek.p
                self.weekAvgCarbs = thisWeek.c
                self.weekAvgFat = thisWeek.f
                self.caloriesDelta = thisWeek.cal - lastWeek.cal
                self.proteinDelta = thisWeek.p - lastWeek.p
                self.carbsDelta = thisWeek.c - lastWeek.c
                self.fatDelta = thisWeek.f - lastWeek.f
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
