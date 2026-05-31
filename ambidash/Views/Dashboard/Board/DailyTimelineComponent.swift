import SwiftUI

/// Design principle #3 — "Make time visible & spatial, not a checklist."
///
/// Renders TODAY as a vertical, duration-SIZED block timeline woven from the day's
/// `PlannedAction`s (fixed anchors / routines / goal-work already merged into one
/// ordered plan by the planner). Each block's height is proportional to its
/// duration; blocks are colour/icon-coded by `anchorKind`. The CURRENT block is
/// highlighted with a LIVE remaining-time countdown (`Text(timerInterval:)`, ticked
/// by the system — no app wakeups); PAST blocks fade via the shared non-punitive
/// `deferred` token (NEVER red); the NEXT block is gently emphasized. Tapping a
/// block opens a calm detail sheet.
///
/// Stateless except for the tapped-block sheet: reads exclusively from the injected
/// `BoardData` (compute-once at board level — no per-component @Query). Calm by
/// default; all motion routes through `MotionPreference`.
struct DailyTimelineComponent: View {
    @Environment(ThemeManager.self) private var tm
    let boardData: BoardData

    /// The block the user tapped — drives the detail sheet.
    @State private var selected: PlannedAction?
    /// A live clock that re-resolves block status (past / current / next) as the day
    /// moves. Updated once a minute; the per-second countdown is handled by the
    /// system via `Text(timerInterval:)`, so this stays cheap.
    @State private var now: Date = .now

    /// Re-evaluate which block is "current" once a minute. The countdown text inside
    /// the current block ticks every second on its own (system-driven).
    private let minuteTick = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: t.space.component) {
            header(t)

            if blocks.isEmpty {
                emptyState(t)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        TimelineBlockRow(
                            block: block,
                            isFirst: index == 0,
                            isLast: index == blocks.count - 1,
                            now: now,
                            onTap: { selected = block.action }
                        )
                    }
                }
                .environment(\.timelineNextBlockID, nextBlockID)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .onReceive(minuteTick) { value in
            withAnimation(MotionPreference.animation(.ambidashSpring)) { now = value }
        }
        .onAppear { now = .now }
        .sheet(item: $selected) { action in
            TimelineBlockDetailSheet(action: action)
                .environment(tm)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Day timeline")
    }

    // MARK: - Header

    @ViewBuilder
    private func header(_ t: ResolvedTheme) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(title: "Today")
            Spacer()
            Text(Self.dayClock(now))
                .font(.system(size: 10, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(t.faint)
        }
    }

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 15))
                .foregroundStyle(t.faint)
            Text("No plan for today yet — your day will show here as blocks.")
                .font(.system(size: 12))
                .foregroundStyle(t.muted)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Block model

    /// Today's actions sorted by clock time, resolved into renderable blocks. Each
    /// block knows its start/end minutes (so the row can size itself + compute
    /// status). Sourced from the merged plan, so fixed/routine/goal-work are all here.
    private var blocks: [TimelineBlock] {
        guard let plan = boardData.todayPlan else { return [] }
        let actions = (plan.actions ?? [])
        guard !actions.isEmpty else { return [] }
        let resolved: [TimelineBlock] = actions.map { action in
            // A no-resolvable-timeSlot action is UNscheduled ("anytime today"), not a
            // midnight block. Stamping it at 0 would sort it above the real day AND
            // make status() read it as already-`.past` (faded/missed) the moment the
            // clock passes 00:30 — punishing a brand-new task. Mark it unscheduled so
            // it sorts to the bottom and never resolves to past/current.
            let parsed = DailyTimeline.minutes(from: action.timeSlot)
            let duration = max(0, action.durationMinutes)
            return TimelineBlock(
                action: action,
                startMinutes: parsed ?? 0,
                durationMinutes: duration,
                isScheduled: parsed != nil
            )
        }
        // Scheduled blocks ordered by clock time; unscheduled ("anytime") fall to the
        // end as a calm tail rather than piling at the top.
        return resolved.sorted { a, b in
            if a.isScheduled != b.isScheduled { return a.isScheduled }
            return a.startMinutes < b.startMinutes
        }
    }

    /// The id of the block to give "next" emphasis: the earliest block that hasn't
    /// ended yet and isn't the current one. nil when nothing is upcoming.
    private var nextBlockID: UUID? {
        let n = TimelineBlock.nowMinutes(now)
        return blocks.first(where: { $0.isScheduled && $0.startMinutes > n })?.id
    }

    private static func dayClock(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

// MARK: - Timeline block value

/// One renderable block: an action plus its resolved start/duration in
/// minutes-from-midnight. `id` mirrors the action so `ForEach`/sheet item stay stable.
struct TimelineBlock: Identifiable {
    let action: PlannedAction
    let startMinutes: Int
    let durationMinutes: Int
    /// Whether the action had a resolvable clock-time `timeSlot`. An unscheduled
    /// block is "anytime today" — it never resolves to `.past`/`.current` (so a
    /// just-added task is never rendered as already-missed) and sorts after the
    /// timed strip.
    var isScheduled: Bool = true

    var id: UUID { action.id }
    var endMinutes: Int { startMinutes + durationMinutes }

    /// Minutes-from-midnight for "now" (local), used to compute status.
    static func nowMinutes(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// The end of this block as a concrete `Date` today, for the live countdown.
    func endDate(reference: Date) -> Date {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: reference)
        return cal.date(byAdding: .minute, value: endMinutes, to: startOfDay) ?? reference
    }

    enum Status { case past, current, next, upcoming }

    /// Resolve this block's status relative to `now`. `isNext` is passed in by the
    /// row because "next" is the FIRST upcoming block, which only the list knows.
    func status(now: Date, isNext: Bool) -> Status {
        // Unscheduled ("anytime today") blocks are never past or current — a task
        // with no clock time must not render as already-missed. It sits calmly as
        // an upcoming/anytime item until the user gives it a time or completes it.
        guard isScheduled else { return .upcoming }
        let n = Self.nowMinutes(now)
        if endMinutes <= n { return .past }
        if startMinutes <= n && n < endMinutes { return .current }
        return isNext ? .next : .upcoming
    }
}

// MARK: - Block row

/// A single duration-sized block in the timeline. Height is proportional to the
/// block's duration (clamped so 1-minute anchors stay tappable and long blocks
/// don't dominate). Colour/icon by `anchorKind`; status drives opacity + the
/// current-block highlight + the live countdown. Calm, tappable, motion-respecting.
private struct TimelineBlockRow: View {
    @Environment(ThemeManager.self) private var tm
    let block: TimelineBlock
    let isFirst: Bool
    let isLast: Bool
    let now: Date
    let onTap: () -> Void

    /// Points-per-minute scaling for block height. Kept gentle so the card stays
    /// compact; clamped below for very short / very long blocks.
    private static let pointsPerMinute: CGFloat = 0.5
    private static let minHeight: CGFloat = 44
    private static let maxHeight: CGFloat = 132

    private var height: CGFloat {
        let raw = CGFloat(block.durationMinutes) * Self.pointsPerMinute
        return min(Self.maxHeight, max(Self.minHeight, raw))
    }

    /// "Next" emphasis is owned by the parent, which knows the full sorted list and
    /// injects the next block's id via the environment. The row reads it so it never
    /// needs the whole list to know whether it is the one to emphasize.
    private var resolvedStatus: TimelineBlock.Status {
        block.status(now: now, isNext: nextProxy)
    }

    @Environment(\.timelineNextBlockID) private var nextBlockID
    private var nextProxy: Bool { nextBlockID == block.id }

    var body: some View {
        let t = tm.resolved
        let status = resolvedStatus
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                rail(t, status: status)
                content(t, status: status)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(status))
    }

    // MARK: Rail (time gutter + connector + node)

    @ViewBuilder
    private func rail(_ t: ResolvedTheme, status: TimelineBlock.Status) -> some View {
        VStack(spacing: 0) {
            // Top connector (hidden for the first block).
            Rectangle()
                .fill(t.hair)
                .frame(width: 1.5)
                .frame(height: 6)
                .opacity(isFirst ? 0 : 1)

            ZStack {
                Circle()
                    .fill(nodeColor(t, status: status))
                    .frame(width: 11, height: 11)
                if status == .current {
                    Circle()
                        .stroke(accentColor(t).opacity(0.4), lineWidth: 3)
                        .frame(width: 17, height: 17)
                }
            }

            // Bottom connector (hidden for the last block).
            Rectangle()
                .fill(t.hair)
                .frame(width: 1.5)
                .frame(maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: 18)
    }

    // MARK: Content block

    @ViewBuilder
    private func content(_ t: ResolvedTheme, status: TimelineBlock.Status) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: kindIcon)
                    .font(.system(size: 12))
                    .foregroundStyle(iconColor(t, status: status))
                    .frame(width: 16)

                Text(block.action.title)
                    .font(.system(size: 14, weight: status == .current ? .semibold : .regular))
                    .foregroundStyle(titleColor(t, status: status))
                    .lineLimit(2)
                    .strikethrough(block.action.statusRaw == "done", color: t.faint)

                Spacer(minLength: 4)

                whenLabel(t, status: status)
            }

            // The live "remaining" indicator only on the CURRENT block — a system-
            // ticked countdown (no app wakeups), framed gently, never punitive.
            if status == .current {
                countdown(t)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(minHeight: height, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(blockBackground(t, status: status))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor(t, status: status), lineWidth: status == .current ? 1 : 0.5)
        )
        .opacity(status == .past ? 0.55 : 1)
    }

    @ViewBuilder
    private func whenLabel(_ t: ResolvedTheme, status: TimelineBlock.Status) -> some View {
        let cue = block.action.scheduleCue.trimmingCharacters(in: .whitespaces)
        // Unscheduled blocks read as a calm "Anytime" rather than a blank/garbage
        // time, so a just-added task looks intentional instead of broken.
        let fallback = block.isScheduled ? block.action.timeSlot : "Anytime"
        let label = cue.isEmpty ? fallback : cue
        Text(label)
            .font(.system(size: 11, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(status == .past ? t.deferred : t.faint)
            .lineLimit(1)
    }

    /// Live remaining-time on the current block. `Text(timerInterval:)` is ticked by
    /// SwiftUI's system clock, so it stays live without us scheduling per-second work.
    @ViewBuilder
    private func countdown(_ t: ResolvedTheme) -> some View {
        let end = block.endDate(reference: now)
        HStack(spacing: 5) {
            Image(systemName: "timer")
                .font(.system(size: 10))
                .foregroundStyle(accentColor(t))
            if end > now {
                Text(timerInterval: now...end, countsDown: true)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(accentColor(t))
                Text("left")
                    .font(.system(size: 10))
                    .foregroundStyle(t.muted)
            } else {
                Text("wrapping up")
                    .font(.system(size: 10))
                    .foregroundStyle(t.muted)
            }
        }
    }

    // MARK: Color / icon coding

    /// Per-`anchorKind` accent (design: fixed = muted, routine = accent, goal_work = ink).
    private func kindColor(_ t: ResolvedTheme) -> Color {
        switch block.action.anchorKind {
        case .fixed: return t.muted
        case .routine: return t.accent
        case .goalWork: return t.ink
        }
    }

    private var kindIcon: String {
        switch block.action.anchorKind {
        case .fixed: return "pin"
        case .routine: return "repeat"
        case .goalWork: return "target"
        }
    }

    private func accentColor(_ t: ResolvedTheme) -> Color { t.accent }

    private func nodeColor(_ t: ResolvedTheme, status: TimelineBlock.Status) -> Color {
        switch status {
        case .past: return t.deferred
        case .current: return t.accent
        case .next: return kindColor(t)
        case .upcoming: return t.hair
        }
    }

    private func iconColor(_ t: ResolvedTheme, status: TimelineBlock.Status) -> Color {
        status == .past ? t.deferred : kindColor(t)
    }

    private func titleColor(_ t: ResolvedTheme, status: TimelineBlock.Status) -> Color {
        switch status {
        case .past: return t.muted
        case .current: return t.ink
        case .next: return t.ink
        case .upcoming: return t.ink2
        }
    }

    private func blockBackground(_ t: ResolvedTheme, status: TimelineBlock.Status) -> Color {
        switch status {
        case .current: return t.accentSoft
        case .next: return t.sunken.opacity(0.6)
        case .past, .upcoming: return t.sunken.opacity(0.35)
        }
    }

    private func borderColor(_ t: ResolvedTheme, status: TimelineBlock.Status) -> Color {
        switch status {
        case .current: return t.accent.opacity(0.5)
        case .next: return t.hair
        case .past, .upcoming: return t.hair.opacity(0.6)
        }
    }

    private func accessibilityLabel(_ status: TimelineBlock.Status) -> String {
        let when = block.action.scheduleCue.isEmpty ? block.action.timeSlot : block.action.scheduleCue
        let state: String
        switch status {
        case .past: state = "earlier"
        case .current: state = "now"
        case .next: state = "next"
        case .upcoming: state = "later"
        }
        return "\(state): \(block.action.title), \(when), \(block.durationMinutes) minutes."
    }
}

// MARK: - Next-block environment seam

/// The id of the block that should get "next" emphasis (the earliest non-past,
/// non-current block). Computed once by the parent and read by each row, so a row
/// doesn't need the whole list to know whether it's the next one.
private struct TimelineNextBlockIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var timelineNextBlockID: UUID? {
        get { self[TimelineNextBlockIDKey.self] }
        set { self[TimelineNextBlockIDKey.self] = newValue }
    }
}

// MARK: - Detail sheet

/// A calm, read-mostly detail for a tapped block: title, when, duration, kind, the
/// "why" line, and the current status — non-punitive throughout (a skipped block
/// reads as faded, never failed).
private struct TimelineBlockDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var tm
    let action: PlannedAction

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: kindIcon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(t.accent)
                                Text(kindLabel)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .tracking(1.2)
                                    .foregroundStyle(t.muted)
                            }
                            Text(action.title)
                                .font(.system(size: 22, weight: .regular, design: .serif))
                                .foregroundStyle(t.ink)
                        }

                        HStack(spacing: 28) {
                            metric(title: "When", value: whenValue, t: t)
                            metric(title: "Duration", value: "\(action.durationMinutes)m", t: t)
                        }

                        if !action.whyReasoning.trimmingCharacters(in: .whitespaces).isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                SectionLabel(title: "Why")
                                Text(action.whyReasoning)
                                    .font(.system(size: 15, design: .serif))
                                    .italic()
                                    .foregroundStyle(t.ink2)
                                    .lineSpacing(3)
                            }
                        }

                        if let target = targetLine {
                            VStack(alignment: .leading, spacing: 6) {
                                SectionLabel(title: "Target")
                                Text(target)
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(t.ink)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Status")
                            Text(statusLabel)
                                .font(.system(size: 14))
                                .foregroundStyle(statusColor(t))
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                }
            }
            .navigationTitle("Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func metric(title: String, value: String, t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionLabel(title: title)
            Text(value)
                .font(.system(size: 18, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(t.ink)
        }
    }

    private var whenValue: String {
        let cue = action.scheduleCue.trimmingCharacters(in: .whitespaces)
        return cue.isEmpty ? (action.timeSlot.isEmpty ? "—" : action.timeSlot) : cue
    }

    private var targetLine: String? {
        guard let amount = action.targetAmount, !action.targetUnit.isEmpty else { return nil }
        let n = amount == amount.rounded() ? String(Int(amount)) : String(amount)
        return "\(n) \(action.targetUnit)"
    }

    private var kindIcon: String {
        switch action.anchorKind {
        case .fixed: return "pin"
        case .routine: return "repeat"
        case .goalWork: return "target"
        }
    }

    private var kindLabel: String {
        switch action.anchorKind {
        case .fixed: return "Fixed anchor"
        case .routine: return "Routine"
        case .goalWork: return "Goal work"
        }
    }

    private var statusLabel: String {
        switch action.statusRaw {
        case "done": return "Done"
        case "skipped": return "Set aside — it can roll forward"
        default: return "Planned"
        }
    }

    /// Non-punitive: a skipped block reads in the soft `deferred` token, never red.
    private func statusColor(_ t: ResolvedTheme) -> Color {
        switch action.statusRaw {
        case "done": return t.ok
        case "skipped": return t.deferred
        default: return t.muted
        }
    }
}
