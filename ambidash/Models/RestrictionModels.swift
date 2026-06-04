// ambidash/Models/RestrictionModels.swift
//
// v5 feat/v5-app-restrictions — the persisted configuration for scheduled app restrictions,
// per-app daily budgets, and override logging. These extend the existing manual all-or-nothing
// shield (AppLimitController) into a schedulable, accountable system.
//
// CloudKit-safe: every scalar carries a default, no relationships, so each type is additive to
// the synced schema with no migration. The app-token SELECTION data inside a budget is device-
// local (ApplicationTokens are only valid on the device that picked them) — it syncs as opaque
// bytes that simply won't resolve on another device, the same honest caveat the manual selection
// already carries.
import Foundation
import SwiftData

/// A scheduled restriction window — e.g. "block social media 09:00–17:00 on weekdays". While a
/// window is active, the shared AppLimitController selection is shielded automatically by the
/// DeviceActivity monitor. Times are minute-of-day; `weekdayMask` is a 7-bit set (see
/// `RestrictionSchedule`).
@Model
final class RestrictionWindow {
    var id: UUID = UUID()
    var name: String = ""
    /// Minute-of-day the window opens (0–1439). Default 09:00.
    var startMinute: Int = 540
    /// Minute-of-day the window closes (0–1439). Default 17:00. A window whose end is <= start
    /// is treated as crossing midnight (e.g. 22:00–06:00).
    var endMinute: Int = 1020
    /// 7-bit weekday set: bit i (0 = Sunday … 6 = Saturday). Default Mon–Fri.
    var weekdayMask: Int = 0b0111110
    var isEnabled: Bool = true
    var createdAt: Date = Date.now

    init(name: String = "", startMinute: Int = 540, endMinute: Int = 1020,
         weekdayMask: Int = 0b0111110, isEnabled: Bool = true) {
        self.id = UUID()
        self.name = name
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.weekdayMask = weekdayMask
        self.isEnabled = isEnabled
        self.createdAt = .now
    }
}

/// A per-app (or per-category) daily time budget — e.g. "30 min of Instagram/day". The
/// DeviceActivity monitor watches usage of `selectionData`'s apps and shields them once
/// `dailyMinutes` is reached; the budget resets at the start of each day.
@Model
final class AppBudget {
    var id: UUID = UUID()
    var name: String = ""
    /// Daily allowance in minutes before the app(s) are shielded for the rest of the day.
    var dailyMinutes: Int = 30
    /// JSON-encoded FamilyActivitySelection (device-local app/category tokens). Optional so a
    /// freshly-created budget can exist before the user picks apps.
    var selectionData: Data? = nil
    var isEnabled: Bool = true
    var createdAt: Date = Date.now

    init(name: String = "", dailyMinutes: Int = 30, selectionData: Data? = nil, isEnabled: Bool = true) {
        self.id = UUID()
        self.name = name
        self.dailyMinutes = dailyMinutes
        self.selectionData = selectionData
        self.isEnabled = isEnabled
        self.createdAt = .now
    }
}

/// A logged restriction OVERRIDE — the user chose to lift a shield early, with a reason. Kept
/// non-punitively: the point is honest self-awareness (a weekly report of when/why you reached
/// past your own limits), never shame. `minutesGranted` is how long the override lasted.
@Model
final class RestrictionOverride {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    /// What was overridden — the window/budget name, or "Manual shield".
    var sourceName: String = ""
    /// `window` | `budget` | `manual`.
    var sourceKind: String = "window"
    var reason: String = ""
    var minutesGranted: Int = 0

    init(sourceName: String = "", sourceKind: String = "window", reason: String = "", minutesGranted: Int = 0) {
        self.id = UUID()
        self.timestamp = .now
        self.sourceName = sourceName
        self.sourceKind = sourceKind
        self.reason = reason
        self.minutesGranted = minutesGranted
    }
}
