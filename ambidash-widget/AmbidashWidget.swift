import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Timeline entry

struct VitalsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetVitalsSnapshot

    var compositeScore: Int { snapshot.compositeScore }
    var pillarsActive: Int { snapshot.pillarsActive }
    var topGoal: String { snapshot.topGoalTitle }
    var topGoalStatus: String { snapshot.topGoalStatus }
    var tasks: [WidgetTask] { snapshot.tasks }
    var goals: [WidgetGoalSummary] { snapshot.goals }
}

// MARK: - Provider

struct VitalsProvider: TimelineProvider {
    func placeholder(in context: Context) -> VitalsEntry {
        VitalsEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (VitalsEntry) -> Void) {
        if context.isPreview {
            completion(VitalsEntry(date: .now, snapshot: .placeholder))
        } else {
            completion(VitalsEntry(date: .now, snapshot: WidgetSharedStore.loadSnapshot()))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VitalsEntry>) -> Void) {
        let entry = VitalsEntry(date: .now, snapshot: WidgetSharedStore.loadSnapshot())
        // Refresh roughly every 30 min as a backstop; the app force-reloads
        // (WidgetCenter.reloadAllTimelines) whenever progress is actually logged.
        let timeline = Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1800)))
        completion(timeline)
    }
}

private extension WidgetVitalsSnapshot {
    /// A representative snapshot for the widget gallery / placeholder.
    static var placeholder: WidgetVitalsSnapshot {
        WidgetVitalsSnapshot(
            generatedAt: .now,
            compositeScore: 54,
            pillarsActive: 6,
            topGoalTitle: "Lean body",
            topGoalStatus: "on track",
            tasks: [
                WidgetTask(id: UUID(), title: "Morning lift", timeSlot: "07:00", durationMinutes: 45, goalID: UUID(), goalTitle: "Lean body", domainRaw: "body", isDone: false),
                WidgetTask(id: UUID(), title: "Deep work block", timeSlot: "10:00", durationMinutes: 90, goalID: UUID(), goalTitle: "Ship v1", domainRaw: "craft", isDone: false),
            ],
            goals: [
                WidgetGoalSummary(id: UUID(), title: "Lean body", domainRaw: "body", statusRaw: "onTrack", neglectDays: 0, percentComplete: 0.4, streakCount: 5),
                WidgetGoalSummary(id: UUID(), title: "Ship v1", domainRaw: "craft", statusRaw: "needsAttention", neglectDays: 4, percentComplete: 0.7, streakCount: 0),
                WidgetGoalSummary(id: UUID(), title: "Read daily", domainRaw: "mind", statusRaw: "slipping", neglectDays: 9, percentComplete: nil, streakCount: 0),
            ],
            nowTask: WidgetTask(id: UUID(), title: "Deep work block", timeSlot: "10:00", durationMinutes: 90, goalID: UUID(), goalTitle: "Ship v1", domainRaw: "craft", isDone: false)
        )
    }
}

// MARK: - Status / domain styling (self-contained — widget target can't see
// the app's GoalDomain/GoalStatus enums, which live under ambidash/).

enum WidgetStyle {
    static func statusColor(_ raw: String) -> Color {
        switch raw {
        case "onTrack": return .green
        case "needsAttention": return .orange
        // Non-punitive (principle #1): a slipping goal fades to grey, never red.
        case "slipping": return .gray
        case "paused": return .secondary
        default: return .secondary
        }
    }

    static func domainColor(_ raw: String) -> Color {
        switch raw {
        case "body": return .green
        case "mind": return .purple
        case "craft": return .blue
        case "people": return .pink
        case "wealth": return .yellow
        case "adventure": return .teal
        default: return .secondary
        }
    }

    static func domainIcon(_ raw: String) -> String {
        switch raw {
        case "body": return "figure.strengthtraining.traditional"
        case "mind": return "brain.head.profile"
        case "craft": return "hammer.fill"
        case "people": return "heart.fill"
        case "wealth": return "banknote.fill"
        case "adventure": return "airplane"
        default: return "circle.fill"
        }
    }
}

// MARK: - Entry view

struct AmbidashWidgetEntryView: View {
    var entry: VitalsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        case .systemLarge:
            largeWidget
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            accessoryInline
        default:
            smallWidget
        }
    }

    // MARK: Home Screen — small

    /// Small: composite headline, with today's next task (or top goal) beneath.
    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("AMBIDASH")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.snapshot.openTaskCount > 0 {
                    Text("\(entry.snapshot.openTaskCount) left")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(entry.compositeScore)")
                    .font(.system(size: 40, design: .monospaced))
                    .fontWeight(.regular)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text("/100")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if let task = entry.snapshot.nextTask {
                taskRow(task, compact: true)
            } else if !entry.topGoal.isEmpty && entry.topGoal != "Open AmbiDash" {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 5, height: 5)
                    Text(entry.topGoal)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Home Screen — medium

    /// Medium: composite on the left, today's tasks (interactive) on the right.
    private var mediumWidget: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AMBIDASH")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(entry.compositeScore)")
                    .font(.system(size: 44, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text("/100 composite")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)

                if entry.pillarsActive > 0 {
                    Text("\(entry.pillarsActive) goals active")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("TODAY")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(entry.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased())
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                }

                if entry.tasks.isEmpty {
                    glanceFallback
                } else {
                    ForEach(entry.tasks.prefix(3)) { task in
                        taskRow(task, compact: false, interactive: true)
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Home Screen — large

    /// Large: tasks at top, multi-goal at-a-glance grid beneath.
    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("AMBIDASH")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(entry.compositeScore)")
                        .font(.system(size: 22, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("/100")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            // Today's tasks
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)
                if entry.tasks.isEmpty {
                    glanceFallback
                } else {
                    ForEach(entry.tasks.prefix(3)) { task in
                        taskRow(task, compact: false, interactive: true)
                    }
                }
            }

            if !entry.goals.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("GOALS")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                    ForEach(entry.goals.prefix(4)) { goal in
                        goalRow(goal)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Lock Screen — circular

    /// Circular: composite score in a ring (gauge), the most at-a-glance signal.
    private var accessoryCircular: some View {
        Gauge(value: Double(entry.compositeScore), in: 0...100) {
            Text("PULSE")
        } currentValueLabel: {
            Text("\(entry.compositeScore)")
                .font(.system(size: 15, design: .rounded))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .containerBackground(.clear, for: .widget)
    }

    // MARK: Lock Screen — rectangular (NOW / NEXT radical focus)

    /// Rectangular: the block running NOW on the headline, the one upcoming block
    /// as a calm "Next" subline. Radical focus — only ever two blocks. Falls back
    /// to the first pending task, then the pulse, when nothing is running yet.
    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let now = entry.snapshot.nowTask {
                HStack(spacing: 4) {
                    Image(systemName: WidgetStyle.domainIcon(now.domainRaw))
                        .font(.system(size: 10))
                    Text(now.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                nextSubline
            } else if let task = entry.snapshot.nextTask {
                HStack(spacing: 4) {
                    Image(systemName: WidgetStyle.domainIcon(task.domainRaw))
                        .font(.system(size: 10))
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                Text(taskSubtitle(task))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "circle.grid.2x2")
                        .font(.system(size: 10))
                    Text("Pulse \(entry.compositeScore)/100")
                        .font(.system(size: 13, weight: .semibold))
                }
                if !entry.topGoal.isEmpty && entry.topGoal != "Open AmbiDash" {
                    Text("\(entry.topGoal) · \(entry.topGoalStatus)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("All clear today")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }

    /// The calm "Next: …" subline. Uses the deferred-style grey treatment for the
    /// upcoming block so it never competes with the Now headline.
    @ViewBuilder
    private var nextSubline: some View {
        if let next = entry.snapshot.nextTask {
            Text("Next · \(next.timeSlot.isEmpty ? next.title : "\(next.timeSlot) \(next.title)")")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        } else {
            Text("Last block of the day")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: Lock Screen — inline

    /// Inline: a single line beside the clock — the NOW block if one is running,
    /// else the next one, else the pulse.
    private var accessoryInline: some View {
        if let now = entry.snapshot.nowTask {
            Text("\(Image(systemName: "target")) Now: \(now.title)")
        } else if let task = entry.snapshot.nextTask {
            Text("\(Image(systemName: "target")) Next: \(task.title)")
        } else {
            Text("\(Image(systemName: "circle.grid.2x2")) Pulse \(entry.compositeScore)")
        }
    }

    // MARK: - Shared rows

    /// Fallback when there are no goal-linked tasks today.
    private var glanceFallback: some View {
        VStack(alignment: .leading, spacing: 6) {
            if entry.goals.isEmpty {
                Text(entry.topGoal == "Open AmbiDash" ? "Open AmbiDash to plan today" : "No tasks scheduled")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                ForEach(entry.goals.prefix(3)) { goal in
                    goalRow(goal)
                }
            }
        }
    }

    /// A task line. When `interactive`, prepends a tap-to-log button that marks
    /// the task done via `LogTaskIntent`.
    @ViewBuilder
    private func taskRow(_ task: WidgetTask, compact: Bool, interactive: Bool = false) -> some View {
        HStack(spacing: 6) {
            if interactive {
                Button(intent: LogTaskIntent(taskID: task.id, goalID: task.goalID)) {
                    Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 14))
                        .foregroundStyle(task.isDone ? WidgetStyle.domainColor(task.domainRaw) : .secondary)
                }
                .buttonStyle(.plain)
            } else {
                Circle()
                    .fill(WidgetStyle.domainColor(task.domainRaw))
                    .frame(width: 5, height: 5)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text(task.title)
                    .font(.system(size: compact ? 10 : 11, weight: .medium, design: .monospaced))
                    .strikethrough(task.isDone)
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .lineLimit(1)
                if !compact {
                    Text(taskSubtitle(task))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func taskSubtitle(_ task: WidgetTask) -> String {
        var parts: [String] = []
        if !task.timeSlot.isEmpty { parts.append(task.timeSlot) }
        if task.durationMinutes > 0 { parts.append("\(task.durationMinutes)m") }
        if !task.goalTitle.isEmpty { parts.append(task.goalTitle) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func goalRow(_ goal: WidgetGoalSummary) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(WidgetStyle.statusColor(goal.statusRaw))
                .frame(width: 5, height: 5)
            Text(goal.title)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let pct = goal.percentComplete {
                Text("\(Int(pct * 100))%")
                    .font(.system(size: 9, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else if goal.streakCount > 0 {
                Text("\(goal.streakCount)d")
                    .font(.system(size: 9, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } else if goal.neglectDays > 0 {
                Text("\(goal.neglectDays)d idle")
                    .font(.system(size: 9, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Now/Next focus view

/// The radical-focus surface: ONLY the block running now + the one upcoming
/// block. Calm, two-line. Shared by the dedicated Now/Next widget families.
struct NowNextEntryView: View {
    var entry: VitalsEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall, .systemMedium:
            homeView
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        default:
            homeView
        }
    }

    private var nowTask: WidgetTask? { entry.snapshot.nowTask }
    private var nextTask: WidgetTask? { entry.snapshot.nextTask }

    private var homeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FOCUS")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.secondary)

            if let now = nowTask {
                blockLine(label: "NOW", task: now, dimmed: false)
            } else if let next = nextTask {
                blockLine(label: "NEXT", task: next, dimmed: false)
            } else {
                Text("Nothing scheduled — open AmbiDash")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            // Show the upcoming block only when a block is already running now.
            if nowTask != nil, let next = nextTask {
                blockLine(label: "NEXT", task: next, dimmed: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private func blockLine(label: String, task: WidgetTask, dimmed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(dimmed ? Color.secondary.opacity(0.7) : .secondary)
            HStack(spacing: 5) {
                Circle()
                    .fill(WidgetStyle.domainColor(task.domainRaw))
                    .frame(width: 5, height: 5)
                    .opacity(dimmed ? 0.5 : 1)
                Text(task.title)
                    .font(.system(size: dimmed ? 12 : 15, weight: dimmed ? .regular : .semibold, design: .rounded))
                    .foregroundStyle(dimmed ? .secondary : .primary)
                    .lineLimit(1)
            }
            if !task.timeSlot.isEmpty {
                Text(task.timeSlot + (task.durationMinutes > 0 ? " · \(task.durationMinutes)m" : ""))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rectangular: some View {
        AmbidashWidgetEntryView(entry: entry).body
    }

    @ViewBuilder
    private var inline: some View {
        if let now = nowTask {
            Text("\(Image(systemName: "target")) Now: \(now.title)")
        } else if let next = nextTask {
            Text("\(Image(systemName: "target")) Next: \(next.title)")
        } else {
            Text("\(Image(systemName: "circle.grid.2x2")) AmbiDash")
        }
    }

    private var circular: some View {
        VStack(spacing: 1) {
            Image(systemName: "target")
                .font(.system(size: 13))
            if let t = (nowTask ?? nextTask) {
                Text(t.timeSlot.isEmpty ? "now" : t.timeSlot)
                    .font(.system(size: 9, design: .monospaced))
                    .minimumScaleFactor(0.6)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Widgets

struct AmbidashWidget: Widget {
    let kind = "AmbidashVitals"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsProvider()) { entry in
            AmbidashWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Vitals")
        .description("Composite score, today's tasks, and goal status at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

/// Radical-focus Now/Next widget — Lock Screen + Home Screen, only ever the
/// current block and the one after it.
struct NowNextWidget: Widget {
    let kind = "AmbidashNowNext"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VitalsProvider()) { entry in
            NowNextEntryView(entry: entry)
        }
        .configurationDisplayName("Now / Next")
        .description("Just the block you're in and the one coming up. Nothing else.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// MARK: - Bundle (@main)

@main
struct AmbidashWidgetBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        AmbidashWidget()
        NowNextWidget()
        // The Now/Next focus Live Activity (ActivityKit, iOS 16.1+). The bundle
        // builder supports #available, so pre-16.1 binaries simply omit it.
        if #available(iOS 16.1, *) {
            PlanBlockLiveActivity()
        }
        // GENTLE TIMELINE ALARMS — the AlarmKit block-start alarm Live Activity
        // (iOS 26+). Required so an opt-in unmissable block alarm has countdown/
        // paused UI; gated so pre-26 binaries simply omit it.
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            BlockAlarmLiveActivity()
        }
        #endif
    }
}
