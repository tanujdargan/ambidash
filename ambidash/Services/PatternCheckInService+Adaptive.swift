// ambidash/Services/PatternCheckInService+Adaptive.swift
//
// v5 feat/v5-adaptive-scheduling — extends PatternCheckInService with RECURRING-ISSUE detection:
// when a drift persists for a week or so (e.g. waking late most days), surface it once, gently,
// with TWO concrete fixes — adjust the target to reality, OR adjust the upstream routine — so the
// user picks the lever that fits. Pure + testable; produces an in-memory AdaptiveSuggestion.
import Foundation

extension PatternCheckInService {

    /// Days of a recurring drift before we treat it as a pattern worth a two-option offer (a week).
    static let recurringIssueDays = 5
    /// Minimum average drift (minutes) for the recurring wake issue to be worth surfacing.
    static let recurringMinDriftMinutes = 30

    /// A persistent late-wake pattern → offer to either move the wake target later (accept reality)
    /// or pull the wind-down earlier (fix the cause). Returns nil until it's a real, week-ish
    /// pattern, so it never nags on a single late morning.
    ///
    /// - Parameters:
    ///   - lateWakeDays: how many of the recent days the user woke meaningfully later than target.
    ///   - avgDriftMinutes: the average minutes-late across those days.
    ///   - currentWake: the user's current wake target ("HH:mm").
    ///   - currentSleep: the current wind-down target ("HH:mm"), for the routine-fix option.
    static func recurringWakeIssue(
        lateWakeDays: Int,
        avgDriftMinutes: Int,
        currentWake: String,
        currentSleep: String
    ) -> AdaptiveSuggestion? {
        guard lateWakeDays >= recurringIssueDays, avgDriftMinutes >= recurringMinDriftMinutes else { return nil }

        // Round the drift to a tidy 15-minute step for the proposed new wake.
        let step = max(15, (avgDriftMinutes / 15) * 15)
        let newWake = AdaptiveScheduling.clockByAdding(minutes: step, to: currentWake)
        let earlierSleep = AdaptiveScheduling.clockByAdding(minutes: -30, to: currentSleep)

        return AdaptiveSuggestion(
            kind: .recurringIssue,
            title: "Your mornings have drifted later",
            body: "You've woken around \(avgDriftMinutes) min later than \(currentWake) for \(lateWakeDays) days. That's a pattern, not a slip — want to meet it where it is, or nudge the night earlier so the morning's easier?",
            symbol: "sunrise",
            options: [
                AdaptiveOption(id: "movewake", label: "Move wake to \(newWake)", isPrimary: true),
                AdaptiveOption(id: "earliernight", label: "Wind down by \(earlierSleep) instead"),
            ]
        )
    }
}
