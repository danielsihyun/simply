import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct MacroEntry: TimelineEntry {
    let date: Date
    let snapshot: MacroSnapshot
}

// MARK: - Timeline Provider
struct MacroTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MacroEntry {
        MacroEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (MacroEntry) -> Void) {
        let snapshot = SharedDefaults.load()
        completion(MacroEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MacroEntry>) -> Void) {
        let snapshot = SharedDefaults.load()
        let entry = MacroEntry(date: Date(), snapshot: snapshot)

        // Refresh after 15 minutes or when the app triggers a reload
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View
struct MacroWidgetView: View {
    let entry: MacroEntry

    private var s: MacroSnapshot { entry.snapshot }
    private var calPct: CGFloat { s.calGoal > 0 ? min(CGFloat(s.calories / s.calGoal), 1) : 0 }
    private var proteinPct: CGFloat { s.proteinGoal > 0 ? min(CGFloat(s.protein / s.proteinGoal), 1) : 0 }
    private var carbsPct: CGFloat { s.carbGoal > 0 ? min(CGFloat(s.carbs / s.carbGoal), 1) : 0 }
    private var fatPct: CGFloat { s.fatGoal > 0 ? min(CGFloat(s.fat / s.fatGoal), 1) : 0 }
    private var remaining: Int { Int(s.calGoal - s.calories) }

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.07, green: 0.07, blue: 0.09)

            VStack(spacing: 0) {
                // Calorie ring + center text
                ZStack {
                    // Track
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 5)

                    // Calorie arc
                    Circle()
                        .trim(from: 0, to: calPct)
                        .stroke(
                            calorieGradient,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    // Center text
                    VStack(spacing: 1) {
                        Text("\(abs(remaining))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)

                        Text(remaining >= 0 ? "left" : "over")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(remaining >= 0 ? .white.opacity(0.4) : Color(red: 1.0, green: 0.47, blue: 0.47).opacity(0.8))
                    }
                }
                .frame(width: 72, height: 72)
                .padding(.top, 10)

                Spacer().frame(height: 8)

                // Macro bars
                HStack(spacing: 8) {
                    MacroMiniBar(label: "P", value: s.protein, goal: s.proteinGoal, color: Color(red: 0.47, green: 0.75, blue: 1.0))
                    MacroMiniBar(label: "C", value: s.carbs, goal: s.carbGoal, color: Color(red: 1.0, green: 0.78, blue: 0.35))
                    MacroMiniBar(label: "F", value: s.fat, goal: s.fatGoal, color: Color(red: 1.0, green: 0.47, blue: 0.47))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .widgetURL(URL(string: "macros://home"))
    }

    private var calorieGradient: LinearGradient {
        if calPct >= 1 {
            return LinearGradient(
                colors: [Color(red: 0.3, green: 0.85, blue: 0.45), Color(red: 0.2, green: 0.7, blue: 0.35)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [Color(red: 0.35, green: 0.55, blue: 1.0), Color(red: 0.6, green: 0.4, blue: 1.0)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Macro mini bar for small widget
struct MacroMiniBar: View {
    let label: String
    let value: Float
    let goal: Float
    let color: Color

    private var pct: CGFloat { goal > 0 ? min(CGFloat(value / goal), 1) : 0 }

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Int(value))")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color.opacity(0.8))
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 2.5)

            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
        }
    }
}

// MARK: - Widget Configuration
struct MacroWidget: Widget {
    let kind: String = "MacroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MacroTimelineProvider()) { entry in
            MacroWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Macros")
        .description("Track your calories, protein, carbs, and fat at a glance.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    MacroWidget()
} timeline: {
    MacroEntry(date: Date(), snapshot: MacroSnapshot(
        calories: 1450, calGoal: 2200,
        protein: 120, proteinGoal: 160,
        carbs: 180, carbGoal: 250,
        fat: 45, fatGoal: 70,
        lastUpdated: Date()
    ))
    MacroEntry(date: Date(), snapshot: MacroSnapshot(
        calories: 2200, calGoal: 2200,
        protein: 160, proteinGoal: 160,
        carbs: 250, carbGoal: 250,
        fat: 70, fatGoal: 70,
        lastUpdated: Date()
    ))
}
