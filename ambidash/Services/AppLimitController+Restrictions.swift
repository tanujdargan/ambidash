// ambidash/Services/AppLimitController+Restrictions.swift
//
// v5 feat/v5-app-restrictions — extends the manual all-or-nothing shield (AppLimitController)
// with scheduled restriction windows, per-app daily budgets, timed focus sessions, and a
// temporary override. All of this is DEVICE-ONLY (Family Controls + DeviceActivity don't run on
// the Simulator), so every entry point degrades to a safe no-op off-device.
//
// Cross-process contract: the DeviceActivity MONITOR extension runs separately and can't see the
// app's state, so the app writes everything the monitor needs — the shared shield selection, the
// per-window schedule config, the per-budget selection, and any active override window — into the
// shared App Group container. Keys are namespaced under `applimits.*` and mirrored in the
// monitor extension.
import Foundation
#if os(iOS)
import FamilyControls
import ManagedSettings
import DeviceActivity
#endif

extension AppLimitController {

    /// Shared App Group used to hand restriction config to the monitor extension.
    static let appGroup = "group.com.ambidash.app"

    // App Group keys (kept in one place; mirrored by the monitor extension).
    enum AGKey {
        static let sharedSelection = "applimits.ag.sharedSelection"   // Data: FamilyActivitySelection for windows
        static let windowConfigs = "applimits.ag.windowConfigs"       // Data: [WindowConfig]
        static let budgetSelectionPrefix = "applimits.ag.budgetSel."  // + budgetID → Data selection
        static let overrideUntil = "applimits.ag.overrideUntil"       // Double: timeIntervalSince1970, shields paused until then
        static let focusEndsAt = "applimits.ag.focusEndsAt"           // Double: timeIntervalSince1970 of active focus session
    }

    /// A lightweight, Codable mirror of a RestrictionWindow that the monitor can read to decide,
    /// on interval start, whether today's weekday is in scope before shielding.
    struct WindowConfig: Codable, Equatable {
        let id: String
        let startMinute: Int
        let endMinute: Int
        let weekdayMask: Int
        let isEnabled: Bool
    }

    private var defaults: UserDefaults? { UserDefaults(suiteName: Self.appGroup) }

    // MARK: - Schedule registration

    /// Reconcile DeviceActivity monitoring to the given windows + budgets. Writes the config the
    /// monitor needs into the App Group, then (re)starts monitoring. Idempotent: it stops all of
    /// our prior activities first. Safe no-op off-device.
    func applySchedules(windows: [RestrictionWindow], budgets: [AppBudget]) {
        #if os(iOS)
        guard authState == .approved else { return }

        // 1. Hand the monitor the shared shield selection + the window configs.
        if let selData = try? JSONEncoder().encode(selection) {
            defaults?.set(selData, forKey: AGKey.sharedSelection)
        }
        let configs = windows.map {
            WindowConfig(id: $0.id.uuidString, startMinute: $0.startMinute, endMinute: $0.endMinute,
                         weekdayMask: $0.weekdayMask, isEnabled: $0.isEnabled)
        }
        if let cfgData = try? JSONEncoder().encode(configs) {
            defaults?.set(cfgData, forKey: AGKey.windowConfigs)
        }

        let center = DeviceActivityCenter()
        center.stopMonitoring()

        // 2. One daily schedule per enabled window (weekday filtering happens in the monitor,
        // which consults WindowConfig — DeviceActivitySchedule itself repeats daily).
        for window in windows where window.isEnabled {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: window.startMinute / 60, minute: window.startMinute % 60),
                intervalEnd: DateComponents(hour: window.endMinute / 60, minute: window.endMinute % 60),
                repeats: true
            )
            let name = DeviceActivityName("window.\(window.id.uuidString)")
            try? center.startMonitoring(name, during: schedule)
        }

        // 3. Per-app budgets: a full-day schedule with a usage-threshold event. The monitor's
        // eventDidReachThreshold shields that budget's apps once the daily allowance is spent.
        for budget in budgets where budget.isEnabled {
            guard let selData = budget.selectionData,
                  let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: selData),
                  !sel.applicationTokens.isEmpty || !sel.categoryTokens.isEmpty else { continue }

            defaults?.set(selData, forKey: AGKey.budgetSelectionPrefix + budget.id.uuidString)

            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59),
                repeats: true
            )
            let event = DeviceActivityEvent(
                applications: sel.applicationTokens,
                categories: sel.categoryTokens,
                threshold: DateComponents(minute: max(1, budget.dailyMinutes))
            )
            let name = DeviceActivityName("budget.\(budget.id.uuidString)")
            let eventName = DeviceActivityEvent.Name("budget.\(budget.id.uuidString)")
            try? center.startMonitoring(name, during: schedule, events: [eventName: event])
        }
        #endif
    }

    /// Stop all of our DeviceActivity monitoring and clear handed-off config.
    func clearAllSchedules() {
        #if os(iOS)
        DeviceActivityCenter().stopMonitoring()
        defaults?.removeObject(forKey: AGKey.windowConfigs)
        #endif
    }

    // MARK: - Focus session (immediate timed block)

    /// Whether a timed focus session is currently shielding.
    var isFocusSessionActive: Bool {
        guard let ends = defaults?.double(forKey: AGKey.focusEndsAt), ends > 0 else { return false }
        return Date.now.timeIntervalSince1970 < ends
    }

    var focusSessionEndsAt: Date? {
        guard let ends = defaults?.double(forKey: AGKey.focusEndsAt), ends > Date.now.timeIntervalSince1970 else { return nil }
        return Date(timeIntervalSince1970: ends)
    }

    /// Start an immediate focus session: shield the shared selection now and auto-lift after
    /// `minutes`. Uses a one-off DeviceActivitySchedule so the lift survives app backgrounding.
    func startFocusSession(minutes: Int) {
        #if os(iOS)
        guard authState == .approved, blockedCount > 0, minutes > 0 else { return }
        let endsAt = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        defaults?.set(endsAt.timeIntervalSince1970, forKey: AGKey.focusEndsAt)
        startBlocking()

        let cal = Calendar.current
        let start = cal.dateComponents([.hour, .minute], from: .now)
        let end = cal.dateComponents([.hour, .minute], from: endsAt)
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: false)
        try? DeviceActivityCenter().startMonitoring(DeviceActivityName("focus.session"), during: schedule)
        #endif
    }

    /// End a focus session early.
    func endFocusSession() {
        #if os(iOS)
        defaults?.removeObject(forKey: AGKey.focusEndsAt)
        DeviceActivityCenter().stopMonitoring([DeviceActivityName("focus.session")])
        stopBlocking()
        #endif
    }

    // MARK: - Override

    /// Temporarily lift the shield for `minutes`, recording that the monitor should not re-shield
    /// until then. The caller logs a RestrictionOverride (with the user's reason) to SwiftData;
    /// this just suspends the device-side shield. Returns the moment the override expires.
    @discardableResult
    func liftShieldTemporarily(minutes: Int) -> Date {
        let until = Date.now.addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        #if os(iOS)
        defaults?.set(until.timeIntervalSince1970, forKey: AGKey.overrideUntil)
        // Lift the live shield now; the monitor honors `overrideUntil` on its next interval and
        // won't re-shield until it passes. `stopBlocking()` clears the live shield surfaces.
        stopBlocking()
        #endif
        return until
    }
}
