// ambidash-monitor/DeviceActivityMonitorExtension.swift
//
// v5 feat/v5-app-restrictions — the DeviceActivity monitor that actually applies shields when a
// scheduled restriction window opens or a per-app daily budget is spent. It runs in a SEPARATE
// process from the app, so it reads everything it needs (the shared shield selection, the window
// configs, per-budget selections, and any active override) from the shared App Group container
// that AppLimitController writes. Keys here mirror AppLimitController.AGKey exactly.
import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

class AmbidashDeviceActivityMonitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore()

    private let appGroup = "group.com.ambidash.app"
    private var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    private enum Key {
        static let sharedSelection = "applimits.ag.sharedSelection"
        static let windowConfigs = "applimits.ag.windowConfigs"
        static let budgetSelectionPrefix = "applimits.ag.budgetSel."
        static let overrideUntil = "applimits.ag.overrideUntil"
        static let focusEndsAt = "applimits.ag.focusEndsAt"
    }

    /// Mirrors AppLimitController.WindowConfig (separate target → redeclared to decode the JSON).
    private struct WindowConfig: Codable {
        let id: String
        let startMinute: Int
        let endMinute: Int
        let weekdayMask: Int
        let isEnabled: Bool
    }

    // MARK: - Interval lifecycle

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard !isOverrideActive() else { return }
        let raw = activity.rawValue
        if raw.hasPrefix("window.") {
            let id = String(raw.dropFirst("window.".count))
            guard windowActiveToday(id: id) else { return }
            shieldShared()
        } else if raw == "focus.session" {
            shieldShared()
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        let raw = activity.rawValue
        if raw.hasPrefix("window.") || raw == "focus.session" {
            // The window/session closed — clear the shield. An overlapping window that's still
            // active re-applies via its own intervalDidStart.
            clearShield()
            if raw == "focus.session" { defaults?.removeObject(forKey: Key.focusEndsAt) }
        }
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        guard !isOverrideActive() else { return }
        let raw = event.rawValue
        if raw.hasPrefix("budget.") {
            let id = String(raw.dropFirst("budget.".count))
            shieldBudget(id: id)
        }
    }

    // MARK: - Shield helpers

    private func shieldShared() {
        guard let data = defaults?.data(forKey: Key.sharedSelection),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        store.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
    }

    /// Add a budget's apps to the shield (merging, so it doesn't wipe an active window shield).
    private func shieldBudget(id: String) {
        guard let data = defaults?.data(forKey: Key.budgetSelectionPrefix + id),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return }
        var apps = store.shield.applications ?? Set<ApplicationToken>()
        apps.formUnion(sel.applicationTokens)
        store.shield.applications = apps.isEmpty ? nil : apps
        if !sel.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(sel.categoryTokens)
        }
    }

    private func clearShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }

    // MARK: - Gating

    private func isOverrideActive() -> Bool {
        guard let until = defaults?.double(forKey: Key.overrideUntil), until > 0 else { return false }
        return Date().timeIntervalSince1970 < until
    }

    /// The DeviceActivitySchedule already gates the time-of-day range; this adds the weekday
    /// filtering (and re-checks enablement), matching the app's RestrictionSchedule.isActive.
    private func windowActiveToday(id: String) -> Bool {
        guard let data = defaults?.data(forKey: Key.windowConfigs),
              let configs = try? JSONDecoder().decode([WindowConfig].self, from: data),
              let cfg = configs.first(where: { $0.id == id }), cfg.isEnabled else { return false }
        let comps = Calendar.current.dateComponents([.hour, .minute, .weekday], from: Date())
        let minute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let weekday = (comps.weekday ?? 1) - 1
        let prevWeekday = (weekday + 6) % 7
        if cfg.startMinute < cfg.endMinute {
            return cfg.weekdayMask & (1 << weekday) != 0
        } else {
            let evening = (cfg.weekdayMask & (1 << weekday) != 0) && minute >= cfg.startMinute
            let morning = (cfg.weekdayMask & (1 << prevWeekday) != 0) && minute < cfg.endMinute
            return evening || morning
        }
    }
}
