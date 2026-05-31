// ambidash/Services/PatternCheckInService.swift
//
// PATTERN CHECK-INS — build-order #8 (feature-brief) and the "offers not verdicts"
// refinement in /tmp/v3-design/differentiators.md.
//
// Reads the on-device `LearnedProfile` (real-vs-target wake/sleep, adherence-by-hour,
// per-goal duration deltas, energy-by-hour — all produced by LearningService from the
// user's PRIVATE logged actuals) and detects a PERSISTENT drift from what the user
// planned. When one is found it surfaces a single GENTLE, NON-JUDGMENTAL, CHOICE-GIVING
// offer (e.g. "You've been waking ~8:30. Move the plan to 8:30, or keep 7:00 and look
// at the night routine?").
//
// DESIGN CONTRACT
//  • OFFERS, never verdicts. Two humane choices + "not now". Accepting EDITS
//    `UserPreferences` (wake/sleep/meal/workout times) — nothing is ever forced.
//  • CONFIDENCE-GATED. Each insight requires a minimum sample (days / logged events)
//    so a single disrupted day never triggers a check-in. The confidence string
//    ("from 6 days") is shown to the user — honesty over certainty.
//  • NON-PUNITIVE. Adherence dips are framed as scheduling fit ("Wednesdays you
//    complete <30% of afternoon blocks — lighter afternoons?"), never "you failed".
//    Numerator + denominator travel with the signal so a thin sample never reads as
//    "incapable". No red, no shame; this is the same spirit as the `deferred` token.
//  • ON-DEVICE + PRIVATE. Operates only on aggregates already computed locally by
//    LearningService. Nothing here logs or transmits; AI phrasing (a TOP layer) keeps
//    energy/health context on-device first.
//
// PURE + TESTABLE: an `enum` namespace of static helpers, mirroring LearningService /
// DisruptionService / CarryOverService. No instances, no stored state, no saves — the
// caller owns any transaction. Compiles in BOTH targets (no SwiftUI, no iOS-only API).

import Foundation

enum PatternCheckInService {

    // MARK: - Insight kind

    /// Which drift a check-in is about. Drives the icon/title and which preference an
    /// ACCEPT edits. Additive — new kinds are pure additions.
    enum Kind: String, Equatable {
        case wake          // real wake later/earlier than planned wakeTime
        case sleep         // real sleep later/earlier than planned sleepTime
        case duration      // a goal consistently runs longer/shorter than planned
        case adherence     // a window the user consistently doesn't follow through on
        case energyTrough  // a recurring low-energy hour worth scheduling lighter
    }

    /// One of the two humane choices on an offer. `editPrefs` mutates a copy of the
    /// supplied `UserPreferences` in place; nothing is saved here — the caller owns the
    /// transaction (so it can save atomically after the user taps).
    struct Choice: Identifiable, Equatable {
        let id: String
        /// The button label, e.g. "Move wake to 8:30".
        let label: String
        /// True for the "adjust the plan to reality" option (vs. "keep my target").
        let isPrimary: Bool
        /// What this choice does when accepted. `.adjust` edits a preference;
        /// `.keepTarget` is the gentle no-op that simply acknowledges + dismisses.
        let action: Action

        enum Action: Equatable {
            /// Set a preference field to a new value (the only mutation a check-in makes).
            case setWake(String)
            case setSleep(String)
            case setBreakfast(String)
            case setLunch(String)
            case setDinner(String)
            case setWorkout(String)
            /// Keep the existing target — acknowledge the reality without changing the plan.
            case keepTarget
        }

        static func == (l: Choice, r: Choice) -> Bool { l.id == r.id }
    }

    /// A single, surfaced gentle offer. A VALUE type (never a @Model) — held in memory
    /// by the card until the user taps a choice, so there is zero CloudKit schema change
    /// and zero migration risk. `id` is stable per-kind so a dismissed offer for the
    /// same drift doesn't re-key the view mid-session.
    struct PatternInsight: Identifiable, Equatable {
        let kind: Kind
        /// The calm headline ("Your mornings have shifted").
        let title: String
        /// The body — what we noticed, framed as observation not verdict.
        let body: String
        /// The honest confidence line ("from 6 days"), always shown.
        let confidence: String
        /// The two humane choices (adjust-to-reality + keep-target).
        let choices: [Choice]
        /// A coarse strength used only to rank which single offer to show first.
        let strength: Double

        var id: String { kind.rawValue }

        var headline: String { title }
    }

    // MARK: - Tunables (confidence gates)

    /// Minimum distinct days of wake/sleep inference before a wake/sleep offer fires.
    static let minWakeSleepDays = 5
    /// Minimum clock drift (minutes) before a wake/sleep shift is worth offering —
    /// below this it's noise, not a pattern.
    static let minDriftMinutes = 45
    /// Minimum logged events in an hour-window before an adherence offer fires.
    static let minAdherenceSamples = 4
    /// Adherence ratio at/below which a window is worth gently re-shaping.
    static let lowAdherenceRatio = 0.3
    /// Minimum logged events for a goal before a duration-resize offer fires.
    static let minDurationSamples = 3
    /// Minimum planned-vs-typical duration delta (minutes) worth offering to resize.
    static let minDurationDeltaMinutes = 15

    // MARK: - Detection

    /// Detect the gentle check-ins worth surfacing, strongest first. Returns [] when
    /// nothing crosses its confidence gate — the common, quiet case. The caller
    /// typically shows only `.first` (one offer at a time; never a wall of nags).
    ///
    /// - Parameters:
    ///   - profile: the on-device `LearnedProfile` (LearningService.buildProfile).
    ///   - prefs: the user's current `UserPreferences` (the targets to compare against).
    ///   - goalTitles: optional goalID → title, so a duration offer can name the goal.
    static func insights(
        profile: LearnedProfile,
        prefs: UserPreferences,
        goalTitles: [UUID: String] = [:]
    ) -> [PatternInsight] {
        guard !profile.isEmpty else { return [] }
        var out: [PatternInsight] = []

        if let wake = wakeInsight(profile: profile, prefs: prefs) { out.append(wake) }
        if let sleep = sleepInsight(profile: profile, prefs: prefs) { out.append(sleep) }
        if let dur = durationInsight(profile: profile, prefs: prefs, goalTitles: goalTitles) {
            out.append(dur)
        }
        if let adh = adherenceInsight(profile: profile) { out.append(adh) }

        return out.sorted { $0.strength > $1.strength }
    }

    // MARK: - Wake drift

    private static func wakeInsight(profile: LearnedProfile, prefs: UserPreferences) -> PatternInsight? {
        guard profile.wakeSleepDayCount >= minWakeSleepDays else { return nil }
        guard let realWake = profile.realWakeMinutes,
              let target = DailyTimeline.minutes(from: prefs.wakeTime) else { return nil }
        let drift = realWake - target
        guard abs(drift) >= minDriftMinutes else { return nil }

        let realClock = DailyTimeline.Entry.format(realWake)
        let targetClock = DailyTimeline.Entry.format(target)
        let later = drift > 0
        let confidence = daysConfidence(profile.wakeSleepDayCount)
        let title = "Your mornings have shifted"
        let body = later
            ? "You've been waking around \(realClock), a little after your \(targetClock) plan. No problem — want the plan to match?"
            : "You've been up around \(realClock), ahead of your \(targetClock) plan. Want to claim that earlier start?"

        return PatternInsight(
            kind: .wake,
            title: title,
            body: body,
            confidence: confidence,
            choices: [
                Choice(id: "wake-move", label: "Move wake to \(realClock)", isPrimary: true, action: .setWake(realClock)),
                Choice(id: "wake-keep", label: later ? "Keep \(targetClock), nudge the night" : "Keep \(targetClock)", isPrimary: false, action: .keepTarget)
            ],
            strength: Double(abs(drift)) + Double(profile.wakeSleepDayCount)
        )
    }

    // MARK: - Sleep drift

    private static func sleepInsight(profile: LearnedProfile, prefs: UserPreferences) -> PatternInsight? {
        guard profile.wakeSleepDayCount >= minWakeSleepDays else { return nil }
        guard let realSleep = profile.realSleepMinutes,
              let target = DailyTimeline.minutes(from: prefs.sleepTime) else { return nil }
        let drift = realSleep - target
        guard abs(drift) >= minDriftMinutes else { return nil }

        let realClock = DailyTimeline.Entry.format(realSleep)
        let targetClock = DailyTimeline.Entry.format(target)
        let later = drift > 0
        let confidence = daysConfidence(profile.wakeSleepDayCount)
        let title = "Your evenings run \(later ? "later" : "earlier")"
        let body = later
            ? "Your days have been winding down nearer \(realClock) than your \(targetClock) plan. Want to set a realistic wind-down?"
            : "You've been settling earlier, around \(realClock) vs your \(targetClock) plan. Want the plan to reflect that?"

        return PatternInsight(
            kind: .sleep,
            title: title,
            body: body,
            confidence: confidence,
            choices: [
                Choice(id: "sleep-move", label: "Set wind-down to \(realClock)", isPrimary: true, action: .setSleep(realClock)),
                Choice(id: "sleep-keep", label: "Keep \(targetClock)", isPrimary: false, action: .keepTarget)
            ],
            // Slightly below wake so a wake offer wins the tie (mornings anchor the day).
            strength: Double(abs(drift)) + Double(profile.wakeSleepDayCount) - 1
        )
    }

    // MARK: - Duration drift

    /// The strongest per-goal duration drift vs the user's WORKOUT plan (the one
    /// goal-shaped duration we hold in prefs). The general per-goal resize is handled
    /// by the planner's `LearnedDuration`; here we only surface the prefs-level workout
    /// duration when a clear pattern exists, since that's the one a check-in can EDIT.
    private static func durationInsight(
        profile: LearnedProfile,
        prefs: UserPreferences,
        goalTitles: [UUID: String]
    ) -> PatternInsight? {
        // Find the goal with the most-sampled, biggest typical-duration signal that
        // we can name; surface it as an informational "resize?" — accepting nudges the
        // workout time only when the goal looks like the workout, else keepTarget.
        let best = profile.durations.values
            .filter { $0.sampleCount >= minDurationSamples }
            .max(by: { $0.sampleCount < $1.sampleCount })
        guard let learned = best else { return nil }

        let name = goalTitles[learned.goalID] ?? "this work"
        let typical = learned.typicalMinutes
        let confidence = eventsConfidence(learned.sampleCount)
        let title = "\(name.capitalizedFirst) takes about \(typical)m"
        let body = "Your last \(learned.sampleCount) logs of \(name) typically ran ~\(typical) minutes. Want future days to budget that?"

        // The only prefs-level duration edit available is the workout window; a generic
        // goal can still be acknowledged (keepTarget) so the offer is always actionable.
        let looksLikeWorkout = name.lowercased().contains("gym")
            || name.lowercased().contains("workout")
            || name.lowercased().contains("run")
            || name.lowercased().contains("exercise")

        var choices: [Choice] = []
        if looksLikeWorkout, let start = DailyTimeline.minutes(from: prefs.workoutTime) {
            // Keep the start; the planner already resizes via LearnedDuration. The
            // prefs edit here is a no-op-equivalent confirmation that keeps the start.
            let clock = DailyTimeline.Entry.format(start)
            choices = [
                Choice(id: "dur-ok", label: "Budget ~\(typical)m", isPrimary: true, action: .setWorkout(clock)),
                Choice(id: "dur-keep", label: "Leave as is", isPrimary: false, action: .keepTarget)
            ]
        } else {
            choices = [
                Choice(id: "dur-ok", label: "Good to know", isPrimary: true, action: .keepTarget),
                Choice(id: "dur-keep", label: "Dismiss", isPrimary: false, action: .keepTarget)
            ]
        }

        return PatternInsight(
            kind: .duration,
            title: title,
            body: body,
            confidence: confidence,
            choices: choices,
            // Weakest of the family — wake/sleep anchor the day more.
            strength: Double(learned.sampleCount)
        )
    }

    // MARK: - Adherence drift

    /// The lowest-adherence window with enough samples, surfaced as a scheduling-fit
    /// offer ("afternoons rarely land — lighter afternoons?"), NEVER a verdict. Maps
    /// the hour to a part-of-day label and offers to keep the plan as-is (the user
    /// decides; we only point it out).
    private static func adherenceInsight(profile: LearnedProfile) -> PatternInsight? {
        let candidates = profile.adherenceByHour
            .filter { $0.value.total >= minAdherenceSamples && $0.value.ratio <= lowAdherenceRatio }
        guard let worst = candidates.min(by: { $0.value.ratio < $1.value.ratio }) else { return nil }

        let hour = worst.key
        let part = partOfDay(hour)
        let pct = Int((worst.value.ratio * 100).rounded())
        let confidence = eventsConfidence(worst.value.total)
        let title = "\(part.capitalizedFirst) blocks rarely land"
        let body = "You complete about \(pct)% of your \(part) blocks (\(worst.value.completed) of \(worst.value.total)). That's a scheduling fit thing, not a you thing — want lighter \(part)s?"

        // Adherence has no single prefs field to flip; it's an informational nudge.
        // The humane choices acknowledge it either way (keepTarget) — the value is the
        // surfacing, and the user can re-shape their day manually.
        return PatternInsight(
            kind: .adherence,
            title: title,
            body: body,
            confidence: confidence,
            choices: [
                Choice(id: "adh-note", label: "I'll lighten \(part)s", isPrimary: true, action: .keepTarget),
                Choice(id: "adh-keep", label: "Keep my plan", isPrimary: false, action: .keepTarget)
            ],
            // Strong only with a real sample; ratio inverted so worse → higher.
            strength: (1 - worst.value.ratio) * Double(worst.value.total)
        )
    }

    // MARK: - Apply (the ONLY mutation: edits UserPreferences)

    /// Apply an accepted choice by editing `prefs` in place. `.keepTarget` is a no-op
    /// (the user acknowledged without changing the plan). Does NOT save — the caller
    /// owns the transaction so the tap can persist atomically. Returns true when a
    /// preference actually changed (so the caller can decide whether to save / refresh).
    @discardableResult
    static func apply(_ choice: Choice, to prefs: UserPreferences) -> Bool {
        switch choice.action {
        case .keepTarget:
            return false
        case .setWake(let v):
            guard prefs.wakeTime != v else { return false }
            prefs.wakeTime = v; return true
        case .setSleep(let v):
            guard prefs.sleepTime != v else { return false }
            prefs.sleepTime = v; return true
        case .setBreakfast(let v):
            guard prefs.breakfastTime != v else { return false }
            prefs.breakfastTime = v; return true
        case .setLunch(let v):
            guard prefs.lunchTime != v else { return false }
            prefs.lunchTime = v; return true
        case .setDinner(let v):
            guard prefs.dinnerTime != v else { return false }
            prefs.dinnerTime = v; return true
        case .setWorkout(let v):
            guard prefs.workoutTime != v else { return false }
            prefs.workoutTime = v; return true
        }
    }

    // MARK: - Confidence strings (honest sample sizes)

    private static func daysConfidence(_ days: Int) -> String {
        "from \(days) day\(days == 1 ? "" : "s") of data"
    }

    private static func eventsConfidence(_ count: Int) -> String {
        "from \(count) log\(count == 1 ? "" : "s")"
    }

    // MARK: - Part-of-day labelling

    private static func partOfDay(_ hour: Int) -> String {
        switch hour {
        case 5..<12:  return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default:      return "late-night"
        }
    }
}

// MARK: - Small string helper (target-shared, no Foundation locale surprises)

private extension String {
    /// Capitalize only the first character (leaves the rest untouched — "gym" → "Gym",
    /// "afternoon" → "Afternoon"), avoiding `.capitalized`'s word-by-word behaviour.
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
