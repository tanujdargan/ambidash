import Foundation
import SwiftData

/// The capture inbox's data engine: the <2-second capture path (with burst-grouping
/// of consecutive dumps), a no-model heuristic kind-guess, and the gentle triage
/// transitions (promote → Goal / today task, archive, drop). Pure model-layer logic
/// (no SwiftUI / no iOS-only frameworks) so it compiles on BOTH targets.
///
/// Triage is NEVER destructive of the original thought beyond what the user chose:
/// archive/drop keep the row (a tombstone) so nothing silently vanishes and the
/// inbox never grows a guilt pile. Promotion stamps `promotedToID` so the item can
/// point at what it became.
enum CaptureService {

    /// Consecutive captures within this window are grouped under one `groupID` so the
    /// inbox can show "you dumped these together" as a single cluster. Mirrors the
    /// self-chat burst pattern.
    static let burstWindow: TimeInterval = 90

    // MARK: - Capture (the <2s path)

    /// Create and persist a capture from raw text. Trims, drops empties, seeds a
    /// local kind-guess, and burst-groups with the most recent capture if it landed
    /// within `burstWindow`. Returns the new item (nil if the text was blank).
    @discardableResult
    @MainActor
    static func capture(
        _ rawText: String,
        source: CaptureSource = .text,
        in context: ModelContext,
        now: Date = .now
    ) -> CaptureItem? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let groupID = burstGroupID(near: now, in: context)
        let item = CaptureItem(
            text: text,
            createdAt: now,
            statusRaw: CaptureStatus.inbox.rawValue,
            sourceRaw: source.rawValue,
            kindGuessRaw: heuristicGuess(for: text).rawValue,
            groupID: groupID
        )
        context.insert(item)
        try? context.save()
        return item
    }

    /// The groupID to attach to a capture made at `now`: reuse the most recent
    /// capture's group (creating one if it had none) when it falls inside the burst
    /// window, otherwise mint a fresh group so a lone capture isn't grouped.
    @MainActor
    private static func burstGroupID(near now: Date, in context: ModelContext) -> UUID {
        var descriptor = FetchDescriptor<CaptureItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard
            let last = try? context.fetch(descriptor).first,
            now.timeIntervalSince(last.createdAt) <= burstWindow
        else {
            return UUID()
        }
        if let existing = last.groupID { return existing }
        // The previous capture was a lone item; backfill a shared group so the two
        // consecutive captures cluster together.
        let group = UUID()
        last.groupID = group
        return group
    }

    // MARK: - Local heuristic kind-guess (no model required)

    /// A deliberately simple, on-device, zero-cost guess used to PRE-SELECT a
    /// suggested triage. It is never authoritative and never shown as a verdict —
    /// the on-device / BYOK decompose may refine it later. Bias is toward `.task`
    /// (the most common, lowest-friction promotion).
    static func heuristicGuess(for text: String) -> CaptureKindGuess {
        let lower = text.lowercased()
        let words = lower.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count

        // Aspirational / long-range language → goal.
        let goalCues = ["i want to", "i'd like to", "someday", "eventually", "learn ",
                        "become ", "build a", "get better at", "master ", "my goal"]
        if goalCues.contains(where: lower.contains) { return .goal }

        // Imperative / actiony language → task.
        let taskCues = ["call ", "email ", "buy ", "book ", "send ", "fix ", "finish ",
                        "reply", "pay ", "schedule ", "todo", "to-do", "remember to",
                        "pick up", "submit ", "review "]
        if taskCues.contains(where: lower.contains) { return .task }

        // Short, snappy fragments tend to be actionable; longer musings tend to be notes.
        if words <= 8 { return .task }
        if words >= 22 { return .note }
        return .unknown
    }

    // MARK: - Triage transitions (gentle, reversible)

    /// Promote a capture into a brand-new active Goal (default domain `.mind` —
    /// the user re-domains it in goal detail; we never block on classification).
    /// Stamps the item triaged and links it to the created goal.
    @MainActor
    @discardableResult
    static func promoteToGoal(_ item: CaptureItem, in context: ModelContext) -> Goal {
        let title = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = Goal(title: title, domain: .mind, priority: nextGoalPriority(in: context))
        context.insert(goal)
        markTriaged(item, becoming: goal.id, in: context)
        return goal
    }

    /// Promote a capture into a today task: a `PlannedAction` appended to TODAY's
    /// `DailyPlan` (creating the plan if today has none). Non-time-boxed by default
    /// (a gentle "today" task, not a scheduled block) so it never implies a deadline.
    @MainActor
    @discardableResult
    static func promoteToTodayTask(_ item: CaptureItem, in context: ModelContext) -> PlannedAction {
        let plan = todayPlan(in: context)
        let action = PlannedAction(
            title: item.text.trimmingCharacters(in: .whitespacesAndNewlines),
            why: "Captured thought",
            duration: 30
        )
        action.plan = plan
        plan.actions = (plan.actions ?? []) + [action]
        plan.actionCount = (plan.actions?.count ?? 0)
        context.insert(action)
        markTriaged(item, becoming: action.id, in: context)
        return action
    }

    /// Keep the thought but set it aside (out of the inbox, recoverable).
    @MainActor
    static func archive(_ item: CaptureItem, in context: ModelContext) {
        item.status = .archived
        item.triagedAt = .now
        try? context.save()
    }

    /// Discard the thought. Kept as a tombstone (not deleted) so it doesn't resurface
    /// and stays recoverable; never shown again in the inbox.
    @MainActor
    static func drop(_ item: CaptureItem, in context: ModelContext) {
        item.status = .dropped
        item.triagedAt = .now
        try? context.save()
    }

    /// Move a triaged/archived/dropped item back to the inbox (undo).
    @MainActor
    static func restore(_ item: CaptureItem, in context: ModelContext) {
        item.status = .inbox
        item.triagedAt = nil
        try? context.save()
    }

    // MARK: - Inbox reads

    /// Recent UNPROCESSED captures (still in the inbox), newest first, capped. This is
    /// what the dashboard component surfaces — never a backlog count, never a badge.
    @MainActor
    static func recentInbox(limit: Int = 5, in context: ModelContext) -> [CaptureItem] {
        var descriptor = FetchDescriptor<CaptureItem>(
            predicate: #Predicate { $0.statusRaw == "inbox" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Total count still waiting in the inbox (used for a neutral "N waiting" line,
    /// never a red badge).
    @MainActor
    static func inboxCount(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<CaptureItem>(
            predicate: #Predicate { $0.statusRaw == "inbox" }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Helpers

    @MainActor
    private static func markTriaged(_ item: CaptureItem, becoming id: UUID, in context: ModelContext) {
        item.status = .triaged
        item.triagedAt = .now
        item.promotedToID = id
        try? context.save()
    }

    @MainActor
    private static func todayPlan(in context: ModelContext) -> DailyPlan {
        let descriptor = FetchDescriptor<DailyPlan>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let plans = (try? context.fetch(descriptor)) ?? []
        if let today = plans.first(where: { Calendar.current.isDateInToday($0.date) }) {
            return today
        }
        let plan = DailyPlan(date: .now)
        context.insert(plan)
        return plan
    }

    @MainActor
    private static func nextGoalPriority(in context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        let top = (try? context.fetch(descriptor))?.first?.priority ?? -1
        return top + 1
    }
}
