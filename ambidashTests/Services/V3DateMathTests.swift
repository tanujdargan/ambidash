// ambidashTests/Services/V3DateMathTests.swift
//
// V3 regression tests for the minutes-from-midnight / day-window date math:
//  • overnight ActualEvent (end < start) yields a correct positive duration, not 0
//  • DisruptionService.planNowMinutes anchors "now" to the plan's own day so a
//    cross-midnight plan reads correctly (the wall-clock day-window helper)
//  • DailyTimeline.Entry.format returns correct wall-clock and wraps safely
//  • DailyTimeline.minutes parses clock strings and tolerates ranges
import Testing
import Foundation
@testable import ambidash

// MARK: - REGRESSION: overnight ActualEvent duration

@Test func overnightActualEventYieldsPositiveDuration() {
    // Sleep logged 23:00 → 07:00 (end < start). Naive end-start would clamp to 0
    // and erase the whole night. Must cross midnight: (07:00 + 24h) - 23:00 = 8h.
    let sleep = ActualEvent(
        title: "Sleep",
        startMinutes: 23 * 60,    // 1380
        endMinutes: 7 * 60,       // 420
        date: .now
    )
    #expect(sleep.actualDurationMinutes == 8 * 60)
    #expect(sleep.actualDurationMinutes > 0)
}

@Test func sameDayActualEventDurationIsPlainDifference() {
    let ev = ActualEvent(startMinutes: 9 * 60, endMinutes: 10 * 60 + 30, date: .now)
    #expect(ev.actualDurationMinutes == 90)
}

@Test func zeroLengthActualEventIsZeroNotADay() {
    let ev = ActualEvent(startMinutes: 600, endMinutes: 600, date: .now)
    #expect(ev.actualDurationMinutes == 0)
}

@Test func justAfterMidnightOvernightEvent() {
    // 23:55 → 00:05 = 10 minutes, not -1430 or 0.
    let ev = ActualEvent(startMinutes: 23 * 60 + 55, endMinutes: 5, date: .now)
    #expect(ev.actualDurationMinutes == 10)
}

// MARK: - REGRESSION: planNowMinutes cross-midnight anchoring

@Test func planNowMinutesOnPlanDayIsWallClock() {
    let cal = Calendar.current
    let planDay = cal.startOfDay(for: .now)
    // 14:30 on the plan's own day → 870 wall-clock minutes.
    let now = cal.date(byAdding: .minute, value: 14 * 60 + 30, to: planDay)!
    #expect(DisruptionService.planNowMinutes(now, planDay: planDay) == 14 * 60 + 30)
}

@Test func planNowMinutesAfterMidnightReturnsEndOfDay() {
    let cal = Calendar.current
    let planDay = cal.startOfDay(for: .now)
    // "now" is the next calendar day → whole plan is behind us → 1440.
    let nextDay = cal.date(byAdding: .day, value: 1, to: planDay)!
    let nowNextMorning = cal.date(byAdding: .minute, value: 8 * 60, to: nextDay)!
    #expect(DisruptionService.planNowMinutes(nowNextMorning, planDay: planDay) == 1440)
}

@Test func planNowMinutesBeforePlanDayReturnsZero() {
    let cal = Calendar.current
    let planDay = cal.startOfDay(for: .now)
    let dayBefore = cal.date(byAdding: .day, value: -1, to: planDay)!
    let nowBefore = cal.date(byAdding: .minute, value: 20 * 60, to: dayBefore)!
    #expect(DisruptionService.planNowMinutes(nowBefore, planDay: planDay) == 0)
}

// MARK: - wall-clock formatting (DST-safe minute arithmetic, no Date math)

@Test func entryFormatProducesZeroPaddedClock() {
    #expect(DailyTimeline.Entry.format(0) == "00:00")
    #expect(DailyTimeline.Entry.format(7 * 60) == "07:00")
    #expect(DailyTimeline.Entry.format(14 * 60 + 30) == "14:30")
    #expect(DailyTimeline.Entry.format(23 * 60 + 59) == "23:59")
}

@Test func entryFormatWrapsAroundMidnightSafely() {
    // 1440 (24:00) wraps to 00:00; negatives wrap into range; >24h folds back.
    #expect(DailyTimeline.Entry.format(24 * 60) == "00:00")
    #expect(DailyTimeline.Entry.format(25 * 60) == "01:00")
    #expect(DailyTimeline.Entry.format(-60) == "23:00")
}

@Test func minutesFromClockParsesPlainAndRange() {
    #expect(DailyTimeline.minutes(from: "07:00") == 420)
    #expect(DailyTimeline.minutes(from: "9:05") == 545)
    #expect(DailyTimeline.minutes(from: "09:00–17:00") == 540) // takes leading token
    #expect(DailyTimeline.minutes(from: "") == nil)
    #expect(DailyTimeline.minutes(from: "anytime") == nil)
    #expect(DailyTimeline.minutes(from: "25:00") == nil) // out of range hour
}

// MARK: - format/parse round-trip across the whole day (wall-clock stability)

@Test func formatParseRoundTripEveryQuarterHour() {
    for m in stride(from: 0, to: 24 * 60, by: 15) {
        let clock = DailyTimeline.Entry.format(m)
        #expect(DailyTimeline.minutes(from: clock) == m, "round-trip failed at \(m)")
    }
}
