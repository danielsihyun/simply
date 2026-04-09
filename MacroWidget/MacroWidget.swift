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
        let now = Date()
        let calendar = Calendar.current

        // Check if the snapshot is from a previous day — if so, show zeros
        let snapshotIsToday = calendar.isDateInToday(snapshot.lastUpdated)
        let currentSnapshot = snapshotIsToday ? snapshot : MacroSnapshot(
            calories: 0,
            calGoal: snapshot.calGoal,
            protein: 0,
            proteinGoal: snapshot.proteinGoal,
            carbs: 0,
            carbGoal: snapshot.carbGoal,
            fat: 0,
            fatGoal: snapshot.fatGoal,
            lastUpdated: now,
            caloriesColorR: snapshot.caloriesColorR,
            caloriesColorG: snapshot.caloriesColorG,
            caloriesColorB: snapshot.caloriesColorB,
            proteinColorR: snapshot.proteinColorR,
            proteinColorG: snapshot.proteinColorG,
            proteinColorB: snapshot.proteinColorB,
            carbsColorR: snapshot.carbsColorR,
            carbsColorG: snapshot.carbsColorG,
            carbsColorB: snapshot.carbsColorB,
            fatColorR: snapshot.fatColorR,
            fatColorG: snapshot.fatColorG,
            fatColorB: snapshot.fatColorB
        )

        let entry = MacroEntry(date: now, snapshot: currentSnapshot)

        // Schedule refresh right after midnight
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        let midnightRefresh = calendar.date(byAdding: .second, value: 5, to: tomorrow)!

        // Also refresh in 15 min for normal updates
        let regularRefresh = calendar.date(byAdding: .minute, value: 15, to: now)!

        // Use whichever comes first
        let nextRefresh = min(midnightRefresh, regularRefresh)

        let timeline = Timeline(entries: [entry], policy: .after(nextRefresh))
        completion(timeline)
    }
}

// MARK: - Widget View
struct MacroWidgetView: View {
    let entry: MacroEntry

    private var s: MacroSnapshot { entry.snapshot }
    private var calPct: CGFloat { s.calGoal > 0 ? min(CGFloat(s.calories / s.calGoal), 1) : 0 }
    private var remaining: Int { Int(s.calGoal - s.calories) }

    private var caloriesColor: Color { Color(red: s.caloriesColorR, green: s.caloriesColorG, blue: s.caloriesColorB) }
    private var proteinColor: Color { Color(red: s.proteinColorR, green: s.proteinColorG, blue: s.proteinColorB) }
    private var carbsColor: Color { Color(red: s.carbsColorR, green: s.carbsColorG, blue: s.carbsColorB) }
    private var fatColor: Color { Color(red: s.fatColorR, green: s.fatColorG, blue: s.fatColorB) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: calPct)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(abs(remaining))")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(remaining >= 0 ? "left" : "over")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(width: 112, height: 112)

            Spacer()

            HStack(spacing: 8) {
                MacroMiniBar(label: "P", value: s.protein, goal: s.proteinGoal, color: proteinColor)
                MacroMiniBar(label: "C", value: s.carbs, goal: s.carbGoal, color: carbsColor)
                MacroMiniBar(label: "F", value: s.fat, goal: s.fatGoal, color: fatColor)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .widgetURL(URL(string: "macros://home"))
    }

    private var ringColor: Color {
        let over = s.calories - s.calGoal
        if over >= 100 {
            return Color(red: 1.0, green: 0.35, blue: 0.35)
        }
        return caloriesColor
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
