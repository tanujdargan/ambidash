// ambidash/Services/WinsService.swift
import Foundation

/// WINS WALL — the pure roll-up that mines EVIDENCE of what the user actually did,
/// framed always as accomplishment, NEVER as a deficit. This is the same substrate
/// `ClosingRitualService` mines (completed/partial `ActualEvent`s + lifecycle
/// `.done`/`.partial` `PlannedAction`s), generalized over an arbitrary window so the
/// Wins Wall component and the weekly "your week in wins" review can share ONE
/// dedup-by-`linkedActionID` implementation rather than re-deriving it.
///
/// NON-PUNITIVE BY CONSTRUCTION:
/// - PARTIALS COUNT. A `.partial` action / actual is surfaced as real progress.
/// - Nothing here is a count of misses, a completion %, or a remaining/overdue pile.
/// - An empty window is framed gently ("your wins will show up here"), never as failure.
///
/// No SwiftUI import → compiles into BOTH the iOS and macOS targets. Pure value types
/// in, pure value types out; the caller owns all fetching. Deriving from existing data
/// means ZERO schema change, ZERO CloudKit migration, ZERO new @Model.
enum WinsService {

    /// One piece of evidence — "look what you did". Sourced from a logged
    /// `ActualEvent` (the truest record) or a completed/partial `PlannedAction`.
    struct WinItem: Identifiable, Hashable {
        let id: UUID
        /// What it was, in the user's words (or the action's title).
        let title: String
        /// True when this was honored partial progress (still a real win).
        let isPartial: Bool
        /// The calendar day (start-of-day) this win belongs to — for grouping by day
        /// in the weekly review.
        let day: Date
        /// Sortable minutes-from-midnight when it happened; nil when only the day is
        /// known. Drives chronological order within a day.
        let atMinutes: Int?
        /// Optional clock label ("14:30"); empty when unknown.
        let clock: String
        /// The originating goal, if any — lets a future surface group wins by pillar.
        let goalID: UUID?
    }

    /// A day's worth of wins, for the grouped weekly review.
    struct DayWins: Identifiable, Hashable {
        /// Start-of-day — also the stable id for the grouped list.
        let day: Date
        var id: Date { day }
        let wins: [WinItem]
    }

    /// Build the flat, de-duplicated list of wins inside `interval`, newest first.
    ///
    /// Dedup rule (mirrors `ClosingRitualService`): an `ActualEvent` linked to a planned
    /// action SUPERSEDES that action's own done/partial entry (the actual is the truer
    /// record), so a logged block is never celebrated twice.
    ///
    /// - Parameters:
    ///   - actuals: the user's logged `ActualEvent`s (the caller filters to the window
    ///     or passes a superset — this method re-filters by `date` defensively).
    ///   - plans: the `DailyPlan`s overlapping the window (their `.actions` are mined for
    ///     completed/partial work not already covered by an actual).
    static func wins(
        in interval: DateInterval,
        actuals: [ActualEvent],
        plans: [DailyPlan],
        calendar: Calendar = .current
    ) -> [WinItem] {
        var items: [WinItem] = []

        // 1) Logged actuals (completed + partial) within the window — the truest record.
        let windowActuals = actuals.filter {
            $0.completionStatus != .abandoned && interval.contains($0.date)
        }
        for ev in windowActuals {
            items.append(WinItem(
                id: ev.id,
                title: ev.title.isEmpty ? "Logged time" : ev.title,
                isPartial: ev.completionStatus == .partial,
                day: calendar.startOfDay(for: ev.date),
                atMinutes: ev.startMinutes,
                clock: DailyTimeline.Entry.format(ev.startMinutes),
                goalID: ev.linkedGoalID
            ))
        }

        // Actions already represented by an actual — never double-count them.
        let coveredActionIDs = Set(windowActuals.compactMap { $0.linkedActionID })

        // 2) Planned actions completed/partial within the window that DON'T already have
        //    a covering actual.
        for plan in plans where interval.contains(plan.date) {
            let day = calendar.startOfDay(for: plan.date)
            for a in (plan.actions ?? []) where !coveredActionIDs.contains(a.id) {
                let life = a.lifecycle
                guard life == .done || life == .partial else { continue }
                let mins = DailyTimeline.minutes(from: a.timeSlot)
                items.append(WinItem(
                    id: a.id,
                    title: a.title,
                    isPartial: life == .partial,
                    day: day,
                    atMinutes: mins,
                    clock: mins.map { DailyTimeline.Entry.format($0) } ?? "",
                    goalID: a.goalID
                ))
            }
        }

        // Newest first: by day desc, then time-of-day desc within a day (unknown-time
        // items sink to the bottom of their day).
        items.sort { lhs, rhs in
            if lhs.day != rhs.day { return lhs.day > rhs.day }
            switch (lhs.atMinutes, rhs.atMinutes) {
            case let (l?, r?): return l > r
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return lhs.title < rhs.title
            }
        }
        return items
    }

    /// Group a flat win list into per-day buckets (newest day first) for the weekly
    /// review. Empty days are omitted.
    static func grouped(_ wins: [WinItem], calendar: Calendar = .current) -> [DayWins] {
        let buckets = Dictionary(grouping: wins) { $0.day }
        return buckets
            .map { DayWins(day: $0.key, wins: $0.value) }
            .sorted { $0.day > $1.day }
    }

    /// Convenience: the last `days` days ending now (inclusive of today). Used by both
    /// the component preview (recent wins) and the weekly review (7-day window).
    static func recentInterval(days: Int, ending end: Date = .now, calendar: Calendar = .current) -> DateInterval {
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? calendar.startOfDay(for: end).addingTimeInterval(24 * 3600)
        let start = calendar.date(byAdding: .day, value: -(max(1, days) - 1), to: calendar.startOfDay(for: end)) ?? calendar.startOfDay(for: end)
        return DateInterval(start: start, end: endOfToday)
    }

    /// A warm, never-empty headline for a window's wins. Honors partials and an empty
    /// week without ever implying failure or a deficit.
    static func headline(count: Int, days: Int) -> String {
        switch count {
        case 0:
            return "Your wins will show up here — one real thing is enough to start."
        case 1:
            return "One win\(days <= 1 ? " today" : " this stretch"). That counts."
        default:
            return "\(count) wins\(days <= 1 ? " today" : days <= 7 ? " this week" : "") — partials and all."
        }
    }
}
