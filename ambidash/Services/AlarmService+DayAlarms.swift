// ambidash/Services/AlarmService+DayAlarms.swift
//
// v5 DAY ALARMS — dedicated recurring WAKE and BEDTIME alarms (iOS-only).
//
// Distinct from the per-block timeline alarms in AlarmService.swift: those fire ONCE at a
// single block's start; these are RECURRING daily alarms anchored to the user's wake/sleep
// rhythm (UserPreferences.wakeTime / .sleepTime). Same calm contract:
//  • Wake defaults to an UNMISSABLE alarm — AlarmKit `.relative` recurring on iOS 26 (overrides
//    Silent + Focus, system Stop/Snooze), degrading pre-26 to a recurring `.timeSensitive`
//    reminder clearly LABELLED as a reminder (never dressed up as a system alarm).
//  • Bedtime defaults to a GENTLE `.passive` wind-down nudge — a calm invitation, not a buzz.
//  • Everything is OFF until the user opts in (the prefs default to disabled).
//
// The decision of WHAT to schedule is factored into pure functions (`dayAlarmDirectives`,
// `dayAlarmStatuses`) so it's unit-testable with zero scheduling side effects; the `reconcile`
// path applies those directives to UNUserNotificationCenter / AlarmManager. Ids are fixed per
// kind so a reschedule/cancel is always idempotent without a persisted side table.
import Foundation
import UserNotifications
#if canImport(AlarmKit)
import AlarmKit
#endif

extension AlarmService {

    // MARK: - Kinds

    /// The two recurring day alarms. Wake follows the day's plan when synced; bedtime is a
    /// fixed wind-down anchor.
    enum DayAlarmKind: String, CaseIterable {
        case wake
        case bedtime

        /// Fixed UNNotification id so a reschedule cleanly replaces the prior request.
        var notificationID: String { "day-alarm-\(rawValue)" }

        /// Stable, deterministic AlarmKit id per kind so a reschedule/cancel always targets
        /// the same alarm without persisting a side table.
        var alarmUUID: UUID {
            switch self {
            case .wake:    return UUID(uuidString: "A1A11111-DA17-4A1A-8A1A-D4A1A12A0001")!
            case .bedtime: return UUID(uuidString: "B2B22222-DA17-4B2B-8B2B-D4B2B22A0002")!
            }
        }

        var title: String {
            switch self {
            case .wake:    return "Wake up"
            case .bedtime: return "Wind down for bed"
            }
        }

        var body: String {
            switch self {
            case .wake:    return "Good morning — your day is ready when you are."
            case .bedtime: return "Time to wind down. Tomorrow starts with a good night's sleep."
            }
        }

        /// Wake defaults to an unmissable alarm; bedtime to a gentle nudge.
        var defaultMode: PlannedAction.AlarmMode { self == .wake ? .alarm : .gentle }

        var tintIsWarm: Bool { self == .wake }
    }

    // MARK: - Pure decision model

    /// A resolved instruction for ONE day alarm. `mode == .off` means "cancel / schedule
    /// nothing". Derived purely from preferences (+ an optional plan wake minute) so it can be
    /// asserted in tests with no side effects.
    struct DayAlarmDirective: Equatable {
        let kind: DayAlarmKind
        let mode: PlannedAction.AlarmMode
        let hour: Int
        let minute: Int
        /// True when the wake alarm's time came from the live plan rather than the static
        /// `wakeTime` preference (display-only).
        let syncedToPlan: Bool

        var minutesOfDay: Int { hour * 60 + minute }
        var clock: String { DailyTimeline.Entry.format(minutesOfDay) }
    }

    /// PURE: resolve both day-alarm directives from raw preference values. The wake time comes
    /// from the live plan (`planWakeMinutes`) when `syncWakeToPlan` is on and a plan time is
    /// available; otherwise from the static `wakeClock`. Bedtime is never plan-synced. A clock
    /// that can't be parsed, or a disabled alarm, resolves to `.off` (nothing scheduled) rather
    /// than crashing.
    static func dayAlarmDirectives(
        wakeEnabled: Bool, wakeModeRaw: String, wakeClock: String,
        bedtimeEnabled: Bool, bedtimeModeRaw: String, bedtimeClock: String,
        syncWakeToPlan: Bool, planWakeMinutes: Int?
    ) -> [DayAlarmDirective] {
        let wakeSynced = syncWakeToPlan && planWakeMinutes != nil
        let wakeMinutes = wakeSynced ? planWakeMinutes : DailyTimeline.minutes(from: wakeClock)

        return [
            directive(kind: .wake, enabled: wakeEnabled, modeRaw: wakeModeRaw,
                      minutes: wakeMinutes, synced: wakeSynced),
            directive(kind: .bedtime, enabled: bedtimeEnabled, modeRaw: bedtimeModeRaw,
                      minutes: DailyTimeline.minutes(from: bedtimeClock), synced: false),
        ]
    }

    private static func directive(
        kind: DayAlarmKind, enabled: Bool, modeRaw: String, minutes: Int?, synced: Bool
    ) -> DayAlarmDirective {
        // A disabled alarm or an unparseable clock means "schedule nothing".
        guard enabled, let minutes, (0..<(24 * 60)).contains(minutes) else {
            return DayAlarmDirective(kind: kind, mode: .off, hour: 0, minute: 0, syncedToPlan: false)
        }
        let mode = PlannedAction.AlarmMode(rawValue: modeRaw) ?? kind.defaultMode
        return DayAlarmDirective(
            kind: kind, mode: mode,
            hour: minutes / 60, minute: minutes % 60,
            syncedToPlan: synced
        )
    }

    /// PURE: the subset of directives that are actually live (mode != .off), for the dashboard
    /// status surface. Order is wake-then-bedtime.
    static func dayAlarmStatuses(
        wakeEnabled: Bool, wakeModeRaw: String, wakeClock: String,
        bedtimeEnabled: Bool, bedtimeModeRaw: String, bedtimeClock: String,
        syncWakeToPlan: Bool, planWakeMinutes: Int?
    ) -> [DayAlarmDirective] {
        dayAlarmDirectives(
            wakeEnabled: wakeEnabled, wakeModeRaw: wakeModeRaw, wakeClock: wakeClock,
            bedtimeEnabled: bedtimeEnabled, bedtimeModeRaw: bedtimeModeRaw, bedtimeClock: bedtimeClock,
            syncWakeToPlan: syncWakeToPlan, planWakeMinutes: planWakeMinutes
        ).filter { $0.mode != .off }
    }

    // MARK: - Reconcile (apply directives — side effects)

    /// Reconcile both day alarms from a `UserPreferences`. Idempotent: each kind is cancelled
    /// then (re)scheduled per its resolved directive. `planWakeMinutes` is the day's first
    /// scheduled block minute-of-day, used only when the user opted into plan-sync.
    static func reconcileDayAlarms(prefs: UserPreferences, planWakeMinutes: Int? = nil) {
        let directives = dayAlarmDirectives(
            wakeEnabled: prefs.wakeAlarmEnabled, wakeModeRaw: prefs.wakeAlarmModeRaw, wakeClock: prefs.wakeTime,
            bedtimeEnabled: prefs.bedtimeAlarmEnabled, bedtimeModeRaw: prefs.bedtimeAlarmModeRaw, bedtimeClock: prefs.sleepTime,
            syncWakeToPlan: prefs.syncWakeAlarmToPlan, planWakeMinutes: planWakeMinutes
        )
        for directive in directives { apply(directive) }
    }

    private static func apply(_ directive: DayAlarmDirective) {
        // Always clear the prior surface first so a re-schedule never doubles up.
        cancelDayAlarm(directive.kind)
        switch directive.mode {
        case .off:
            return
        case .gentle:
            scheduleRecurringGentle(kind: directive.kind, hour: directive.hour, minute: directive.minute)
        case .alarm:
            scheduleRecurringHard(kind: directive.kind, hour: directive.hour, minute: directive.minute)
        }
    }

    /// Cancel both the UNNotification reminder AND any AlarmKit alarm for a day-alarm kind.
    static func cancelDayAlarm(_ kind: DayAlarmKind) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [kind.notificationID])
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            try? AlarmManager.shared.cancel(id: kind.alarmUUID)
        }
        #endif
    }

    /// Cancel every day alarm (e.g. the user turned the whole feature off, or on sign-out).
    static func cancelAllDayAlarms() {
        for kind in DayAlarmKind.allCases { cancelDayAlarm(kind) }
    }

    // MARK: - Gentle recurring path (UNCalendar repeats)

    private static func scheduleRecurringGentle(kind: DayAlarmKind, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = kind.body
        content.sound = .default
        // Wake stays `.active` so it surfaces promptly; bedtime is `.passive` — a calm,
        // non-intrusive wind-down, never a buzz.
        content.interruptionLevel = kind == .wake ? .active : .passive
        content.userInfo = ["deepLink": DeepLink.today.rawValue, "dayAlarm": kind.rawValue]

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: kind.notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Hard alarm recurring path (AlarmKit iOS 26 / time-sensitive fallback)

    private static func scheduleRecurringHard(kind: DayAlarmKind, hour: Int, minute: Int) {
        #if canImport(AlarmKit)
        if #available(iOS 26.1, *) {
            Task { await scheduleRecurringAlarmKit(kind: kind, hour: hour, minute: minute) }
            return
        }
        #endif
        scheduleRecurringTimeSensitiveFallback(kind: kind, hour: hour, minute: minute)
    }

    /// Pre-26 fallback: a RECURRING `.timeSensitive` notification at the alarm time, labelled
    /// honestly as a reminder. `.timeSensitive` pierces Focus but not Silent — honest about
    /// what it is. Uses the same fixed id so it replaces cleanly.
    private static func scheduleRecurringTimeSensitiveFallback(kind: DayAlarmKind, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Reminder: \(kind.title)"
        content.body = "\(kind.body) (This is a reminder, not a system alarm.)"
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = ["deepLink": DeepLink.today.rawValue, "dayAlarm": kind.rawValue]

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: kind.notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    #if canImport(AlarmKit)
    /// Schedule a genuine RECURRING AlarmKit alarm at the given clock time, every day. Requests
    /// authorization lazily; if declined or scheduling fails, degrades to the time-sensitive
    /// reminder so the opt-in still does something rather than silently failing.
    @available(iOS 26.1, *)
    private static func scheduleRecurringAlarmKit(kind: DayAlarmKind, hour: Int, minute: Int) async {
        let manager = AlarmManager.shared
        let authorized: Bool
        switch manager.authorizationState {
        case .authorized:
            authorized = true
        case .denied:
            authorized = false
        default:
            authorized = (try? await manager.requestAuthorization()) == .authorized
        }
        guard authorized else {
            scheduleRecurringTimeSensitiveFallback(kind: kind, hour: hour, minute: minute)
            return
        }

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: kind.title),
            secondaryButton: AlarmButton(text: "Snooze", textColor: .white, systemImageName: "zzz"),
            secondaryButtonBehavior: .countdown
        )
        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: kind.title),
            pauseButton: nil
        )
        let presentation = AlarmPresentation(alert: alert, countdown: countdown)
        let attributes = AlarmAttributes(
            presentation: presentation,
            metadata: BlockAlarmMetadata(blockTitle: kind.title),
            tintColor: kind.tintIsWarm ? .orange : .indigo
        )
        // A 9-minute snooze countdown if the user taps Snooze.
        let countdownDuration = Alarm.CountdownDuration(preAlert: nil, postAlert: 9 * 60)

        // RECURRING: fire at this clock time every day of the week, in the device time zone.
        let schedule: Alarm.Schedule = .relative(.init(
            time: .init(hour: hour, minute: minute),
            repeats: .weekly([.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday])
        ))
        let id = kind.alarmUUID
        let config = AlarmManager.AlarmConfiguration(
            countdownDuration: countdownDuration,
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopBlockAlarmIntent(alarmID: id.uuidString),
            secondaryIntent: SnoozeBlockAlarmIntent(alarmID: id.uuidString),
            sound: .default
        )

        do {
            _ = try await manager.schedule(id: id, configuration: config)
        } catch {
            scheduleRecurringTimeSensitiveFallback(kind: kind, hour: hour, minute: minute)
        }
    }
    #endif

    // MARK: - Plan wake helper

    /// The minute-of-day of the EARLIEST scheduled block in a set of actions — the day's
    /// effective wake-to-action moment. Used as the plan-sync source for the wake alarm so the
    /// alarm follows the actual plan instead of a static preference. Nil when nothing is
    /// scheduled (callers then fall back to the static `wakeTime`).
    static func planWakeMinutes(for actions: [PlannedAction]) -> Int? {
        actions
            .compactMap { DailyTimeline.minutes(from: $0.timeSlot) }
            .min()
    }
}
