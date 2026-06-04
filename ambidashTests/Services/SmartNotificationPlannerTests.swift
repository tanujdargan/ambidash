import Testing
import Foundation
@testable import ambidash

// v5 feat/v5-notifications — unit tests for the PURE smart-notification planning logic. The
// UNUserNotificationCenter scheduling and EventKit fetch are side effects exercised elsewhere;
// every timing decision (check-in placement, learned-optimal hour, busy avoidance, streak risk)
// lives in SmartNotificationPlanner and is tested here.

private typealias P = SmartNotificationPlanner

// MARK: - Waking window

@Test func isWakingSameDayWindow() {
    #expect(P.isWaking(600, wakeMinutes: 420, sleepMinutes: 1410))   // 10:00 inside 07:00–23:30
    #expect(!P.isWaking(120, wakeMinutes: 420, sleepMinutes: 1410))  // 02:00 outside
    #expect(!P.isWaking(1410, wakeMinutes: 420, sleepMinutes: 1410)) // sleep edge exclusive
}

@Test func isWakingWrapPastMidnight() {
    // Wake 07:00, sleep 01:00 (next day).
    #expect(P.isWaking(1380, wakeMinutes: 420, sleepMinutes: 60))   // 23:00 awake
    #expect(P.isWaking(30, wakeMinutes: 420, sleepMinutes: 60))     // 00:30 awake
    #expect(!P.isWaking(180, wakeMinutes: 420, sleepMinutes: 60))   // 03:00 asleep
}

@Test func wakingLengthHandlesBothCases() {
    #expect(P.wakingLength(wakeMinutes: 420, sleepMinutes: 1410) == 990)
    #expect(P.wakingLength(wakeMinutes: 420, sleepMinutes: 60) == 1080) // 18h awake
}

// MARK: - Check-in times

@Test func checkInTimesAreOrderedAndWaking() {
    let t = P.checkInTimes(wakeMinutes: 420, sleepMinutes: 1410)
    #expect(t.morning == 450)   // 07:30
    #expect(t.evening == 1350)  // 22:30
    #expect(t.midday == 915)    // 15:15
    #expect(t.morning < t.midday && t.midday < t.evening)
    for m in [t.morning, t.midday, t.evening] {
        #expect(P.isWaking(m, wakeMinutes: 420, sleepMinutes: 1410))
    }
}

@Test func checkInTimesStayInsideShortWindow() {
    // A very short awake window (06:00–10:00 = 240m) must keep all three inside it.
    let t = P.checkInTimes(wakeMinutes: 360, sleepMinutes: 600)
    for m in [t.morning, t.midday, t.evening] {
        #expect(P.isWaking(m, wakeMinutes: 360, sleepMinutes: 600))
    }
    #expect(t.morning < t.midday && t.midday < t.evening)
}

// MARK: - Optimal nudge minute

@Test func optimalNudgePicksHighestCombinedScore() {
    let energy = [9: 5.0, 15: 3.0]       // normalized: 1.0, 0.6
    let adherence = [9: 0.2, 15: 0.9]    // total: 1.2 vs 1.5
    let m = P.optimalNudgeMinute(energyByHour: energy, adherenceByHour: adherence,
                                 wakeMinutes: 420, sleepMinutes: 1410)
    #expect(m == 15 * 60) // 15:00 wins
}

@Test func optimalNudgeTieBreaksToEarliestHour() {
    let energy = [10: 5.0, 16: 5.0]
    let adherence = [10: 0.5, 16: 0.5]
    let m = P.optimalNudgeMinute(energyByHour: energy, adherenceByHour: adherence,
                                 wakeMinutes: 420, sleepMinutes: 1410)
    #expect(m == 10 * 60)
}

@Test func optimalNudgeFallsBackWhenNoSignal() {
    let m = P.optimalNudgeMinute(energyByHour: [:], adherenceByHour: [:],
                                 wakeMinutes: 420, sleepMinutes: 1410)
    #expect(m == 600) // wake 420 + 180 = 10:00
}

@Test func optimalNudgeAvoidsBusyHour() {
    // Best hour is 09:00 but 09:00–10:00 is busy → pushed to just after (10:05).
    let energy = [9: 5.0]
    let adherence = [9: 0.9]
    let busy = [P.BusyInterval(startMinute: 540, endMinute: 600)]
    let m = P.optimalNudgeMinute(energyByHour: energy, adherenceByHour: adherence,
                                 wakeMinutes: 420, sleepMinutes: 1410, busy: busy)
    #expect(m == 605)
}

// MARK: - Busy avoidance

@Test func avoidingBusyLeavesFreeMinuteUnchanged() {
    let busy = [P.BusyInterval(startMinute: 540, endMinute: 600)]
    #expect(P.avoidingBusy(minute: 480, busy: busy, wakeMinutes: 420, sleepMinutes: 1410) == 480)
}

@Test func avoidingBusyShiftsAfterBusy() {
    let busy = [P.BusyInterval(startMinute: 540, endMinute: 600)]
    #expect(P.avoidingBusy(minute: 550, busy: busy, wakeMinutes: 420, sleepMinutes: 1410) == 605)
}

@Test func avoidingBusyShiftsBeforeWhenAfterEscapesWindow() {
    // Busy span runs to the end of the day → "after" isn't waking, so fall back to just before.
    let busy = [P.BusyInterval(startMinute: 540, endMinute: 1410)]
    #expect(P.avoidingBusy(minute: 550, busy: busy, wakeMinutes: 420, sleepMinutes: 1410) == 535)
}

// MARK: - Streak at risk

@Test func streakAtRiskWhenNeverLogged() {
    #expect(P.isStreakAtRisk(lastProgressDate: nil))
}

@Test func streakAtRiskWhenLastProgressNotToday() {
    let cal = Calendar(identifier: .gregorian)
    let now = cal.date(from: DateComponents(year: 2024, month: 5, day: 10, hour: 18))!
    let yesterday = cal.date(from: DateComponents(year: 2024, month: 5, day: 9, hour: 20))!
    let today = cal.date(from: DateComponents(year: 2024, month: 5, day: 10, hour: 8))!
    #expect(P.isStreakAtRisk(lastProgressDate: yesterday, now: now, calendar: cal))
    #expect(!P.isStreakAtRisk(lastProgressDate: today, now: now, calendar: cal))
}
