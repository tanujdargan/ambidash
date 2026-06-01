import SwiftUI
import SwiftData
#if os(iOS)
import WidgetKit
#endif

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

    /// MID-DAY DISRUPTION MODE (differentiator #1) — the trigger that opens the
    /// re-plan diff sheet, nil when closed. Set by the manual "Day changed?" button,
    /// the health-flare path, or an accepted auto-detect offer.
    @State private var disruptionTrigger: DisruptionService.Trigger?
    /// Recent energy check-ins, for the low-energy auto-detect offer. Small @Query —
    /// the same pattern EnergyCheckinComponent uses. Read-only here.
    @Query(sort: \EnergyCheckin.date, order: .reverse) private var recentCheckins: [EnergyCheckin]
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

            // MID-DAY DISRUPTION MODE — the manual "Day changed?" trigger + a soft
            // auto-detect offer, shown only when there's a plan to reshape.
            if boardData.todayPlan != nil && !blocks.isEmpty {
                disruptionBar(t)
            }

            if blocks.isEmpty {
                emptyState(t)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        switch row {
                        case .block(let block):
                            TimelineBlockRow(
                                block: block,
                                isFirst: index == 0,
                                isLast: index == rows.count - 1,
                                now: now,
                                onTap: { selected = block.action }
                            )
                        case .transition(let buffer):
                            TransitionBufferRow(buffer: buffer)
                        }
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
            // Re-evaluate the rough-day signal each minute; fire a gentle, interactive
            // check-in the first time a rough day is detected today.
            maybeOfferGentleCheckin()
        }
        .onAppear {
            now = .now
            maybeOfferGentleCheckin()
        }
        .sheet(item: $selected) { action in
            TimelineBlockDetailSheet(action: action)
                .environment(tm)
        }
        .sheet(item: $disruptionTrigger) { trigger in
            if let plan = boardData.todayPlan {
                DisruptionDiffSheet(
                    plan: plan,
                    goals: boardData.activeGoals,
                    prefs: boardData.profile?.userPreferences,
                    trigger: trigger
                )
                .environment(tm)
            }
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

    // MARK: - Disruption trigger

    /// The auto-detected trigger to softly OFFER (low energy / many missed blocks),
    /// or nil when the day looks fine. Never acts on its own — just a gentle banner.
    private var autoDetected: DisruptionService.Trigger? {
        guard let plan = boardData.todayPlan else { return nil }
        let recentEnergy = LearningService.recentEnergyLevel(checkins: recentCheckins, reference: now)
        return DisruptionService.suggestedTrigger(plan: plan, recentEnergy: recentEnergy, now: now)
    }

    /// GENTLE CHECK-IN — when the day is auto-detected as rough (low energy or several
    /// slipped blocks), fire the interactive `GENTLE_CHECKIN` notification ("I feel
    /// better" / "Move my plan" / "Just one thing") ONCE per day. This is the real
    /// trigger that makes the action-first check-in reachable; the disruption sheet is
    /// still one tap away in-app, this just surfaces the same help when the user may
    /// not be looking. Deduped per calendar day via UserDefaults.
    private func maybeOfferGentleCheckin() {
        guard autoDetected != nil else { return }
        let dayKey = Self.gentleCheckinDayKey(for: now)
        let lastKey = "gentleCheckin.lastDay"
        guard UserDefaults.standard.string(forKey: lastKey) != dayKey else { return }
        UserDefaults.standard.set(dayKey, forKey: lastKey)
        // A short delay so it lands as a calm Notification-Center nudge, not an
        // instant interruption. NotificationService clamps it to the waking window.
        NotificationService.scheduleGentleCheckin(after: 60)
    }

    private static func gentleCheckinDayKey(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    /// The "your day changed" affordances: a manual re-plan trigger, a humane
    /// health-flare path, and a soft auto-detect offer when signals suggest one.
    @ViewBuilder
    private func disruptionBar(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                triggerChip(
                    "My day changed",
                    icon: "arrow.triangle.2.circlepath",
                    t: t
                ) { disruptionTrigger = .manual }

                triggerChip(
                    "Health first",
                    icon: "heart.text.square",
                    t: t
                ) { disruptionTrigger = .healthFlare }
            }

            // Soft auto-detect OFFER — calm, dismissible by simply ignoring it. Uses
            // the deferred token, never red. Tapping opens the same diff sheet.
            if let auto = autoDetected {
                Button {
                    Haptics.light()
                    disruptionTrigger = auto
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                        Text(autoOfferText(auto))
                            .font(.system(size: 11))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.right").font(.system(size: 9))
                    }
                    .foregroundStyle(t.deferred)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(t.sunken.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.hair, lineWidth: 0.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func triggerChip(_ label: String, icon: String, t: ResolvedTheme, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(t.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(t.accentSoft)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    private func autoOfferText(_ trigger: DisruptionService.Trigger) -> String {
        switch trigger {
        case .lowEnergy:
            return "Energy's running low — want a lighter rest-of-day?"
        case .missedBlocks(let count):
            let qty = count >= 4 ? "Several" : "A few"
            return "\(qty) blocks slipped — reshape what's left?"
        default:
            return "Want to reshape the rest of your day?"
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

    /// The rendered rows: the ordered blocks with gentle, NON-INTERACTIVE transition
    /// buffers woven between consecutive SCHEDULED blocks that sit close together. The
    /// buffers are a DISPLAY-TIME concern only — no PlannedAction, no @Model, no
    /// CloudKit/plan impact; they're computed purely from adjacent blocks here. Gated
    /// by `UserPreferences.showTransitionBuffers` (default on) and `MotionPreference`
    /// (a reduced-motion day stays uncluttered), and only inserted when the gap is
    /// genuinely tight, so calm days aren't littered with markers.
    private var rows: [TimelineRow] {
        let bs = blocks
        guard showsTransitionBuffers else {
            return bs.map { .block($0) }
        }
        var out: [TimelineRow] = []
        for (i, block) in bs.enumerated() {
            out.append(.block(block))
            guard i < bs.count - 1 else { continue }
            let next = bs[i + 1]
            if let buffer = TransitionBuffer.between(block, next) {
                out.append(.transition(buffer))
            }
        }
        return out
    }

    /// Whether to weave transition buffers in. Respects the user's preference (default
    /// on) and suppresses the extra chrome under reduced motion for a calmer surface.
    private var showsTransitionBuffers: Bool {
        let pref = boardData.profile?.userPreferences?.showTransitionBuffers ?? true
        return pref && !MotionPreference.prefersReducedMotion
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

// MARK: - Timeline row (block or transition buffer)

/// One rendered row of the timeline: either a real duration-sized block, or a gentle
/// NON-INTERACTIVE transition buffer synthesized between two close blocks. The buffer
/// is render-time only — it is NEVER persisted, never a PlannedAction, and never feeds
/// carry-over / closing-ritual / CloudKit.
enum TimelineRow: Identifiable {
    case block(TimelineBlock)
    case transition(TransitionBuffer)

    var id: UUID {
        switch self {
        case .block(let b): return b.id
        case .transition(let t): return t.id
        }
    }
}

/// A tiny, derived "wrap up → next" marker between two consecutive blocks. Pure value,
/// computed from adjacent blocks at render time. Only created when the gap between the
/// current block's end and the next block's start is small but positive — the moment a
/// transition actually needs a gentle buffer.
struct TransitionBuffer: Identifiable {
    let id: UUID
    /// The title of the block coming up, for the "next: X" copy.
    let nextTitle: String
    /// Minutes of breathing room between the two blocks (1...maxGap).
    let gapMinutes: Int

    /// The window (in minutes) within which a gap is treated as a tight transition
    /// worth a buffer. A larger gap is genuine free time, not a hand-off, so we leave
    /// it alone.
    static let maxGap = 15

    /// Synthesize a buffer between two blocks when they're both scheduled and sit
    /// close together (0 < gap <= maxGap). Returns nil otherwise.
    static func between(_ current: TimelineBlock, _ next: TimelineBlock) -> TransitionBuffer? {
        guard current.isScheduled, next.isScheduled else { return nil }
        let gap = next.startMinutes - current.endMinutes
        guard gap > 0, gap <= maxGap else { return nil }
        let title = next.action.title.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return nil }
        return TransitionBuffer(id: UUID(), nextTitle: title, gapMinutes: gap)
    }

    /// Gentle, non-punitive copy: "wrap up · stretch · next: Cook dinner".
    var copy: String {
        "wrap up · stretch · next: \(nextTitle)"
    }
}

// MARK: - Transition buffer row

/// Renders a `TransitionBuffer` as a thin, inset, NON-INTERACTIVE marker: a dashed
/// connector + muted "wrap up → next" copy in the soft `deferred` token. Never sized
/// by duration like a real block, never tappable, never carries a lifecycle badge —
/// it's purely a calm visual breath between hand-offs.
private struct TransitionBufferRow: View {
    @Environment(ThemeManager.self) private var tm
    let buffer: TransitionBuffer

    var body: some View {
        let t = tm.resolved
        HStack(alignment: .center, spacing: 12) {
            // Dashed connector aligned with the timeline rail (matches the 18pt gutter).
            DashedVerticalLine()
                .stroke(t.deferred.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                .frame(width: 1.5)
                .frame(maxHeight: .infinity)
                .frame(width: 18)

            HStack(spacing: 6) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8))
                Text(buffer.copy)
                    .font(.system(size: 10))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(buffer.gapMinutes)m")
                    .font(.system(size: 9, design: .monospaced))
                    .monospacedDigit()
            }
            .foregroundStyle(t.deferred)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
        .frame(height: 28)
        .opacity(0.7)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Transition: wrap up, then \(buffer.nextTitle)")
    }
}

/// A simple vertical line shape, stroked with a dash pattern for the transition rail.
private struct DashedVerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
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
                    .font(t.body(14))
                    .fontWeight(status == .current ? .semibold : .regular)
                    .foregroundStyle(titleColor(t, status: status))
                    .lineLimit(2)
                    .strikethrough(block.action.statusRaw == "done", color: t.faint)

                lifecycleBadge(t)

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

    /// ZERO-GUILT lifecycle badge — renders the non-punitive state inline:
    /// `partial` (progress dot + %), `deferred` (forward arrow), `rest` (moon). All
    /// use the shared soft `deferred` token, NEVER red. `pending`/`done` show nothing
    /// here (done already strikes through the title).
    @ViewBuilder
    private func lifecycleBadge(_ t: ResolvedTheme) -> some View {
        switch block.action.lifecycle {
        case .partial:
            let pct = Int((max(0, min(1, block.action.partialProgress)) * 100).rounded())
            HStack(spacing: 3) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 9))
                if pct > 0 {
                    Text("\(pct)%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
            }
            .foregroundStyle(t.deferred)
            .accessibilityLabel(pct > 0 ? "partly done, \(pct) percent" : "partly done")
        case .deferred:
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 9))
                .foregroundStyle(t.deferred)
                .accessibilityLabel("deferred, rolls forward")
        case .rest:
            Image(systemName: "moon.stars")
                .font(.system(size: 9))
                .foregroundStyle(t.deferred)
                .accessibilityLabel("rest")
        case .pending, .done, .abandoned:
            EmptyView()
        }
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
    @Environment(\.modelContext) private var modelContext
    let action: PlannedAction

    /// Drives the "How'd that go?" logging sheet.
    @State private var showLog = false

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
                                .font(t.heading(22))
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
                                    .font(t.heading(15))
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

                        // GENTLE TIMELINE ALARMS — a calm per-block reminder picker.
                        // Only meaningful for a block that is still upcoming and has a
                        // clock time; a logged/past/timeless block has nothing to remind.
                        if showsAlarmPicker {
                            alarmPicker(t)
                        }

                        // One-tap logging entry — "How'd that go?". Calm, optional,
                        // never a demand. Opens the gentle log sheet.
                        Button {
                            Haptics.light()
                            showLog = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 13))
                                Text(action.statusRaw == "done" ? "Log how it went" : "How'd that go?")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(t.faint)
                            }
                            .foregroundStyle(t.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(t.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .scaleOnPress()

                        // ZERO-GUILT one-tap lifecycle actions. Only meaningful before
                        // the block is done; hidden once completed. All non-punitive.
                        if action.lifecycle != .done {
                            lifecycleActions(t)
                        }

                        // Gentle 3-option review, surfaced SOFTLY (no red, no badge)
                        // only when an item has rolled forward enough to be kind.
                        if CarryOverService.deservesGentleReview(action) {
                            gentleReview(t)
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
        .sheet(isPresented: $showLog) {
            BlockLogSheet(action: action) { dismiss() }
                .environment(tm)
        }
    }

    // MARK: - Gentle alarm picker

    /// Show the reminder picker only when there's something to remind toward: an
    /// upcoming block (not yet done/let-go) that has a resolvable clock time today.
    /// A timeless ("anytime") or already-settled block has no start to fire at.
    private var showsAlarmPicker: Bool {
        guard action.lifecycle != .done, action.lifecycle != .abandoned else { return false }
        guard let startMin = DailyTimeline.minutes(from: action.timeSlot) else { return false }
        let dayStart = Calendar.current.startOfDay(for: .now)
        let startDate = dayStart.addingTimeInterval(TimeInterval(startMin * 60))
        return startDate > .now
    }

    /// A calm 3-way picker: Off / Gentle / Alarm. DEFAULT is Gentle (a soft
    /// notification); Alarm is the explicit opt-in to a genuinely-unmissable
    /// AlarmKit alarm (iOS 26) or a clearly-labelled time-sensitive reminder pre-26.
    /// Selecting a mode persists it and immediately reconciles THIS block's scheduled
    /// surface so the change takes effect without waiting for a re-plan.
    @ViewBuilder
    private func alarmPicker(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Remind me")
            HStack(spacing: 8) {
                ForEach(PlannedAction.AlarmMode.allCases, id: \.self) { mode in
                    let on = action.alarmMode == mode
                    Button {
                        Haptics.light()
                        setAlarmMode(mode)
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: mode.symbol)
                                .font(.system(size: 14))
                            Text(mode.label)
                                .font(.system(size: 11, weight: on ? .semibold : .medium))
                        }
                        // Non-punitive even at the loudest setting: accent, never red.
                        .foregroundStyle(on ? t.accent : t.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(on ? t.accentSoft : t.sunken.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(on ? t.accent.opacity(0.5) : t.hair, lineWidth: on ? 1 : 0.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .accessibilityLabel("\(mode.label) reminder")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            // Honest one-liner about what "Alarm" does so the loud option is never a
            // surprise — it overrides Silent/Focus (iOS 26).
            if action.alarmMode == .alarm {
                Text("Unmissable — overrides Silent & Focus when your block starts.")
                    .font(.system(size: 11))
                    .foregroundStyle(t.muted)
            }
        }
    }

    /// Persist the chosen mode and reconcile only THIS block's scheduled
    /// reminder/alarm immediately (so the toggle feels live). Goal-work's gentle path
    /// stays owned by the chain; `AlarmService` no-ops a duplicate gentle ping for it.
    private func setAlarmMode(_ mode: PlannedAction.AlarmMode) {
        guard action.alarmMode != mode else { return }
        action.alarmMode = mode
        try? modelContext.save()
        #if os(iOS)
        if let startMin = DailyTimeline.minutes(from: action.timeSlot) {
            let dayStart = Calendar.current.startOfDay(for: .now)
            let startDate = dayStart.addingTimeInterval(TimeInterval(startMin * 60))
            AlarmService.reconcile(
                blockID: action.id.uuidString,
                blockTitle: action.title,
                startDate: startDate,
                mode: mode,
                gentleHandledByChain: action.anchorKind == .goalWork
            )
        }
        #endif
        Haptics.success()
    }

    /// ZERO-GUILT one-tap actions: gently defer to tomorrow, mark a first-class rest,
    /// or let it go without judgment. No red anywhere; all soft `deferred`/accent.
    @ViewBuilder
    private func lifecycleActions(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Or, gently")
            HStack(spacing: 8) {
                softAction("Defer", "arrow.turn.down.right", t) {
                    action.lifecycle = .deferred
                    action.deferredFrom = Calendar.current.startOfDay(for: .now)
                    persist()
                }
                softAction("Rest", "moon.stars", t) {
                    action.lifecycle = .rest
                    persist()
                }
                softAction("Let go", "archivebox", t) {
                    CarryOverService.letGo(action)
                    persist()
                }
            }
        }
    }

    /// The soft 3-option "still want this?" review for an item that's been rolling
    /// forward a while. An offer, never a verdict.
    @ViewBuilder
    private func gentleReview(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Still want this?")
            Text("It's gently rolled forward a few days. No pressure either way.")
                .font(.system(size: 12))
                .foregroundStyle(t.muted)
            HStack(spacing: 8) {
                softAction("Keep", "checkmark", t) {
                    CarryOverService.applyReview(.keep, to: action)
                    persist()
                }
                softAction("Later", "arrow.turn.down.right", t) {
                    CarryOverService.applyReview(.later, to: action)
                    persist()
                }
                softAction("Let it go", "archivebox", t) {
                    CarryOverService.applyReview(.letGo, to: action)
                    persist()
                }
            }
        }
    }

    @ViewBuilder
    private func softAction(_ label: String, _ icon: String, _ t: ResolvedTheme, action perform: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            perform()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(t.deferred)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(t.sunken.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).stroke(t.hair, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    /// Save the lifecycle mutation and dismiss the sheet calmly. The soft actions
    /// (Defer / Rest / Let go, and the gentle-review variants) settle this block,
    /// so — mirroring BlockLogSheet.confirm — silence its escalating reminder chain
    /// and any opt-in start alarm, then rewrite the widget snapshot and refresh the
    /// Live Activity so the ambient surfaces stop pointing at a block the user just
    /// set aside.
    private func persist() {
        // The user has settled this block — cancel its escalating reminder chain
        // (including the .now timeSensitive ping) and any opt-in start alarm.
        NotificationService.cancelReminderChain(blockID: action.id.uuidString)
        AlarmService.cancel(blockID: action.id.uuidString)

        Haptics.success()
        try? modelContext.save()

        // Keep the ambient surfaces honest: the widget's now/next and the Live
        // Activity should reflect that this block is no longer open work.
        WidgetSnapshotWriter.write(context: modelContext)
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        if let plan = action.plan {
            LiveActivityService.refresh(for: plan.actions ?? [], on: plan.date)
        }

        dismiss()
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
        // Prefer the richer non-punitive lifecycle label; for un-migrated actions a
        // bare legacy "skipped" still reads as a soft set-aside.
        switch action.lifecycle {
        case .done: return "Done"
        case .partial:
            let pct = Int((max(0, min(1, action.partialProgress)) * 100).rounded())
            return pct > 0 ? "In progress — \(pct)% so far" : "In progress"
        case .deferred:
            let reason = action.deferralReason.trimmingCharacters(in: .whitespaces)
            return reason.isEmpty ? "Deferred — it rolls forward" : "Deferred (\(reason)) — it rolls forward"
        case .rest: return "Rest — and that's okay"
        case .abandoned: return "Let go — no judgment"
        case .pending:
            return action.statusRaw == "skipped" ? "Set aside — it can roll forward" : "Planned"
        }
    }

    /// Non-punitive: every non-done state reads in the soft `deferred` token, never red.
    private func statusColor(_ t: ResolvedTheme) -> Color {
        switch action.lifecycle {
        case .done: return t.ok
        case .partial, .deferred, .rest, .abandoned: return t.deferred
        case .pending: return action.statusRaw == "skipped" ? t.deferred : t.muted
        }
    }
}
