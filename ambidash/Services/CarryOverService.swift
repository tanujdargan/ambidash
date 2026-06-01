// ambidash/Services/CarryOverService.swift
import Foundation
import SwiftData

/// C2 — resurfaces yesterday's unfinished work into today's plan. When a new
/// `DailyPlan` is generated, the still-pending (and explicitly skipped) actions
/// from the most recent prior plan are cloned forward so they don't silently
/// vanish, preserving their goal lineage (`goalID` / `goalTitleSnapshot`) and
/// their `milestone` link so credit still rolls up the C1 chain when completed.
///
/// Mirrors `MilestoneGenerator` / `PlanGenerator`: an `enum` namespace of pure
/// static helpers, no instances. Does NOT save — the caller owns the transaction.
///
/// Idempotent: each carried-over clone is stamped with `carriedOverFrom = the
/// prior plan's date`, and `carryForward` skips any source action that already
/// has a matching clone in today's plan, so re-running it (e.g. a plan
/// regenerate) never double-clones the same work into one day.
enum CarryOverService {
    /// The actions from `priorPlan` that should gently roll forward — i.e. unfinished
    /// work the user hasn't settled. ZERO-GUILT (differentiator #2): this now folds in
    /// the `deferred` and `partial` lifecycle states (a not-done item rolls forward as
    /// "deferred until tomorrow", and a half-finished item keeps going), while
    /// EXCLUDING the two settled/honored end-states:
    /// - `rest`      — a logged "I chose not to, and that's okay"; rest isn't
    ///                 unfinished work, so it is NOT re-surfaced (would re-shame).
    /// - `abandoned` — explicitly "let go" (legacy statusRaw "skipped" via
    ///                 `applyLifecycle`); never re-carried.
    ///
    /// Legacy actions with no lifecycle set behave exactly as before: a plain
    /// "pending" carries; a bare legacy "skipped" (a soft set-aside, not an abandon)
    /// also still carries. `done` actions are left behind.
    static func unfinishedActions(from priorPlan: DailyPlan) -> [PlannedAction] {
        (priorPlan.actions ?? []).filter { isUnfinished($0) }
    }

    /// Whether one action is unfinished work that should roll forward. Centralised so
    /// the lifecycle contract lives in one place.
    static func isUnfinished(_ action: PlannedAction) -> Bool {
        // Honored end-states are never re-surfaced.
        if action.restMarker { return false }
        switch action.lifecycle {
        case .done, .abandoned, .rest:
            return false
        case .partial, .deferred:
            return true
        case .pending:
            // Fall back to the legacy status vocabulary for un-migrated actions:
            // a bare legacy "skipped" is a soft set-aside that still rolls forward;
            // "done" is finished.
            return action.statusRaw != "done"
        }
    }

    /// Clones each unfinished action from `priorPlan` into `todayPlan`, preserving
    /// title / why / duration / timeSlot / goalID / goalTitleSnapshot / milestone,
    /// resetting status to `pending`, and stamping `carriedOverFrom` with
    /// `priorPlan.date` so the action reads as carried-over.
    ///
    /// Idempotent: skips any source action whose work is already represented in
    /// `todayPlan` by a clone carried from the same prior date with the same
    /// IDENTITY, so a regenerate or a repeat call won't pile up duplicates.
    /// Does NOT save.
    static func carryForward(into todayPlan: DailyPlan, from priorPlan: DailyPlan, context: ModelContext) {
        let priorDate = priorPlan.date

        // Identities already carried from this prior date into today's plan — the
        // idempotency guard. `carriedOverFrom` is the marker; a COMPOSITE of
        // (title, goalID, timeSlot) disambiguates distinct unfinished items that
        // share a title (the planner emits shared templated titles like "Workout
        // session" across goals) so two genuinely-different blocks both roll forward
        // and neither loses its goal lineage / milestone link.
        let alreadyCarried = Set(
            (todayPlan.actions ?? [])
                .filter { $0.carriedOverFrom == priorDate }
                .map(Self.carryKey)
        )

        for source in unfinishedActions(from: priorPlan) {
            guard !alreadyCarried.contains(Self.carryKey(source)) else { continue }

            let clone = PlannedAction(
                title: source.title,
                why: source.whyReasoning,
                timeSlot: source.timeSlot,
                duration: source.durationMinutes,
                goalID: source.goalID,
                goalTitleSnapshot: source.goalTitleSnapshot,
                loggedAmount: source.loggedAmount,
                milestone: source.milestone,
                carriedOverFrom: priorDate
            )
            context.insert(clone)
            clone.plan = todayPlan

            // ZERO-GUILT: the clone resurfaces as a gently DEFERRED item ("deferred
            // until today"), NEVER a missed/overdue one. Carry any partial progress
            // and deferral reason so the user picks up where they left off with full
            // context, and so credit stays proportional rather than all-or-nothing.
            clone.lifecycle = .deferred           // mirrors statusRaw → "pending"
            clone.deferredFrom = priorDate
            clone.partialProgress = source.partialProgress
            clone.deferralReason = source.deferralReason

            todayPlan.actionCount = (todayPlan.actions ?? []).count
        }
    }

    /// Composite identity for the carry-over idempotency guard: (title, goalID,
    /// timeSlot). A clone preserves all three from its source, so a source's key
    /// equals the clone's — a repeat call still skips it — while two distinct items
    /// that merely share a title no longer collapse into one.
    private static func carryKey(_ action: PlannedAction) -> String {
        let goal = action.goalID?.uuidString ?? "—"
        return "\(action.title)\u{1F}\(goal)\u{1F}\(action.timeSlot)"
    }

    // MARK: - Gentle review (the 3-option "still want this?" — keep / later / let go)

    /// The three soft choices offered when an item has rolled forward enough that a
    /// gentle check-in is kind. Surfaced softly (no red, no badge) — an OFFER, never a
    /// verdict. `keep` leaves it in today's plan as-is; `later` re-defers it without
    /// judgment; `letGo` archives it (see `letGo`).
    enum ReviewChoice {
        case keep
        case later
        case letGo
    }

    /// Apply a gentle-review choice to a deferred/carried action. Pure model mutation;
    /// the caller owns the save. Non-punitive throughout.
    static func applyReview(_ choice: ReviewChoice, to action: PlannedAction, reason: String = "") {
        switch choice {
        case .keep:
            // Still want it: settle it back to a plain pending so it stops reading as
            // "carried over" pressure — it's just on the plan now.
            action.lifecycle = .pending
            action.deferredFrom = nil
            action.deferralReason = ""
        case .later:
            // Roll it forward again, gently, with optional fresh context.
            action.lifecycle = .deferred
            action.deferredFrom = Calendar.current.startOfDay(for: .now)
            if !reason.isEmpty { action.deferralReason = reason }
        case .letGo:
            letGo(action)
        }
    }

    /// "Let it go" — archive WITHOUT judgment. The item is settled as `abandoned`
    /// (mirrors legacy statusRaw "skipped" so it is never re-carried) and unhooked
    /// from any deferral pressure. This is a kindness, not a failure: it clears the
    /// pile instead of letting it accrue as shame. Pure mutation; caller saves.
    static func letGo(_ action: PlannedAction, reason: String = "") {
        action.lifecycle = .abandoned
        action.deferredFrom = nil
        if !reason.isEmpty { action.deferralReason = reason }
    }

    /// Whether an action has rolled forward enough to warrant a soft "still want
    /// this?" review (3+ days of gentle carry by default). Used to surface the review
    /// quietly, never to nag. A nil `deferredFrom` (never deferred) never qualifies.
    static func deservesGentleReview(_ action: PlannedAction, today: Date = .now, threshold days: Int = 3) -> Bool {
        guard action.lifecycle == .deferred, let from = action.deferredFrom else { return false }
        let cal = Calendar.current
        let elapsed = cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: today)).day ?? 0
        return elapsed >= days
    }
}
