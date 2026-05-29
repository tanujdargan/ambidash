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
    /// The actions from `priorPlan` that were not finished — i.e. still `pending`
    /// or explicitly `skipped`. (`done` actions are left behind.) Status strings
    /// match the codebase's `PlannedAction.statusRaw` vocabulary.
    static func unfinishedActions(from priorPlan: DailyPlan) -> [PlannedAction] {
        priorPlan.actions.filter { $0.statusRaw == "pending" || $0.statusRaw == "skipped" }
    }

    /// Clones each unfinished action from `priorPlan` into `todayPlan`, preserving
    /// title / why / duration / timeSlot / goalID / goalTitleSnapshot / milestone,
    /// resetting status to `pending`, and stamping `carriedOverFrom` with
    /// `priorPlan.date` so the action reads as carried-over.
    ///
    /// Idempotent: skips any source action whose work is already represented in
    /// `todayPlan` by a clone carried from the same prior date with the same
    /// title, so a regenerate or a repeat call won't pile up duplicates.
    /// Does NOT save.
    static func carryForward(into todayPlan: DailyPlan, from priorPlan: DailyPlan, context: ModelContext) {
        let priorDate = priorPlan.date

        // Titles already carried from this prior date into today's plan — the
        // idempotency guard. `carriedOverFrom` is the marker; title disambiguates
        // distinct unfinished items that share the same source date.
        let alreadyCarriedTitles = Set(
            todayPlan.actions
                .filter { $0.carriedOverFrom == priorDate }
                .map(\.title)
        )

        for source in unfinishedActions(from: priorPlan) {
            guard !alreadyCarriedTitles.contains(source.title) else { continue }

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
            todayPlan.actions.append(clone)
            todayPlan.actionCount = todayPlan.actions.count
        }
    }
}
