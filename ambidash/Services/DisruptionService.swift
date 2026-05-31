// ambidash/Services/DisruptionService.swift
//
// MID-DAY DISRUPTION MODE — the v3 differentiator (#1 in /tmp/v3-design/
// differentiators.md). When the day breaks, this produces a PROPOSED re-plan as a
// DIFF over today's REMAINING plan: what is KEPT, what is MOVED, what is gently
// DROPPED (deferred — never abandoned, never red). It explicitly protects the ONE
// most-important thing.
//
// DESIGN CONTRACT
//  • Output is a PlanDiff VALUE type — NOT a @Model. It lives in memory until the
//    user ACCEPTS, so there is zero CloudKit schema change and zero migration risk.
//  • Apply semantics reuse the existing non-punitive state machine:
//      - moved   → mutate timeSlot (+ a soft scheduleCue), reversibly (originals are
//                  snapshotted so DECLINE / undo is exact).
//      - dropped → lifecycle = .deferred + deferredFrom (so CarryOverService rolls it
//                  to tomorrow). NEVER .abandoned — that is only the explicit user
//                  "let go".
//      - kept    → untouched.
//  • Fully REVERSIBLE: `snapshot(of:)` captures the prior plan; `revert(_:in:)`
//    restores it exactly. ACCEPT persists; DECLINE discards (nothing was mutated
//    until apply); EDIT lets the user tweak before applying.
//  • Always shows WHY: every entry carries a one-line, calm reason string.
//  • Triage / "one thing now": `triageProtectedID` collapses the day to the single
//    protected next step when the user is overwhelmed.
//  • Health-flare path: `healthFlareDiff` defers everything except the one protected
//    block, with gentle health-first phrasing — a kindness, not a failure.
//
// PURE + TESTABLE: an `enum` namespace of static helpers, mirroring CarryOverService
// / PlanGenerator. Does NOT save — the caller owns the transaction. AI phrasing (the
// WHY lines) is layered on TOP by DisruptionPhrasing (on-device FM → BYOK → canned);
// this core is fully deterministic and works with no model at all.

import Foundation
import SwiftData

enum DisruptionService {

    /// Minutes-from-midnight for `date` (local). Kept here so this Service has no
    /// dependency on any View type (it must compile in the mac target too).
    static func nowMinutes(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    // MARK: - Trigger

    /// What kicked off the re-plan. Drives the default WHY phrasing and how
    /// aggressively the day is trimmed. All non-punitive.
    enum Trigger: Equatable, Identifiable {
        /// The user tapped "my day changed" on the timeline/dashboard.
        case manual
        /// A recent energy check-in came back low (LearningService.recentEnergyLevel).
        case lowEnergy(level: Int)
        /// The current block is being missed / many blocks slipped.
        case missedBlocks(count: Int)
        /// A fixed block (class/meeting) ran long and ate the remaining gaps.
        case calendarOverrun
        /// The humane health path: prioritize health, defer the rest, restore later.
        case healthFlare

        /// Stable identity for `.sheet(item:)` — distinguishes the trigger families.
        var id: String {
            switch self {
            case .manual:          return "manual"
            case .lowEnergy:       return "lowEnergy"
            case .missedBlocks:    return "missedBlocks"
            case .calendarOverrun: return "calendarOverrun"
            case .healthFlare:     return "healthFlare"
            }
        }

        /// A short, calm headline for the diff sheet.
        var headline: String {
            switch self {
            case .manual:          return "Your day changed"
            case .lowEnergy:       return "Running low"
            case .missedBlocks:    return "The day slipped a little"
            case .calendarOverrun: return "Something ran long"
            case .healthFlare:     return "Health comes first"
            }
        }

        /// A one-line subhead explaining WHY a re-plan is offered. Never a verdict.
        var rationale: String {
            switch self {
            case .manual:
                return "Here's a gentler shape for what's left — nothing is lost."
            case .lowEnergy(let level):
                return "Energy's at \(level)/5. Let's protect the one thing that matters and let the rest roll forward."
            case .missedBlocks(let count):
                let word = count == 1 ? "block" : "blocks"
                return "\(count) \(word) slipped — that happens. Here's a lighter rest-of-day."
            case .calendarOverrun:
                return "That overran into your free time. Let's reshape what's left around it."
            case .healthFlare:
                return "Rest is the plan right now. One small thing stays; everything else waits, no judgment."
            }
        }

        /// How many goal-work blocks to keep beyond the single protected one. A low
        /// energy / health flare trims hard; a manual reshuffle is gentler.
        var keepBudget: Int {
            switch self {
            case .manual:          return 3
            case .calendarOverrun: return 2
            case .missedBlocks:    return 2
            case .lowEnergy(let level): return level <= 2 ? 0 : 1
            case .healthFlare:     return 0
            }
        }
    }

    // MARK: - Diff value types (in-memory; never persisted)

    /// One line of the proposed re-plan. References the live `PlannedAction` by id so
    /// apply can find it, and carries everything the timeline overlay needs to render
    /// the change + a calm WHY.
    struct DiffEntry: Identifiable, Equatable {
        enum Kind: Equatable { case kept, moved, dropped }

        let id: UUID                 // mirrors the PlannedAction.id
        let title: String
        var kind: Kind
        /// For `.moved`: the original HH:MM slot (for the strike-through "8:00 → 18:00").
        let fromSlot: String
        /// For `.moved`: the proposed new HH:MM slot.
        var toSlot: String
        /// A one-line, calm reason for this change. Default is deterministic; the AI
        /// layer may replace it with warmer phrasing.
        var why: String
        /// True when this is THE protected, most-important block. Always `.kept`.
        let isProtected: Bool

        var startMinutesProposed: Int {
            DailyTimeline.minutes(from: toSlot.isEmpty ? fromSlot : toSlot) ?? 0
        }
    }

    /// The full proposed re-plan: an ordered set of entries plus the protected id and
    /// the trigger that produced it. A VALUE type — held in memory by the UI until the
    /// user ACCEPTs. Reversible because nothing is mutated until `apply`.
    struct PlanDiff: Equatable {
        let trigger: Trigger
        var entries: [DiffEntry]
        /// The id of the ONE most-important block that is force-kept.
        let protectedID: UUID?

        var headline: String { trigger.headline }
        var rationale: String { trigger.rationale }

        var movedCount: Int { entries.filter { $0.kind == .moved }.count }
        var droppedCount: Int { entries.filter { $0.kind == .dropped }.count }
        var keptCount: Int { entries.filter { $0.kind == .kept }.count }

        /// Nothing actually changes — a no-op diff (e.g. the day is already light).
        var isEmpty: Bool { movedCount == 0 && droppedCount == 0 }

        /// The protected entry, surfaced for triage / "one thing now".
        var protectedEntry: DiffEntry? {
            guard let protectedID else { return entries.first(where: { $0.isProtected }) }
            return entries.first(where: { $0.id == protectedID })
        }
    }

    // MARK: - Importance (no migration: derived, not stored)

    /// Importance score for a goal-work action — higher is more important. There is
    /// NO stored priority field on PlannedAction, so we DERIVE one from existing
    /// signals so "preserve the ONE most-important thing" needs no migration:
    ///   • the linked goal's priority (lower `priority` int = higher rank),
    ///   • an imminent milestone deadline (the nearest `endDate` still in the future),
    ///   • a live streak worth protecting,
    ///   • neglect (a long-untouched goal gets a small nudge so it isn't always
    ///     dropped).
    /// Fixed anchors and routines are handled separately (never dropped, never the
    /// protected pick) so this only ranks goal-work.
    static func importance(of action: PlannedAction, goals: [Goal], today: Date = .now) -> Double {
        guard action.anchorKind == .goalWork else { return 0 }
        var score = 0.0
        let goal = action.goalID.flatMap { id in goals.first(where: { $0.id == id }) }
        if let goal {
            // priority: 0 is top. Map to a descending bonus (cap so it dominates gently).
            score += max(0, 20 - Double(goal.priority))
            // streak worth protecting.
            if let count = goal.streak?.currentCount, count > 0 {
                score += min(10, Double(count))
            }
            // imminent milestone: the nearest future checkpoint adds urgency.
            if let nearest = (goal.milestones ?? [])
                .filter({ !$0.isCompleted && $0.endDate >= today })
                .min(by: { $0.endDate < $1.endDate }) {
                let days = Calendar.current.dateComponents([.day], from: today, to: nearest.endDate).day ?? 99
                score += max(0, 14 - Double(max(0, days)))   // closer deadline → bigger boost
            }
            // gentle neglect nudge so a long-ignored goal isn't perpetually dropped.
            score += min(5, Double(goal.neglectDays) * 0.5)
        }
        // A block carrying a measurable logged amount is concrete work — slight boost.
        if let amt = action.loggedAmount, amt != 0 { score += 2 }
        return score
    }

    /// The single most-important goal-work block among `actions`, or nil when there's
    /// no goal-work left to protect. This is the one the re-plan force-keeps.
    static func mostImportant(among actions: [PlannedAction], goals: [Goal], today: Date = .now) -> PlannedAction? {
        actions
            .filter { $0.anchorKind == .goalWork && !isSettled($0) }
            .max(by: { importance(of: $0, goals: goals, today: today) < importance(of: $1, goals: goals, today: today) })
    }

    // MARK: - Building the diff

    /// Whether an action is already settled and so out of scope for a re-plan (done,
    /// rested, or let go). Deferred/partial/pending are all still "live" remaining work.
    static func isSettled(_ action: PlannedAction) -> Bool {
        switch action.lifecycle {
        case .done, .rest, .abandoned: return true
        case .pending, .partial, .deferred: return false
        }
    }

    /// The actions still ahead of `now` (remaining today). Past blocks are left
    /// untouched — a re-plan only reshapes what's still to come. Unscheduled
    /// ("anytime") goal-work counts as remaining. Settled items are excluded.
    static func remainingActions(in plan: DailyPlan, now: Date = .now) -> [PlannedAction] {
        let nowMin = nowMinutes(now)
        return (plan.actions ?? []).filter { action in
            if isSettled(action) { return false }
            guard let start = DailyTimeline.minutes(from: action.timeSlot) else { return true } // anytime
            // A block already in progress counts as remaining (you can still re-plan it).
            return start + max(0, action.durationMinutes) > nowMin
        }
    }

    /// Build the proposed PlanDiff for `plan` given the trigger. Pure — mutates
    /// nothing. The strategy:
    ///   1. Fixed anchors + routines are always KEPT (the day is built around them).
    ///   2. The single most-important goal-work block is force-KEPT (protected).
    ///   3. Remaining goal-work is ranked; the top `keepBudget` are KEPT but MOVED
    ///      into the next free gaps after now (so they fit the shrunken day); the
    ///      rest are gently DROPPED (deferred, rolls forward).
    ///   4. A health flare defers ALL goal-work except the protected one.
    static func buildDiff(
        for plan: DailyPlan,
        trigger: Trigger,
        prefs: UserPreferences?,
        goals: [Goal],
        now: Date = .now
    ) -> PlanDiff {
        let remaining = remainingActions(in: plan, now: now)
        let protected = mostImportant(among: remaining, goals: goals, today: now)
        let protectedID = protected?.id

        // Anchors/routines: always kept, untouched.
        var entries: [DiffEntry] = []
        let anchors = remaining.filter { $0.anchorKind != .goalWork }
        for a in anchors {
            entries.append(DiffEntry(
                id: a.id, title: a.title, kind: .kept,
                fromSlot: a.timeSlot, toSlot: a.timeSlot,
                why: "A fixed part of your day — left as is.",
                isProtected: false
            ))
        }

        // Goal-work, ranked most-important first.
        let goalWork = remaining
            .filter { $0.anchorKind == .goalWork }
            .sorted { importance(of: $0, goals: goals, today: now) > importance(of: $1, goals: goals, today: now) }

        // Free gaps from now onward, to land the kept-moved blocks somewhere real.
        // CRITICAL: gaps must reflect the LIVE remaining plan, not just the generic
        // prefs skeleton. Otherwise a kept anchor or the protected/kept-in-place block
        // is invisible to the cursor and a moved block double-books on top of it.
        // So we start from the skeleton's free gaps and then SUBTRACT every interval
        // that's already occupied by a real remaining block we won't move:
        //   • all remaining fixed anchors / routines (always kept in place), and
        //   • the protected block's own original slot when it's still in the future
        //     (we intend to keep it there if we can).
        let skeleton = DailyTimeline.skeleton(from: prefs)
        let nowMin = nowMinutes(now)

        var occupied: [(start: Int, end: Int)] = []
        for a in anchors {
            guard let s = DailyTimeline.minutes(from: a.timeSlot) else { continue }
            occupied.append((s, s + max(5, a.durationMinutes)))
        }
        // Reserve the protected block's current slot so moved blocks never land on it.
        if let protected,
           let ps = DailyTimeline.minutes(from: protected.timeSlot),
           ps + max(5, protected.durationMinutes) > nowMin {
            occupied.append((ps, ps + max(5, protected.durationMinutes)))
        }

        let liveGaps = subtract(occupied, from: DailyTimeline.freeGaps(in: skeleton))
        var gapCursor = GapCursor(gaps: liveGaps, after: nowMin)

        var keptBeyondProtected = 0
        let budget = trigger.keepBudget

        for action in goalWork {
            let isProtected = action.id == protectedID
            if isProtected {
                // The ONE thing stays. Its original slot was RESERVED (subtracted from
                // the gaps), so if that slot is still in the future we keep it exactly
                // where it is — no other moved block can have landed on it. Only when
                // its slot is already past (or unset) do we gently shift it into the
                // next real free gap so it's still doable.
                let origin = DailyTimeline.minutes(from: action.timeSlot)
                let stillAhead = origin.map { $0 + max(0, action.durationMinutes) > nowMin } ?? false
                if stillAhead {
                    entries.append(DiffEntry(
                        id: action.id, title: action.title, kind: .kept,
                        fromSlot: action.timeSlot, toSlot: action.timeSlot,
                        why: "Your one most-important thing — protected.",
                        isProtected: true
                    ))
                } else if let slot = nextFitSlot(for: action, cursor: &gapCursor, now: nowMin) {
                    entries.append(DiffEntry(
                        id: action.id, title: action.title, kind: .moved,
                        fromSlot: action.timeSlot, toSlot: DailyTimeline.Entry.format(slot),
                        why: "Your one most-important thing — kept, just shifted to fit.",
                        isProtected: true
                    ))
                } else {
                    // No gap left at all — still protect it, in place, never dropped.
                    entries.append(DiffEntry(
                        id: action.id, title: action.title, kind: .kept,
                        fromSlot: action.timeSlot, toSlot: action.timeSlot,
                        why: "Your one most-important thing — protected.",
                        isProtected: true
                    ))
                }
                continue
            }

            if keptBeyondProtected < budget,
               let slot = nextFitSlot(for: action, cursor: &gapCursor, now: nowMin) {
                keptBeyondProtected += 1
                let newClock = DailyTimeline.Entry.format(slot)
                let origin = DailyTimeline.minutes(from: action.timeSlot)
                if origin == slot {
                    entries.append(DiffEntry(
                        id: action.id, title: action.title, kind: .kept,
                        fromSlot: action.timeSlot, toSlot: action.timeSlot,
                        why: "Still fits — kept where it is.", isProtected: false
                    ))
                } else {
                    entries.append(DiffEntry(
                        id: action.id, title: action.title, kind: .moved,
                        fromSlot: action.timeSlot, toSlot: newClock,
                        why: "Shifted later so it fits the rest of your day.", isProtected: false
                    ))
                }
            } else {
                // Gently deferred — rolls forward to tomorrow, never marked missed.
                entries.append(DiffEntry(
                    id: action.id, title: action.title, kind: .dropped,
                    fromSlot: action.timeSlot, toSlot: action.timeSlot,
                    why: dropWhy(for: trigger), isProtected: false
                ))
            }
        }

        // Order the proposal by proposed time so it reads top-to-bottom like the day.
        entries.sort { $0.startMinutesProposed < $1.startMinutesProposed }
        return PlanDiff(trigger: trigger, entries: entries, protectedID: protectedID)
    }

    private static func dropWhy(for trigger: Trigger) -> String {
        switch trigger {
        case .healthFlare: return "Waiting for you — no rush, no judgment."
        case .lowEnergy:   return "Rolling forward to a day with more in the tank."
        default:           return "Gently rolled forward to tomorrow."
        }
    }

    // MARK: - Gap fitting

    /// Subtract a set of OCCUPIED intervals (minutes-from-midnight) from the day's
    /// free gaps, so the cursor only ever offers slots that don't overlap a block we
    /// intend to keep in place (a fixed anchor, or the protected block's reserved
    /// slot). Returns the remaining sub-gaps, each still ≥ a usable minimum so we
    /// never hand back a sliver. Pure.
    static func subtract(_ occupied: [(start: Int, end: Int)], from gaps: [DailyTimeline.Gap]) -> [DailyTimeline.Gap] {
        guard !occupied.isEmpty else { return gaps }
        let busy = occupied
            .map { (min($0.start, $0.end), max($0.start, $0.end)) }
            .sorted { $0.0 < $1.0 }
        let minSlice = 5
        var result: [DailyTimeline.Gap] = []
        for gap in gaps {
            var cursor = gap.startMinutes
            for b in busy {
                // Skip busy intervals that don't intersect this gap.
                if b.1 <= cursor || b.0 >= gap.endMinutes { continue }
                if b.0 > cursor {
                    let end = min(b.0, gap.endMinutes)
                    if end - cursor >= minSlice {
                        result.append(DailyTimeline.Gap(startMinutes: cursor, endMinutes: end))
                    }
                }
                cursor = max(cursor, b.1)
                if cursor >= gap.endMinutes { break }
            }
            if cursor < gap.endMinutes && gap.endMinutes - cursor >= minSlice {
                result.append(DailyTimeline.Gap(startMinutes: cursor, endMinutes: gap.endMinutes))
            }
        }
        return result.sorted { $0.startMinutes < $1.startMinutes }
    }

    /// A small mutable cursor over the day's free gaps, walking forward as blocks are
    /// placed so two kept-moved blocks never get the same slot.
    private struct GapCursor {
        var gaps: [DailyTimeline.Gap]
        var index: Int = 0
        var cursor: Int

        init(gaps: [DailyTimeline.Gap], after nowMin: Int) {
            self.gaps = gaps
            // Start at the first gap that still has room after now.
            self.cursor = nowMin
            self.index = 0
            advanceToUsableGap()
        }

        mutating func advanceToUsableGap() {
            while index < gaps.count && gaps[index].endMinutes <= max(cursor, 0) {
                index += 1
            }
            if index < gaps.count {
                cursor = max(cursor, gaps[index].startMinutes)
            }
        }

        /// The next start slot that fits `duration`, or nil when the day's gaps are
        /// full. Advances the cursor past the placed block.
        mutating func place(duration: Int) -> Int? {
            let dur = max(5, duration)
            while index < gaps.count {
                let gap = gaps[index]
                let start = max(cursor, gap.startMinutes)
                if gap.endMinutes - start >= dur {
                    cursor = start + dur
                    return start
                }
                index += 1
                if index < gaps.count { cursor = max(cursor, gaps[index].startMinutes) }
            }
            return nil
        }
    }

    /// The next slot to fit `action`. nil means no gap remains (caller will drop it).
    private static func nextFitSlot(for action: PlannedAction, cursor: inout GapCursor, now: Int) -> Int? {
        cursor.place(duration: action.durationMinutes)
    }

    // MARK: - Snapshot + reversibility

    /// A reversible snapshot of one action's mutable scheduling/lifecycle state,
    /// captured BEFORE a diff is applied so DECLINE / undo restores it exactly.
    struct ActionSnapshot: Equatable {
        let id: UUID
        let timeSlot: String
        let scheduleCue: String
        let lifecycleRaw: String
        let statusRaw: String
        let deferredFrom: Date?
        let deferralReason: String
        let partialProgress: Double
        let restMarker: Bool
        let completedAt: Date?
    }

    /// Snapshot every remaining action in the plan so an applied diff is fully
    /// reversible. Capture this BEFORE calling `apply`.
    static func snapshot(of plan: DailyPlan, now: Date = .now) -> [ActionSnapshot] {
        remainingActions(in: plan, now: now).map { a in
            ActionSnapshot(
                id: a.id,
                timeSlot: a.timeSlot,
                scheduleCue: a.scheduleCue,
                lifecycleRaw: a.lifecycleRaw,
                statusRaw: a.statusRaw,
                deferredFrom: a.deferredFrom,
                deferralReason: a.deferralReason,
                partialProgress: a.partialProgress,
                restMarker: a.restMarker,
                completedAt: a.completedAt
            )
        }
    }

    /// Restore a plan from a snapshot — the exact inverse of `apply`. Used by DECLINE
    /// after a preview-apply, or an explicit undo. Does NOT save.
    static func revert(_ snapshots: [ActionSnapshot], in plan: DailyPlan) {
        let byID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
        for action in (plan.actions ?? []) {
            guard let s = byID[action.id] else { continue }
            action.timeSlot = s.timeSlot
            action.scheduleCue = s.scheduleCue
            action.lifecycleRaw = s.lifecycleRaw
            action.statusRaw = s.statusRaw
            action.deferredFrom = s.deferredFrom
            action.deferralReason = s.deferralReason
            action.partialProgress = s.partialProgress
            action.restMarker = s.restMarker
            action.completedAt = s.completedAt
        }
    }

    // MARK: - Applying the diff (non-punitive state machine)

    /// Apply an accepted (and possibly user-edited) diff to the live plan. Reuses the
    /// existing non-punitive lifecycle:
    ///   • moved   → set timeSlot to the new clock + a soft "rescheduled" cue.
    ///   • dropped → lifecycle = .deferred + deferredFrom (CarryOverService rolls it
    ///               to tomorrow). NEVER .abandoned.
    ///   • kept    → untouched.
    /// Does NOT save — the caller owns the transaction (so it can snapshot first and
    /// keep ACCEPT atomic).
    static func apply(_ diff: PlanDiff, to plan: DailyPlan, reason: String = "") {
        let byID = Dictionary(uniqueKeysWithValues: (plan.actions ?? []).map { ($0.id, $0) })
        let dayStart = Calendar.current.startOfDay(for: .now)
        let dropReason = reason.isEmpty ? defaultDeferReason(for: diff.trigger) : reason

        for entry in diff.entries {
            guard let action = byID[entry.id] else { continue }
            switch entry.kind {
            case .kept:
                break
            case .moved:
                guard !entry.toSlot.isEmpty else { break }
                action.timeSlot = entry.toSlot
                // A soft, instruction-style cue so the timeline reads "rescheduled"
                // rather than just snapping to a new time.
                action.scheduleCue = "Rescheduled · \(entry.toSlot)"
            case .dropped:
                // Gentle roll-forward — NEVER abandoned. CarryOverService.isUnfinished
                // returns true for .deferred, so this clones to tomorrow's plan.
                action.lifecycle = .deferred
                action.deferredFrom = dayStart
                if action.deferralReason.isEmpty { action.deferralReason = dropReason }
            }
        }
    }

    private static func defaultDeferReason(for trigger: Trigger) -> String {
        switch trigger {
        case .healthFlare: return "health day"
        case .lowEnergy:   return "low energy"
        case .calendarOverrun: return "day ran long"
        case .missedBlocks:    return "day got full"
        case .manual:          return "re-planned"
        }
    }

    // MARK: - Health-flare path

    /// The humane health-flare diff: defer EVERYTHING except the single protected
    /// block, with gentle health-first phrasing. "Here's the one thing to still feel
    /// okay; tell me when you feel better." The deferred rest can be restored later
    /// via `revert` against the snapshot.
    static func healthFlareDiff(
        for plan: DailyPlan,
        prefs: UserPreferences?,
        goals: [Goal],
        now: Date = .now
    ) -> PlanDiff {
        buildDiff(for: plan, trigger: .healthFlare, prefs: prefs, goals: goals, now: now)
    }

    // MARK: - Auto-detect triggers (offers, never verdicts)

    /// Suggest a disruption trigger from current signals, or nil when the day looks
    /// fine. This is an OFFER surfaced softly — it never acts on its own. Order of
    /// concern: a low recent energy reading, then many missed blocks.
    ///   • lowEnergy: most recent check-in within 6h is ≤ 2.
    ///   • missedBlocks: 3+ remaining blocks already started but untouched.
    static func suggestedTrigger(
        plan: DailyPlan,
        recentEnergy: Int?,
        now: Date = .now
    ) -> Trigger? {
        if let level = recentEnergy, level <= 2 {
            return .lowEnergy(level: level)
        }
        let nowMin = nowMinutes(now)
        let missed = (plan.actions ?? []).filter { action in
            guard !isSettled(action), action.anchorKind == .goalWork else { return false }
            guard let start = DailyTimeline.minutes(from: action.timeSlot) else { return false }
            // Started but not done and now well past its start → slipped.
            return start + max(0, action.durationMinutes) <= nowMin
        }.count
        if missed >= 3 { return .missedBlocks(count: missed) }
        return nil
    }
}
