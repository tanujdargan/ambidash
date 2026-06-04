import Testing
import Foundation
@testable import ambidash

// v5 feat/v5-app-restrictions — unit tests for the PURE restriction scheduling + weekly report
// logic. The DeviceActivity/Family Controls shielding is device-only and not exercised here;
// all the branching (window activity, midnight-crossing, weekday masks, report aggregation)
// lives in RestrictionSchedule and is fully testable.

private let cal = Calendar(identifier: .gregorian)

/// Build a concrete date at a given weekday-in-2024 + time. 2024-01-07 is a Sunday.
private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    var c = DateComponents()
    c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    return cal.date(from: c)!
}

// MARK: - Weekday masks

@Test func weekdayMaskRoundTrips() {
    let m = RestrictionSchedule.mask(from: [1, 3, 5]) // Mon, Wed, Fri
    #expect(RestrictionSchedule.weekdays(from: m) == [1, 3, 5])
    #expect(RestrictionSchedule.contains(m, weekday: 3))
    #expect(!RestrictionSchedule.contains(m, weekday: 2))
    #expect(RestrictionSchedule.activeDayCount(m) == 3)
}

@Test func weekdayMaskConstants() {
    #expect(RestrictionSchedule.activeDayCount(RestrictionSchedule.weekdaysMonFri) == 5)
    #expect(RestrictionSchedule.activeDayCount(RestrictionSchedule.weekendMask) == 2)
    #expect(RestrictionSchedule.activeDayCount(RestrictionSchedule.weekdaysMask) == 7)
}

@Test func weekdayMaskLabels() {
    #expect(RestrictionSchedule.label(for: RestrictionSchedule.weekdaysMask) == "Every day")
    #expect(RestrictionSchedule.label(for: RestrictionSchedule.weekdaysMonFri) == "Weekdays")
    #expect(RestrictionSchedule.label(for: RestrictionSchedule.weekendMask) == "Weekends")
    #expect(RestrictionSchedule.label(for: 0) == "Never")
    #expect(RestrictionSchedule.label(for: RestrictionSchedule.mask(from: [1, 3])) == "Mon, Wed")
}

@Test func weekdayIndexMatchesCalendar() {
    // 2024-01-07 is a Sunday → index 0; 2024-01-10 is a Wednesday → index 3.
    #expect(RestrictionSchedule.weekdayIndex(for: date(2024, 1, 7, 12, 0), calendar: cal) == 0)
    #expect(RestrictionSchedule.weekdayIndex(for: date(2024, 1, 10, 12, 0), calendar: cal) == 3)
}

// MARK: - Duration

@Test func durationSameDay() {
    #expect(RestrictionSchedule.durationMinutes(startMinute: 540, endMinute: 1020) == 480) // 9–17
}

@Test func durationCrossMidnight() {
    // 22:00 (1320) → 06:00 (360) = 8 hours.
    #expect(RestrictionSchedule.durationMinutes(startMinute: 1320, endMinute: 360) == 480)
}

@Test func durationZeroLength() {
    #expect(RestrictionSchedule.durationMinutes(startMinute: 600, endMinute: 600) == 0)
}

// MARK: - Window activity (same-day)

@Test func sameDayWindowActiveInsideRangeOnEnabledWeekday() {
    // Wednesday (2024-01-10) 10:00, window 9–17 Mon–Fri → active.
    let active = RestrictionSchedule.isActive(
        startMinute: 540, endMinute: 1020, weekdayMask: RestrictionSchedule.weekdaysMonFri,
        at: date(2024, 1, 10, 10, 0), calendar: cal
    )
    #expect(active)
}

@Test func sameDayWindowInactiveOutsideRange() {
    let before = RestrictionSchedule.isActive(
        startMinute: 540, endMinute: 1020, weekdayMask: RestrictionSchedule.weekdaysMonFri,
        at: date(2024, 1, 10, 8, 30), calendar: cal
    )
    let after = RestrictionSchedule.isActive(
        startMinute: 540, endMinute: 1020, weekdayMask: RestrictionSchedule.weekdaysMonFri,
        at: date(2024, 1, 10, 17, 0), calendar: cal // end is exclusive
    )
    #expect(!before)
    #expect(!after)
}

@Test func sameDayWindowInactiveOnDisabledWeekday() {
    // Sunday (2024-01-07) 10:00, window Mon–Fri → inactive.
    let active = RestrictionSchedule.isActive(
        startMinute: 540, endMinute: 1020, weekdayMask: RestrictionSchedule.weekdaysMonFri,
        at: date(2024, 1, 7, 10, 0), calendar: cal
    )
    #expect(!active)
}

@Test func disabledFlagShortCircuits() {
    let active = RestrictionSchedule.isActive(
        startMinute: 540, endMinute: 1020, weekdayMask: RestrictionSchedule.weekdaysMask,
        isEnabled: false, at: date(2024, 1, 10, 10, 0), calendar: cal
    )
    #expect(!active)
}

@Test func zeroLengthWindowNeverActive() {
    let active = RestrictionSchedule.isActive(
        startMinute: 600, endMinute: 600, weekdayMask: RestrictionSchedule.weekdaysMask,
        at: date(2024, 1, 10, 10, 0), calendar: cal
    )
    #expect(!active)
}

// MARK: - Window activity (cross-midnight)

@Test func crossMidnightEveningPortionGatedByStartDay() {
    // Window 22:00–06:00 active on Wednesdays. Wed 23:00 → active (evening portion).
    let active = RestrictionSchedule.isActive(
        startMinute: 1320, endMinute: 360, weekdayMask: RestrictionSchedule.mask(from: [3]),
        at: date(2024, 1, 10, 23, 0), calendar: cal
    )
    #expect(active)
}

@Test func crossMidnightMorningPortionGatedByPreviousDay() {
    // Window 22:00–06:00 active on Wednesdays. Thursday 05:00 belongs to Wednesday's window → active.
    let active = RestrictionSchedule.isActive(
        startMinute: 1320, endMinute: 360, weekdayMask: RestrictionSchedule.mask(from: [3]),
        at: date(2024, 1, 11, 5, 0), calendar: cal
    )
    #expect(active)
}

@Test func crossMidnightMorningInactiveWhenPreviousDayNotSet() {
    // Same 22:00–06:00 Wednesdays-only window: Wednesday 05:00 is the TAIL of Tuesday's window,
    // and Tuesday isn't set → inactive.
    let active = RestrictionSchedule.isActive(
        startMinute: 1320, endMinute: 360, weekdayMask: RestrictionSchedule.mask(from: [3]),
        at: date(2024, 1, 10, 5, 0), calendar: cal
    )
    #expect(!active)
}

// MARK: - Weekly report

@Test func reportSumsScheduledMinutesAcrossEnabledWindows() {
    let windows = [
        RestrictionSchedule.WindowSummary(startMinute: 540, endMinute: 1020, weekdayMask: RestrictionSchedule.weekdaysMonFri, isEnabled: true), // 8h × 5 = 2400
        RestrictionSchedule.WindowSummary(startMinute: 1320, endMinute: 360, weekdayMask: RestrictionSchedule.weekendMask, isEnabled: true),     // 8h × 2 = 960
        RestrictionSchedule.WindowSummary(startMinute: 0, endMinute: 60, weekdayMask: RestrictionSchedule.weekdaysMask, isEnabled: false),        // disabled → 0
    ]
    let report = RestrictionSchedule.weeklyReport(windows: windows, enabledBudgetCount: 2, overrides: [], now: date(2024, 2, 1, 12, 0))
    #expect(report.enabledWindowCount == 2)
    #expect(report.enabledBudgetCount == 2)
    #expect(report.scheduledRestrictedMinutesPerWeek == 3360)
    #expect(report.scheduledRestrictedLabel == "56h")
}

@Test func reportCountsOnlyOverridesInLastSevenDays() {
    let now = date(2024, 2, 10, 12, 0)
    let overrides = [
        RestrictionSchedule.OverrideSummary(timestamp: now.addingTimeInterval(-2 * 86400), reason: "Need to message a friend", minutesGranted: 15),
        RestrictionSchedule.OverrideSummary(timestamp: now.addingTimeInterval(-1 * 86400), reason: "Need to message a friend", minutesGranted: 10),
        RestrictionSchedule.OverrideSummary(timestamp: now.addingTimeInterval(-9 * 86400), reason: "Old one", minutesGranted: 99), // outside 7d
    ]
    let report = RestrictionSchedule.weeklyReport(windows: [], enabledBudgetCount: 0, overrides: overrides, now: now)
    #expect(report.overrideCount == 2)
    #expect(report.totalOverrideMinutes == 25)
    #expect(report.overridesByReason["Need to message a friend"] == 2)
    #expect(report.overridesByReason["Old one"] == nil)
    #expect(report.topReason == "Need to message a friend")
}

@Test func reportNormalizesEmptyReason() {
    let now = date(2024, 2, 10, 12, 0)
    let overrides = [
        RestrictionSchedule.OverrideSummary(timestamp: now.addingTimeInterval(-3600), reason: "   ", minutesGranted: 5),
    ]
    let report = RestrictionSchedule.weeklyReport(windows: [], enabledBudgetCount: 0, overrides: overrides, now: now)
    #expect(report.overridesByReason["No reason given"] == 1)
}
