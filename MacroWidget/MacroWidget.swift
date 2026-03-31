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
    private var remaining: Int { Int(s.calGoal - s.calories) }

    private var proteinColor: Color { Color(red: s.proteinColorR, green: s.proteinColorG, blue: s.proteinColorB) }
    private var carbsColor: Color { Color(red: s.carbsColorR, green: s.carbsColorG, blue: s.carbsColorB) }
    private var fatColor: Color { Color(red: s.fatColorR, green: s.fatColorG, blue: s.fatColorB) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Calorie ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: calPct)
                    .stroke(
                        calorieGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(abs(remaining))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(remaining >= 0 ? "left" : "over")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(width: 104, height: 104)

            Spacer()

            // Macro bars pinned to bottom
            HStack(spacing: 8) {
                MacroMiniBar(label: "P", value: s.protein, goal: s.proteinGoal, color: proteinColor)
                MacroMiniBar(label: "C", value: s.carbs, goal: s.carbGoal, color: carbsColor)
                MacroMiniBar(label: "F", value: s.fat, goal: s.fatGoal, color: fatColor)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
        }
        .widgetURL(URL(string: "macros://home"))
    }

    private var calorieGradient: LinearGradient {
        let over = s.calories - s.calGoal
        if over >= 100 {
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.35, blue: 0.35), Color(red: 0.85, green: 0.2, blue: 0.2)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if calPct >= 1 {
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
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text("\(Int(value))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(label)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }

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
        }
    }
}

// MARK: - Widget Configuration
struct MacroWidget: Widget {
    let kind: String = "MacroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MacroTimelineProvider()) { entry in
            MacroWidgetView(entry: entry)
                .containerBackground(Color(red: 0.07, green: 0.07, blue: 0.09), for: .widget)
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
        lastUpdated: Date(),
        proteinColorR: 0.47, proteinColorG: 0.75, proteinColorB: 1.0,
        carbsColorR: 1.0, carbsColorG: 0.78, carbsColorB: 0.35,
        fatColorR: 1.0, fatColorG: 0.47, fatColorB: 0.47
    ))
    MacroEntry(date: Date(), snapshot: MacroSnapshot(
        calories: 2400, calGoal: 2200,
        protein: 160, proteinGoal: 160,
        carbs: 250, carbGoal: 250,
        fat: 70, fatGoal: 70,
        lastUpdated: Date(),
        proteinColorR: 0.47, proteinColorG: 0.75, proteinColorB: 1.0,
        carbsColorR: 1.0, carbsColorG: 0.78, carbsColorB: 0.35,
        fatColorR: 1.0, fatColorG: 0.47, fatColorB: 0.47
    ))
}
