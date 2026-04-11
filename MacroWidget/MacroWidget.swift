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

// MARK: - Widget View (dispatches by family)
struct MacroWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MacroEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                MediumMacroWidgetView(entry: entry)
            case .systemLarge:
                LargeMacroWidgetView(entry: entry)
            default:
                SmallMacroWidgetView(entry: entry)
            }
        }
        .widgetURL(URL(string: "macros://home"))
    }
}

// MARK: - Shared color helpers
private extension MacroSnapshot {
    var caloriesColor: Color { Color(red: caloriesColorR, green: caloriesColorG, blue: caloriesColorB) }
    var proteinColor: Color { Color(red: proteinColorR, green: proteinColorG, blue: proteinColorB) }
    var carbsColor: Color { Color(red: carbsColorR, green: carbsColorG, blue: carbsColorB) }
    var fatColor: Color { Color(red: fatColorR, green: fatColorG, blue: fatColorB) }

    var calPct: CGFloat { calGoal > 0 ? min(CGFloat(calories / calGoal), 1) : 0 }
    var remaining: Int { Int(calGoal - calories) }

    var calorieRingColor: Color {
        let over = calories - calGoal
        if over >= 100 { return Color(red: 1.0, green: 0.35, blue: 0.35) }
        return caloriesColor
    }
}

// MARK: - Small widget (2x2)
struct SmallMacroWidgetView: View {
    let entry: MacroEntry
    private var s: MacroSnapshot { entry.snapshot }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: s.calPct)
                    .stroke(
                        s.calorieRingColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(abs(s.remaining))")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(s.remaining >= 0 ? "left" : "over")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(width: 112, height: 112)

            Spacer()

            HStack(spacing: 8) {
                MacroMiniBar(label: "P", value: s.protein, goal: s.proteinGoal, color: s.proteinColor)
                MacroMiniBar(label: "C", value: s.carbs, goal: s.carbGoal, color: s.carbsColor)
                MacroMiniBar(label: "F", value: s.fat, goal: s.fatGoal, color: s.fatColor)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Medium widget (4x2): ring on the left, detailed bars on the right
struct MediumMacroWidgetView: View {
    let entry: MacroEntry
    private var s: MacroSnapshot { entry.snapshot }

    var body: some View {
        HStack(spacing: 18) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 7)

                    Circle()
                        .trim(from: 0, to: s.calPct)
                        .stroke(
                            s.calorieRingColor,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 1) {
                        Text("\(abs(s.remaining))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)

                        Text(s.remaining >= 0 ? "left" : "over")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                .frame(width: 116, height: 116)

                Text("\(Int(s.calories)) / \(Int(s.calGoal)) cal")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
            }

            VStack(spacing: 10) {
                MacroDetailRow(label: "Protein", value: s.protein, goal: s.proteinGoal, color: s.proteinColor)
                MacroDetailRow(label: "Carbs", value: s.carbs, goal: s.carbGoal, color: s.carbsColor)
                MacroDetailRow(label: "Fat", value: s.fat, goal: s.fatGoal, color: s.fatColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

// MARK: - Large widget (4x4): centered ring + 4-cell detail grid
struct LargeMacroWidgetView: View {
    let entry: MacroEntry
    private var s: MacroSnapshot { entry.snapshot }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 9)

                Circle()
                    .trim(from: 0, to: s.calPct)
                    .stroke(
                        s.calorieRingColor,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(abs(s.remaining))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)

                    Text(s.remaining >= 0 ? "calories left" : "calories over")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    Text("\(Int(s.calories)) / \(Int(s.calGoal))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.top, 2)
                }
            }
            .frame(width: 168, height: 168)

            VStack(spacing: 10) {
                MacroDetailRow(label: "Protein", value: s.protein, goal: s.proteinGoal, color: s.proteinColor)
                MacroDetailRow(label: "Carbs", value: s.carbs, goal: s.carbGoal, color: s.carbsColor)
                MacroDetailRow(label: "Fat", value: s.fat, goal: s.fatGoal, color: s.fatColor)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
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

// MARK: - Detailed macro row for medium / large widgets
struct MacroDetailRow: View {
    let label: String
    let value: Float
    let goal: Float
    let color: Color

    private var pct: CGFloat { goal > 0 ? min(CGFloat(value / goal), 1) : 0 }
    private var remaining: Int { max(Int(goal - value), 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(.white.opacity(0.45))

                Spacer()

                HStack(spacing: 3) {
                    Text("\(Int(value))")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(color)
                    Text("/ \(Int(goal))g")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 4)
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews
private let previewSnapshot = MacroSnapshot(
    calories: 1450, calGoal: 2200,
    protein: 120, proteinGoal: 160,
    carbs: 180, carbGoal: 250,
    fat: 45, fatGoal: 70,
    lastUpdated: Date(),
    caloriesColorR: 0.36, caloriesColorG: 0.61, caloriesColorB: 0.96,
    proteinColorR: 0.42, proteinColorG: 0.87, proteinColorB: 0.72,
    carbsColorR: 0.69, carbsColorG: 0.49, carbsColorB: 1.0,
    fatColorR: 0.96, fatColorG: 0.64, fatColorB: 0.38
)

#Preview(as: .systemSmall) {
    MacroWidget()
} timeline: {
    MacroEntry(date: Date(), snapshot: previewSnapshot)
}

#Preview(as: .systemMedium) {
    MacroWidget()
} timeline: {
    MacroEntry(date: Date(), snapshot: previewSnapshot)
}

#Preview(as: .systemLarge) {
    MacroWidget()
} timeline: {
    MacroEntry(date: Date(), snapshot: previewSnapshot)
}
