// ambidash/Services/ClosingRitualService.swift
import Foundation
import SwiftData

/// CLOSING RITUAL (the most-loved Sunsama mechanic, made non-punitive) — the
/// pure roll-up that powers the gentle end-of-day flow. It assembles, from what
/// ACTUALLY happened today (`ActualEvent`s) plus the lifecycle of today's
/// `PlannedAction`s, a CELEBRATION of the day: "here's what you did".
///
/// NON-PUNITIVE BY CONSTRUCTION:
/// - Partials COUNT. A `.partial` action / actual is surfaced as real progress,
///   never as a failure or a half-empty bar.
/// - Deferrals "roll forward" — they are framed as carried-on intent, NEVER as a
///   red overdue pile (differentiators win #2).
/// - Rest is a first-class, honored state — shown calmly, not as absence.
/// - Nothing here computes a "completion %" verdict or a shame-coded score.
///
/// No SwiftUI import → compiles into BOTH the iOS and macOS targets. Pure value
/// types out; the caller owns all persistence.
enum ClosingRitualService {

    /// One celebrated thing the user did today. Sourced from a completed/partial
    /// `PlannedAction` or from a logged `ActualEvent` (including unplanned work the
    /// user logged — "I did this, it wasn't on the plan"). Framed as accomplishment.
    struct DoneItem: Identifiable, Hashable {
        let id: UUID
        /// What it was, in the user's words (or the action's title).
        let title: String
        /// True when this was honored partial progress (still celebrated).
        let isPartial: Bool
        /// Sortable minutes-from-midnight when it happened (for chronological order);
        /// nil when we only know it was done but not when.
        let atMinutes: Int?
        /// Optional clock label ("14:30") for display; empty when unknown.
        let clock: String
    }

    /// A piece of planned work that gently ROLLS FORWARD to tomorrow (deferred or
    /// still-pending at day's end). Framed as "carries on", NEVER as missed/overdue.
    struct RollsForwardItem: Identifiable, Hashable {
        let id: UUID
        let title: String
        /// The originating action's id, so the ritual can offer it as tomorrow's
        /// ONE thing in one tap.
        let actionID: UUID
    }

    /// The full non-punitive recap for one day.
    struct Recap {
        /// Everything the user did today (completed + partial), chronological.
        let done: [DoneItem]
        /// Planned work that rolls forward to tomorrow (gentle, not a backlog).
        let rollsForward: [RollsForwardItem]
        /// Count of honored rest markers today (shown calmly, never as absence).
        let restCount: Int

        /// A warm, never-empty headline for the recap. Honors partials and an
        /// all-rest / quiet day without ever implying failure.
        var celebration: String {
            let n = done.count
            switch n {
            case 0:
                return restCount > 0
                    ? "A quieter day — and that's a kind of doing too."
                    : "Today was what it was. Tomorrow is fresh."
            case 1:
                return "You did one real thing today. That counts."
            default:
                return "Here's what you did today — \(n) things, partials and all."
            }
        }

        var isEmpty: Bool { done.isEmpty && rollsForward.isEmpty && restCount == 0 }
    }

    /// Builds the recap for `day` (defaults to today) from the supplied plan + the
    /// day's logged actuals. Pure: no fetch, no save — the caller passes the data
    /// it already has (a `DailyPlan` for `day` and that day's `ActualEvent`s).
    ///
    /// Dedup rule: an `ActualEvent` linked to a planned action SUPERSEDES that
    /// action's own done/partial entry (the actual is the truer record of what
    /// happened), so a logged block isn't celebrated twice.
    static func recap(
        plan: DailyPlan?,
        actuals: [ActualEvent],
        day: Date = .now,
        calendar: Calendar = .current
    ) -> Recap {
        let actions = (plan?.actions ?? [])

        // Actions whose actuals already represent them — don't double-count.
        let actionIDsCoveredByActuals = Set(actuals.compactMap { $0.linkedActionID })

        var done: [DoneItem] = []

        // 1) Logged actuals (completed + partial) — the truest "what happened".
        for ev in actuals where ev.completionStatus != .abandoned {
            done.append(DoneItem(
                id: ev.id,
                title: ev.title.isEmpty ? "Logged time" : ev.title,
                isPartial: ev.completionStatus == .partial,
                atMinutes: ev.startMinutes,
                clock: DailyTimeline.Entry.format(ev.startMinutes)
            ))
        }

        // 2) Planned actions completed/partial that DON'T already have an actual.
        for a in actions where !actionIDsCoveredByActuals.contains(a.id) {
            let life = a.lifecycle
            guard life == .done || life == .partial else { continue }
            let mins = DailyTimeline.minutes(from: a.timeSlot)
            done.append(DoneItem(
                id: a.id,
                title: a.title,
                isPartial: life == .partial,
                atMinutes: mins,
                clock: mins.map { DailyTimeline.Entry.format($0) } ?? ""
            ))
        }

        // Chronological; unknown-time items sink to the end.
        done.sort { (lhs, rhs) in
            switch (lhs.atMinutes, rhs.atMinutes) {
            case let (l?, r?): return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.title < rhs.title
            }
        }

        // 3) Rolls-forward: pending/deferred goal-work + still-open tasks (never a
        // hard skip / abandoned, never an anchor the day structures around).
        var rollsForward: [RollsForwardItem] = []
        for a in actions {
            let life = a.lifecycle
            guard life == .pending || life == .deferred else { continue }
            // Don't roll forward fixed anchors / routines (wake, meals, sleep) —
            // they aren't unfinished WORK, they're the shape of the day.
            guard a.anchorKind == .goalWork else { continue }
            rollsForward.append(RollsForwardItem(id: a.id, title: a.title, actionID: a.id))
        }

        let restCount = actions.filter { $0.lifecycle == .rest }.count

        return Recap(done: done, rollsForward: rollsForward, restCount: restCount)
    }
}
