import WidgetKit
import SwiftUI

struct VitalsEntry: TimelineEntry {
    let date: Date
    let compositeScore: Int
    let topGoal: String
    let topGoalStatus: String
    let pillarsActive: Int
}

struct VitalsProvider: TimelineProvider {
    func placeholder(in context: Context) -> VitalsEntry {
        VitalsEntry(date: .now, compositeScore: 54, topGoal: "Lean body", topGoalStatus: "on track", pillarsActive: 6)
    }

    func getSnapshot(in context: Context, completion: @escaping (VitalsEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VitalsEntry>) -> Void) {
        let entry = VitalsEntry(
            date: .now,
            compositeScore: UserDefaults(suiteName: "group.com.ambidash.app")?.integer(forKey: "widget_composite") ?? 50,
            topGoal: UserDefaults(suiteName: "group.com.ambidash.app")?.string(forKey: "widget_top_goal") ?? "Open AmbiDash",
            topGoalStatus: UserDefaults(suiteName: "group.com.ambidash.app")?.string(forKey: "widget_top_status") ?? "",
            pillarsActive: UserDefaults(suiteName: "group.com.ambidash.app")?.integer(forKey: "widget_pillars") ?? 0
        )
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1800)))
        completion(timeline)
    }
}

struct AmbidashWidgetEntryView: View {
    var entry: VitalsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AMBIDASH")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Spacer()

            Text("\(entry.compositeScore)")
                .font(.system(size: 44, design: .monospaced))
                .fontWeight(.regular)
                .monospacedDigit()
                .foregroundStyle(.primary)

            Text("/100")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)

            if !entry.topGoal.isEmpty && entry.topGoal != "Open AmbiDash" {
                Text(entry.topGoal)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            // Score
            VStack(alignment: .leading, spacing: 4) {
                Text("AMBIDASH")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(entry.compositeScore)")
                    .font(.system(size: 48, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text("/100 composite")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Info
            VStack(alignment: .trailing, spacing: 8) {
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.secondary)

                Spacer()

                if entry.pillarsActive > 0 {
                    Text("\(entry.pillarsActive) pillars active")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                if !entry.topGoal.isEmpty && entry.topGoal != "Open AmbiDash" {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(entry.topGoal)
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if !entry.topGoalStatus.isEmpty {
                            Text(entry.topGoalStatus)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

@main
struct AmbidashWidget: Widget {
    let kind = "AmbidashVitals"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsProvider()) { entry in
            AmbidashWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Vitals")
        .description("Your composite score at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
