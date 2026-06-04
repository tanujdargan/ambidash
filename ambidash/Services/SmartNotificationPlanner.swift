// ambidash/Services/SmartNotificationPlanner.swift
//
// v5 feat/v5-notifications — the PURE planning brain behind smart notifications. Decides WHEN to
// fire (the three daily check-ins, learned-optimal goal nudges, streak-at-risk reminders) from
// the user's learned patterns and today's calendar, with zero UNUserNotificationCenter / EventKit
// dependency so it's fully unit-testable. NotificationService+Smart consumes these times to
// actually schedule grouped notifications.
import Foundation

enum SmartNotificationPlanner {

    /// A busy span on the calendar, in minutes-from-midnight (so the planner needn't touch
    /// EventKit). `endMinute` may exceed 1440 conceptually but callers pass same-day spans.
    struct BusyInterval: Equatable {
        let startMinute: Int
        let endMinute: Int
    }

    /// The three adaptive daily check-in times (minutes-from-midnight), derived from the user's
    /// waking window so they always land while they're awake and roughly at the right phase of day.
    struct CheckInTimes: Equatable {
        let morning: Int   // shortly after waking — energy check
        let midday: Int    // mid-day — progress check
        let evening: Int   // before bed — reflection
    }

    // MARK: - Waking window

    /// Is `minute` inside the [wake, sleep) waking window? Handles a sleep time past midnight
    /// (wake 07:00 / sleep 01:00). Pure — wake/sleep are passed explicitly.
    static func isWaking(_ minute: Int, wakeMinutes: Int, sleepMinutes: Int) -> Bool {
        let m = ((minute % 1440) + 1440) % 1440
        if wakeMinutes <= sleepMinutes {
            return m >= wakeMinutes && m < sleepMinutes
        } else {
            return m >= wakeMinutes || m < sleepMinutes
        }
    }

    /// Length of the awake window in minutes (handles the past-midnight case).
    static func wakingLength(wakeMinutes: Int, sleepMinutes: Int) -> Int {
        sleepMinutes > wakeMinutes ? sleepMinutes - wakeMinutes : (sleepMinutes + 1440) - wakeMinutes
    }

    // MARK: - Daily check-ins

    /// Morning ~30m after waking, evening ~60m before sleep, midday at the midpoint. All clamped
    /// to stay strictly inside the waking window even for short days.
    static func checkInTimes(wakeMinutes: Int, sleepMinutes: Int) -> CheckInTimes {
        let length = wakingLength(wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes)
        // Offsets shrink for very short awake windows so the three never collide or escape it.
        let morningOffset = min(30, length / 6)
        let eveningOffset = min(60, length / 5)
        let morningAbs = wakeMinutes + morningOffset
        let eveningAbs = wakeMinutes + length - eveningOffset
        let middayAbs = wakeMinutes + length / 2
        return CheckInTimes(
            morning: morningAbs % 1440,
            midday: middayAbs % 1440,
            evening: ((eveningAbs % 1440) + 1440) % 1440
        )
    }

    // MARK: - Optimal nudge time (learned)

    /// The learned-best minute-of-day for a goal nudge: the waking hour with the highest combined
    /// energy + adherence score, then nudged out of any calendar-busy span. Falls back to a sane
    /// default (≈3h after waking) when there's no learned signal yet. Deterministic tie-break
    /// (earliest qualifying hour) so the same inputs always yield the same time.
    static func optimalNudgeMinute(
        energyByHour: [Int: Double],
        adherenceByHour: [Int: Double],
        wakeMinutes: Int,
        sleepMinutes: Int,
        busy: [BusyInterval] = []
    ) -> Int {
        var bestHour: Int? = nil
        var bestScore = -1.0
        for hour in 0..<24 {
            let minute = hour * 60
            guard isWaking(minute, wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes) else { continue }
            let energy = (energyByHour[hour] ?? 0) / 5.0          // 1–5 → 0–1
            let adherence = adherenceByHour[hour] ?? 0            // already 0–1
            let score = energy + adherence
            if score > bestScore {                                // strict > keeps the EARLIEST best
                bestScore = score
                bestHour = hour
            }
        }

        let target: Int
        if let bestHour, bestScore > 0 {
            target = bestHour * 60
        } else {
            // No learned signal: a calm default ~3h after waking, clamped into the window.
            let fallback = wakeMinutes + 180
            target = isWaking(fallback, wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes)
                ? fallback
                : (wakeMinutes + min(180, wakingLength(wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes) / 2)) % 1440
        }
        return avoidingBusy(minute: target % 1440, busy: busy, wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes)
    }

    /// Shift `minute` out of any busy interval it lands in: move to just after the busy span ends
    /// (+5m buffer). If that escapes the waking window, try just before the busy span starts.
    /// Returns the original minute when it's already free (or no good alternative exists).
    static func avoidingBusy(minute: Int, busy: [BusyInterval], wakeMinutes: Int, sleepMinutes: Int) -> Int {
        guard let hit = busy.first(where: { minute >= $0.startMinute && minute < $0.endMinute }) else {
            return minute
        }
        let after = (hit.endMinute + 5) % 1440
        if isWaking(after, wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes),
           !busy.contains(where: { after >= $0.startMinute && after < $0.endMinute }) {
            return after
        }
        let before = (hit.startMinute - 5 + 1440) % 1440
        if isWaking(before, wakeMinutes: wakeMinutes, sleepMinutes: sleepMinutes),
           !busy.contains(where: { before >= $0.startMinute && before < $0.endMinute }) {
            return before
        }
        return minute
    }

    // MARK: - Streak at risk

    /// A streak is "at risk" when there's been no progress logged YET today — the reminder should
    /// fire (gently) so the run isn't lost. `lastProgressDate` nil (never logged) also counts.
    static func isStreakAtRisk(lastProgressDate: Date?, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let last = lastProgressDate else { return true }
        return !calendar.isDate(last, inSameDayAs: now)
    }
}
