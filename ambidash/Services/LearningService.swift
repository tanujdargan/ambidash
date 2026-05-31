// ambidash/Services/LearningService.swift
import Foundation
import SwiftData

/// LOGGING / learning engine (build-order #3) — the on-device pattern layer that
/// reads `ActualEvent`s (what the user really did) and `EnergyCheckin`s (how they
/// felt) and turns them into gentle, non-punitive signals the planner can use to
/// adapt the day to the real human.
///
/// Mirrors the codebase convention (CarryOverService / PlanGenerator): an `enum`
/// namespace of PURE static helpers. No instances, no stored state, no saves — the
/// caller owns any transaction. Everything is computed from data passed in, so it is
/// trivially testable and never touches the network.
///
/// PRIVACY: operates only on the user's private store data; produces aggregates, not
/// raw personal text. Nothing here logs or transmits.
enum LearningService {

    // MARK: - Duration deltas

    /// Per-action planned-vs-actual duration deltas for a day's plan, keyed by the
    /// `PlannedAction.id`. Only actions that have a matching logged `ActualEvent`
    /// appear. `delta = actual - planned` (negative = the user underran the
    /// estimate; positive = it ran long). Lets the planner right-size future
    /// estimates instead of repeatedly over-scheduling.
    static func analyzeDurationDeltas(
        plan: DailyPlan,
        actuals: [ActualEvent]
    ) -> [UUID: (planned: Int, actual: Int, delta: Int)] {
        let actions = plan.actions ?? []
        // Index actuals by the action they were logged against (take the longest
        // actual when several were logged for one block).
        var byAction: [UUID: ActualEvent] = [:]
        for ev in actuals {
            guard let aid = ev.linkedActionID else { continue }
            if let existing = byAction[aid], existing.actualDurationMinutes >= ev.actualDurationMinutes { continue }
            byAction[aid] = ev
        }

        var out: [UUID: (planned: Int, actual: Int, delta: Int)] = [:]
        for action in actions {
            guard let ev = byAction[action.id] else { continue }
            let planned = max(0, action.durationMinutes)
            let actual = ev.actualDurationMinutes
            out[action.id] = (planned, actual, actual - planned)
        }
        return out
    }

    // MARK: - Adherence by time slot

    /// Adherence bucketed by hour-of-day, computed from logged actuals over the
    /// supplied window. For each hour that has any logged events, returns how many
    /// resolved as `completed` out of the total logged there, plus the ratio. The
    /// planner can bias goal-work toward the user's actually-followed-through hours.
    ///
    /// IMPORTANT (non-punitive + honest signal): this tracks COMPLETION % among
    /// logged events, surfacing numerator + denominator so a thin sample is never
    /// read as "incapable in the morning". A morning-busy day ≠ morning-incapable.
    static func computeAdherenceByHour(
        actuals: [ActualEvent]
    ) -> [Int: (completed: Int, total: Int, ratio: Double)] {
        var buckets: [Int: (completed: Int, total: Int)] = [:]
        for ev in actuals {
            let hour = max(0, min(23, ev.startMinutes / 60))
            var b = buckets[hour] ?? (0, 0)
            b.total += 1
            if ev.completionStatus == .completed { b.completed += 1 }
            buckets[hour] = b
        }
        var out: [Int: (completed: Int, total: Int, ratio: Double)] = [:]
        for (hour, b) in buckets {
            let ratio = b.total > 0 ? Double(b.completed) / Double(b.total) : 0
            out[hour] = (b.completed, b.total, ratio)
        }
        return out
    }

    // MARK: - Real wake / sleep inference

    /// Infer the user's REAL wake and sleep minutes-from-midnight for a day from the
    /// logged actuals. Sleep/wake are ONLY inferred from `.health`-sourced events
    /// (actual sleep/wake samples); other logged activity — a daytime study block, a
    /// workout — is NOT the user's wake or sleep time. The planner uses these to anchor
    /// the day to how the user actually lives rather than the ideal `UserPreferences`
    /// defaults.
    ///
    /// Conservative graceful no-op: with no `.health` events both are nil and the caller
    /// keeps the existing preferences. This prevents "latest logged activity end" from
    /// being mistaken for bedtime (which would collapse the planning window mid-afternoon
    /// and drop goal-work) and "earliest logged start" from being mistaken for wake-up.
    static func inferWakeSleep(
        actuals: [ActualEvent]
    ) -> (wakeMinutes: Int?, sleepMinutes: Int?) {
        // Only HealthKit-sourced sleep/wake samples are authoritative here. Manual
        // activity logs say nothing about when the user actually woke or went to bed.
        let health = actuals.filter { $0.source == .health }
        guard !health.isEmpty else { return (nil, nil) }
        // A sleep sample that crosses midnight is recorded with endMinutes < startMinutes
        // (start = bedtime the prior evening, end = this morning's wake). For those the
        // morning WAKE is the event's END and the SLEEP/bedtime is its START — the
        // opposite of a same-day event. Treat them specially so an overnight night isn't
        // read as "woke at 23:00, slept at 07:00".
        let overnight = health.filter { $0.endMinutes < $0.startMinutes }
        if !overnight.isEmpty {
            // Wake = the latest morning wake-up (end) across overnight samples; sleep =
            // the earliest bedtime (start). Same-day health samples (workouts etc.) still
            // contribute their plain start/end as a fallback floor/ceiling.
            let sameDay = health.filter { $0.endMinutes >= $0.startMinutes }
            let wake = (overnight.map(\.endMinutes) + sameDay.map(\.startMinutes)).max()
            let sleep = (overnight.map(\.startMinutes) + sameDay.map(\.endMinutes)).min()
            return (wake, sleep)
        }
        let wake = health.map(\.startMinutes).min()
        let sleep = health.map(\.endMinutes).max()
        return (wake, sleep)
    }

    // MARK: - Energy pattern

    /// Average energy per hour-of-day from recent check-ins, keyed by hour. Lets the
    /// planner place demanding work where the user actually has energy (and back off
    /// when they're typically depleted) — humane, not aspirational.
    static func computeEnergyByHour(
        checkins: [EnergyCheckin]
    ) -> [Int: Double] {
        var sums: [Int: (total: Int, count: Int)] = [:]
        for c in checkins {
            let hour = Calendar.current.component(.hour, from: c.date)
            var s = sums[hour] ?? (0, 0)
            s.total += c.clampedLevel
            s.count += 1
            sums[hour] = s
        }
        return sums.mapValues { Double($0.total) / Double(max(1, $0.count)) }
    }

    /// The most recent energy check-in's level, if any was logged within `within`
    /// seconds of `reference` (default 6 hours). Drives the disruption flow's
    /// "collapse to one thing when low" trigger without forcing a fresh prompt.
    static func recentEnergyLevel(
        checkins: [EnergyCheckin],
        reference: Date = .now,
        within seconds: TimeInterval = 6 * 3600
    ) -> Int? {
        checkins
            .filter { reference.timeIntervalSince($0.date) >= 0 && reference.timeIntervalSince($0.date) <= seconds }
            .max(by: { $0.date < $1.date })?
            .clampedLevel
    }

    // MARK: - Auto-inference from completed plans

    /// Build an `inferred` `ActualEvent` from a completed `PlannedAction`, so logging
    /// is mostly automatic: a block the user marked done with a known timeSlot +
    /// duration becomes a logged actual with no extra taps. Returns nil when there
    /// isn't enough to infer a time (no resolvable timeSlot) — the user can still log
    /// it manually. Does NOT insert/save; the caller owns the transaction and should
    /// de-dupe on `linkedActionID` first.
    static func inferredEvent(
        from action: PlannedAction,
        on day: Date
    ) -> ActualEvent? {
        guard action.statusRaw == "done" else { return nil }
        guard let start = DailyTimeline.minutes(from: action.timeSlot) else { return nil }
        let dayStart = Calendar.current.startOfDay(for: day)
        return ActualEvent(
            title: action.title,
            startMinutes: start,
            endMinutes: start + max(0, action.durationMinutes),
            date: dayStart,
            sourceRaw: ActualEventSource.inferred.rawValue,
            completionStatusRaw: ActualCompletionStatus.completed.rawValue,
            linkedActionID: action.id,
            linkedGoalID: action.goalID
        )
    }

    // MARK: - Learned profile (the wired output the planner consumes)

    /// Build a `LearnedProfile` from the user's recent logged actuals + energy
    /// check-ins. This is the SINGLE aggregate the planner reads — it folds duration
    /// deltas, real wake/sleep, and adherence-by-hour into one explainable bundle so
    /// `PlanGenerator` can adapt the day to the real human without re-querying.
    ///
    /// Everything is derived from the passed-in data (pure, testable, no network).
    /// Each learned signal carries the sample size that produced it, so the planner —
    /// and any future UI — can show confidence ("from 6 days") and never overfit to a
    /// single disrupted day. With no data the profile is fully empty and every
    /// `adjusted*` accessor is an identity no-op, so day-1 behaviour is unchanged.
    ///
    /// - Parameters:
    ///   - actuals: logged `ActualEvent`s over the learning window (caller decides
    ///     the window, typically the last ~14 days).
    ///   - checkins: logged `EnergyCheckin`s over the same window.
    ///   - minSamplesForDuration: how many logged events for one goal are required
    ///     before its learned duration is trusted (guards against a single outlier).
    static func buildProfile(
        actuals: [ActualEvent],
        checkins: [EnergyCheckin] = [],
        minSamplesForDuration: Int = 2
    ) -> LearnedProfile {
        // --- Per-goal learned durations (planned-vs-actual) ---
        // Group every linked, completed/partial actual by its goal, comparing the
        // logged actual minutes against the planned minutes we can recover. We DON'T
        // have the plan here, so we learn the user's typical ACTUAL duration per goal
        // and let the planner re-estimate from that. abandoned events are excluded —
        // a walked-away block isn't evidence the task is short.
        var byGoal: [UUID: [Int]] = [:]
        for ev in actuals {
            guard let gid = ev.linkedGoalID else { continue }
            guard ev.completionStatus != .abandoned else { continue }
            let dur = ev.actualDurationMinutes
            guard dur > 0 else { continue }
            byGoal[gid, default: []].append(dur)
        }
        var durations: [UUID: LearnedDuration] = [:]
        for (gid, samples) in byGoal where samples.count >= minSamplesForDuration {
            let median = Self.median(samples)
            guard median > 0 else { continue }
            durations[gid] = LearnedDuration(
                goalID: gid,
                typicalMinutes: median,
                sampleCount: samples.count
            )
        }

        // --- Real wake / sleep (already inferred per the existing helper) ---
        let (wake, sleep) = inferWakeSleep(actuals: actuals)
        // Count the distinct days the inference is grounded in, for confidence.
        let dayKeys = Set(actuals.map { Calendar.current.startOfDay(for: $0.date) })

        // --- Adherence by hour ---
        let adherence = computeAdherenceByHour(actuals: actuals)

        return LearnedProfile(
            durations: durations,
            realWakeMinutes: wake,
            realSleepMinutes: sleep,
            wakeSleepDayCount: dayKeys.count,
            adherenceByHour: adherence,
            energyByHour: computeEnergyByHour(checkins: checkins)
        )
    }

    /// Convenience: fetch the recent `ActualEvent`s + `EnergyCheckin`s from a
    /// `ModelContext` (default: the last `days` days) and build a `LearnedProfile`.
    /// Keeps the call sites (TodayView / MacTodayView) thin and identical, and means
    /// the windowing/query logic lives in one place. Returns an empty profile (a
    /// strict planner no-op) on any fetch failure or when there's no logged data.
    static func buildProfile(
        from context: ModelContext,
        days: Int = 14,
        reference: Date = .now
    ) -> LearnedProfile {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: reference)
            ?? reference.addingTimeInterval(-Double(days) * 86_400)
        let eventDesc = FetchDescriptor<ActualEvent>(
            predicate: #Predicate { $0.date >= cutoff }
        )
        let checkinDesc = FetchDescriptor<EnergyCheckin>(
            predicate: #Predicate { $0.date >= cutoff }
        )
        let actuals = (try? context.fetch(eventDesc)) ?? []
        let checkins = (try? context.fetch(checkinDesc)) ?? []
        return buildProfile(actuals: actuals, checkins: checkins)
    }

    /// Median of a non-empty int sample (returns 0 for empty). Median, not mean, so a
    /// single very-long or very-short logged block can't drag the learned estimate.
    static func median(_ values: [Int]) -> Int {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[mid] }
        return (sorted[mid - 1] + sorted[mid]) / 2
    }
}

// MARK: - LearnedProfile

/// The per-goal typical duration the learning layer inferred from logged actuals.
struct LearnedDuration {
    let goalID: UUID
    /// The user's typical ACTUAL minutes for work on this goal (median of samples).
    let typicalMinutes: Int
    /// How many logged events back this estimate (for confidence / explainability).
    let sampleCount: Int
}

/// The explainable bundle of everything the on-device learning layer inferred about
/// how the user ACTUALLY lives, ready for `PlanGenerator` to consume. Computed (not
/// persisted) — rebuilt cheaply from the recent actuals/check-ins each generation.
///
/// Explainability is a first-class requirement: every adjustment the planner makes
/// from this profile can be traced to a sample-backed field here (e.g. "scheduled
/// gym for 45m not 20m — your last 4 logs averaged 45m"). The `explain*` helpers
/// produce those human strings.
///
/// NON-PUNITIVE: adherence is a placement HINT only (bias toward when the user
/// follows through), never a verdict; low-adherence hours are simply de-prioritised,
/// never blocked or flagged.
struct LearnedProfile {
    /// Per-goal learned typical durations, keyed by goalID. Absent ⇒ no signal yet ⇒
    /// the planner keeps the template default for that goal.
    var durations: [UUID: LearnedDuration] = [:]

    /// The user's REAL inferred wake / sleep minutes-from-midnight, or nil when there
    /// isn't enough signal (then the planner keeps the `UserPreferences` targets).
    var realWakeMinutes: Int? = nil
    var realSleepMinutes: Int? = nil
    /// Distinct days behind the wake/sleep inference (confidence).
    var wakeSleepDayCount: Int = 0

    /// Completion-ratio per hour-of-day (completed, total, ratio). Used only to BIAS
    /// goal-work placement toward hours the user actually follows through.
    var adherenceByHour: [Int: (completed: Int, total: Int, ratio: Double)] = [:]

    /// Average reported energy per hour-of-day (1–5). Available for future
    /// energy-aware placement; not yet a hard input to scheduling.
    var energyByHour: [Int: Double] = [:]

    /// True when nothing was learned — the planner then behaves exactly as before.
    var isEmpty: Bool {
        durations.isEmpty && realWakeMinutes == nil && realSleepMinutes == nil
            && adherenceByHour.isEmpty
    }

    // MARK: Planner-facing accessors (each adjustment is traceable)

    /// The duration the planner should use for goal-work on `goalID`, given the
    /// template's default. Returns the learned typical when we have enough signal,
    /// else the unchanged default (identity no-op). Clamped so a wild estimate can't
    /// produce an absurd block.
    func adjustedDuration(forGoal goalID: UUID?, default fallback: Int) -> Int {
        guard let goalID, let learned = durations[goalID] else { return fallback }
        // Clamp to a sane band around the template so learning refines, never
        // explodes, the estimate (5 min … 4 h).
        return max(5, min(240, learned.typicalMinutes))
    }

    /// Human, traceable reason for a duration adjustment, or nil when unchanged.
    /// e.g. "Sized to 45m — your last 4 logs of this goal averaged 45m."
    func explainDuration(forGoal goalID: UUID?, default fallback: Int) -> String? {
        guard let goalID, let learned = durations[goalID] else { return nil }
        let adjusted = max(5, min(240, learned.typicalMinutes))
        guard adjusted != fallback else { return nil }
        return "Sized to \(adjusted)m (was \(fallback)m) — your last \(learned.sampleCount) logs here typically ran \(learned.typicalMinutes)m."
    }

    /// An adherence score in 0…1 for an hour-of-day, or nil when that hour has no
    /// logged history (so the planner treats it neutrally, never penalised).
    func adherenceRatio(forHour hour: Int) -> Double? {
        adherenceByHour[hour].map(\.ratio)
    }
}
