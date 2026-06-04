import Testing
import Foundation
@testable import ambidash

// v5 feat/v5-alarm-connect — unit tests for the PURE day-alarm decision logic in
// AlarmService+DayAlarms. The scheduling itself (UNUserNotificationCenter / AlarmKit) is a
// side effect we don't exercise here; these assert that the right DIRECTIVE is produced for a
// given set of preferences, which is where all the branching lives.

private typealias Directive = AlarmService.DayAlarmDirective

private func directives(
    wakeEnabled: Bool = false, wakeMode: String = "alarm", wakeClock: String = "07:00",
    bedtimeEnabled: Bool = false, bedtimeMode: String = "gentle", bedtimeClock: String = "23:30",
    sync: Bool = false, planWake: Int? = nil
) -> [Directive] {
    AlarmService.dayAlarmDirectives(
        wakeEnabled: wakeEnabled, wakeModeRaw: wakeMode, wakeClock: wakeClock,
        bedtimeEnabled: bedtimeEnabled, bedtimeModeRaw: bedtimeMode, bedtimeClock: bedtimeClock,
        syncWakeToPlan: sync, planWakeMinutes: planWake
    )
}

private func wake(_ ds: [Directive]) -> Directive { ds.first { $0.kind == .wake }! }
private func bedtime(_ ds: [Directive]) -> Directive { ds.first { $0.kind == .bedtime }! }

@Test func disabledAlarmsResolveToOff() {
    let ds = directives(wakeEnabled: false, bedtimeEnabled: false)
    #expect(wake(ds).mode == .off)
    #expect(bedtime(ds).mode == .off)
}

@Test func enabledWakeAlarmUsesStaticTimeWhenNotSynced() {
    let d = wake(directives(wakeEnabled: true, wakeMode: "alarm", wakeClock: "07:00", sync: false))
    #expect(d.mode == .alarm)
    #expect(d.hour == 7)
    #expect(d.minute == 0)
    #expect(d.syncedToPlan == false)
    #expect(d.clock == "07:00")
}

@Test func wakeAlarmSyncsToPlanWhenEnabledAndPlanTimeAvailable() {
    // Plan's first block at 06:30 (390 min) should override the static 07:00 wakeClock.
    let d = wake(directives(wakeEnabled: true, wakeClock: "07:00", sync: true, planWake: 390))
    #expect(d.hour == 6)
    #expect(d.minute == 30)
    #expect(d.syncedToPlan == true)
}

@Test func wakeAlarmFallsBackToStaticWhenSyncOnButNoPlanTime() {
    let d = wake(directives(wakeEnabled: true, wakeClock: "07:15", sync: true, planWake: nil))
    #expect(d.hour == 7)
    #expect(d.minute == 15)
    #expect(d.syncedToPlan == false)
}

@Test func bedtimeIsNeverPlanSynced() {
    // Even with sync on and a plan time, bedtime stays on its static sleepTime.
    let d = bedtime(directives(bedtimeEnabled: true, bedtimeClock: "23:30", sync: true, planWake: 390))
    #expect(d.hour == 23)
    #expect(d.minute == 30)
    #expect(d.syncedToPlan == false)
    #expect(d.mode == .gentle)
}

@Test func unparseableClockResolvesToOffNotCrash() {
    let d = wake(directives(wakeEnabled: true, wakeClock: "not a time", sync: false))
    #expect(d.mode == .off)
}

@Test func enabledButModeOffResolvesToOff() {
    // The master switch is on, but the user set the mode itself to "off" → schedule nothing.
    let d = wake(directives(wakeEnabled: true, wakeMode: "off"))
    #expect(d.mode == .off)
}

@Test func unknownModeRawFallsBackToKindDefault() {
    // Garbage mode string → the kind's sensible default (wake = alarm, bedtime = gentle).
    let w = wake(directives(wakeEnabled: true, wakeMode: "garbage"))
    #expect(w.mode == .alarm)
    let b = bedtime(directives(bedtimeEnabled: true, bedtimeMode: "garbage"))
    #expect(b.mode == .gentle)
}

@Test func statusesFilterOutOffAlarms() {
    // Only wake enabled → exactly one live status, and it's the wake one.
    let statuses = AlarmService.dayAlarmStatuses(
        wakeEnabled: true, wakeModeRaw: "alarm", wakeClock: "06:45",
        bedtimeEnabled: false, bedtimeModeRaw: "gentle", bedtimeClock: "23:30",
        syncWakeToPlan: false, planWakeMinutes: nil
    )
    #expect(statuses.count == 1)
    #expect(statuses.first?.kind == .wake)
    #expect(statuses.first?.clock == "06:45")
}

@Test func planWakeMinutesPicksEarliestScheduledBlock() {
    let actions = [
        PlannedAction(title: "Deep work", timeSlot: "09:00"),
        PlannedAction(title: "Stretch", timeSlot: "06:30"),
        PlannedAction(title: "Lunch", timeSlot: "13:00"),
    ]
    #expect(AlarmService.planWakeMinutes(for: actions) == 6 * 60 + 30)
}

@Test func planWakeMinutesIsNilWhenNothingScheduled() {
    #expect(AlarmService.planWakeMinutes(for: []) == nil)
    // Actions with no parseable time slot also yield nil.
    let untimed = [PlannedAction(title: "Someday", timeSlot: "")]
    #expect(AlarmService.planWakeMinutes(for: untimed) == nil)
}

@Test func dayAlarmKindIdentifiersAreStableAndDistinct() {
    #expect(AlarmService.DayAlarmKind.wake.notificationID == "day-alarm-wake")
    #expect(AlarmService.DayAlarmKind.bedtime.notificationID == "day-alarm-bedtime")
    #expect(AlarmService.DayAlarmKind.wake.alarmUUID != AlarmService.DayAlarmKind.bedtime.alarmUUID)
    #expect(AlarmService.DayAlarmKind.wake.defaultMode == .alarm)
    #expect(AlarmService.DayAlarmKind.bedtime.defaultMode == .gentle)
}
