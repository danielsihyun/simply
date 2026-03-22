import SwiftUI
import Charts
import Supabase

// MARK: - One entry per macro per day
struct MacroChartEntry: Identifiable {
    let id = UUID()
    let date: Date
    let macro: String      // "Protein", "Carbs", "Fat"
    let calories: Float
}

// MARK: - Analytics View
struct AnalyticsView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) var dismiss

    @State private var chartEntries: [MacroChartEntry] = []
    @State private var isLoading = true

    private var calGoal: Float { Float(authService.profile?.calGoal ?? 2200) }

    // Fixed order so Swift Charts stacks consistently
    private let macroOrder = ["Fat", "Carbs", "Protein"]

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
                AxisMarks(values: .stride(by: .day, count: 2)) { value in
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
            .chartLegend(.hidden)
            .frame(height: 240)

            // Goal label
            HStack {
                Spacer()
                Text("goal: \(Int(calGoal)) cal")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.textVeryMuted)
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.bgCard)
        .cornerRadius(14)
    }

    private var chartYMax: Float {
        // Sum calories per day to find the peak
        var dailyTotals: [Date: Float] = [:]
        for entry in chartEntries {
            dailyTotals[entry.date, default: 0] += entry.calories
        }
        let dataMax = dailyTotals.values.max() ?? calGoal
        return max(calGoal, dataMax) * 1.15
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
    private func shortDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        let f = DateFormatter()
        f.dateFormat = "M/d"
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

            // Aggregate by date
            var grouped: [String: (protein: Float, carbs: Float, fat: Float)] = [:]
            for entry in entries {
                var current = grouped[entry.logDate] ?? (0, 0, 0)
                current.protein += entry.protein
                current.carbs += entry.carbs
                current.fat += entry.fat
                grouped[entry.logDate] = current
            }

            let cal = Calendar.current
            var chart: [MacroChartEntry] = []

            // All 14 days — zeros for days with no data so the area is continuous
            for daysAgo in stride(from: 13, through: 0, by: -1) {
                let date = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
                let key = formatter.string(from: date)
                let data = grouped[key]

                let proteinCal = (data?.protein ?? 0) * 4
                let carbCal = (data?.carbs ?? 0) * 4
                let fatCal = (data?.fat ?? 0) * 9

                // Order: Fat, Carbs, Protein — stacked bottom to top
                chart.append(MacroChartEntry(date: date, macro: "Fat", calories: fatCal))
                chart.append(MacroChartEntry(date: date, macro: "Carbs", calories: carbCal))
                chart.append(MacroChartEntry(date: date, macro: "Protein", calories: proteinCal))
            }

            await MainActor.run {
                self.chartEntries = chart
                self.isLoading = false
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
