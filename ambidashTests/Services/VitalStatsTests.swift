import Testing
import Foundation
@testable import ambidash

// v5 feat/v5-custom-vitals — tests for the PURE vital statistics (today total, progress, weekly
// average, days logged, current streak, sparkline) and the category defaults. Persistence is via
// SwiftData @Models exercised by the app; the math lives here.

private let cal = Calendar(identifier: .gregorian)
private func day(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}
private func pt(_ value: Double, _ date: Date) -> VitalStats.Point { .init(value: value, date: date) }

// MARK: - Category defaults

@Test func categoryDefaultsAreSensible() {
    #expect(VitalCategory.sleep.defaultUnit == "hrs")
    #expect(VitalCategory.sleep.defaultTarget == 8)
    #expect(!VitalCategory.hydration.defaultIcon.isEmpty)
    #expect(VitalCategory.custom.defaultTarget == 0)
    #expect(VitalCategory.allCases.count == 8)
}

// MARK: - Summary

@Test func summaryIsEmptyWithNoEntries() {
    let s = VitalStats.summary(entries: [], target: 8)
    #expect(s.todayTotal == 0)
    #expect(s.latest == nil)
    #expect(s.weekAverage == nil)
    #expect(s.progress == 0)
    #expect(s.currentStreak == 0)
}

@Test func summarySumsTodayAndComputesProgress() {
    let now = day(2024, 6, 10, 18)
    let entries = [
        pt(3, day(2024, 6, 10, 9)),
        pt(2, day(2024, 6, 10, 14)),
        pt(5, day(2024, 6, 9, 10)), // yesterday — not in today's total
    ]
    let s = VitalStats.summary(entries: entries, target: 8, now: now, calendar: cal)
    #expect(s.todayTotal == 5)
    #expect(s.progress == 5.0 / 8.0)
    #expect(s.progressPercent == 63)
    #expect(s.latest == 2) // most recent by date
}

@Test func summaryProgressClampsAndZeroTargetIsZero() {
    let now = day(2024, 6, 10, 18)
    let over = VitalStats.summary(entries: [pt(12, day(2024, 6, 10, 9))], target: 8, now: now, calendar: cal)
    #expect(over.progress == 1.0)
    let noTarget = VitalStats.summary(entries: [pt(12, day(2024, 6, 10, 9))], target: 0, now: now, calendar: cal)
    #expect(noTarget.progress == 0)
}

@Test func summaryWeekAverageAndDaysLogged() {
    let now = day(2024, 6, 10, 18)
    let entries = [
        pt(4, day(2024, 6, 10, 9)),
        pt(2, day(2024, 6, 10, 12)), // today total 6
        pt(8, day(2024, 6, 9, 9)),   // day total 8
        pt(10, day(2024, 6, 3, 9)),  // exactly 7 days back (within window of 7 incl today)
    ]
    let s = VitalStats.summary(entries: entries, target: 8, now: now, calendar: cal)
    // Window is today + 6 prior days = back to June 4, so June 3 is excluded.
    #expect(s.daysLoggedThisWeek == 2)        // June 10 and June 9
    #expect(s.weekAverage == (6.0 + 8.0) / 2.0)
}

// MARK: - Streak

@Test func streakCountsConsecutiveDaysEndingToday() {
    let now = day(2024, 6, 10, 18)
    let entries = [
        pt(1, day(2024, 6, 10)), pt(1, day(2024, 6, 9)), pt(1, day(2024, 6, 8)),
    ]
    #expect(VitalStats.currentStreak(entries: entries, now: now, calendar: cal) == 3)
}

@Test func streakBreaksOnGap() {
    let now = day(2024, 6, 10, 18)
    let entries = [pt(1, day(2024, 6, 10)), pt(1, day(2024, 6, 8))] // gap on the 9th
    #expect(VitalStats.currentStreak(entries: entries, now: now, calendar: cal) == 1)
}

@Test func streakGracesTodayNotYetLogged() {
    let now = day(2024, 6, 10, 8)
    let entries = [pt(1, day(2024, 6, 9)), pt(1, day(2024, 6, 8))] // today none, anchor yesterday
    #expect(VitalStats.currentStreak(entries: entries, now: now, calendar: cal) == 2)
}

@Test func streakZeroWhenStale() {
    let now = day(2024, 6, 10, 12)
    let entries = [pt(1, day(2024, 6, 7))] // 3 days ago — not current
    #expect(VitalStats.currentStreak(entries: entries, now: now, calendar: cal) == 0)
}

// MARK: - Sparkline

@Test func dailyTotalsHasFixedLengthAndZeroFillsGaps() {
    let now = day(2024, 6, 10, 18)
    let entries = [pt(3, day(2024, 6, 10)), pt(5, day(2024, 6, 8))]
    let totals = VitalStats.dailyTotals(entries: entries, days: 7, now: now, calendar: cal)
    #expect(totals.count == 7)
    #expect(totals.last == 3)        // today
    #expect(totals[4] == 5)          // June 8 is 2 days before today → index 7-1-2 = 4
    #expect(totals[5] == 0)          // June 9 had nothing
}
