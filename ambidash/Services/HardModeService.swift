// ambidash/Services/HardModeService.swift
import Foundation

/// "TODAY IS HARD" MODE — the pure, per-DAY flag logic. When the user marks today
/// hard, the board softens to a minimal, kind set and copy gentles for the day. It is a
/// per-day marker (compared with `Calendar.isDateInToday`) so it AUTO-EXPIRES when the
/// day rolls over — it can never silently stick across days. Stored as `hardModeDay:
/// Date?` on the already-registered `UserPreferences` → no new @Model, no CloudKit
/// migration. Fully reversible.
///
/// No SwiftUI import → compiles into BOTH targets. Mutates the passed `UserPreferences`
/// in place; the CALLER owns `modelContext.save()`.
enum HardModeService {

    /// Is TODAY currently marked hard? False when unset OR when the stored day is not
    /// today (so a stale flag from a previous day reads as off without any cleanup).
    static func isHardToday(_ prefs: UserPreferences?, calendar: Calendar = .current) -> Bool {
        guard let day = prefs?.hardModeDay else { return false }
        return calendar.isDateInToday(day)
    }

    /// Mark today hard. Caller persists.
    static func markHard(_ prefs: UserPreferences, calendar: Calendar = .current, now: Date = .now) {
        prefs.hardModeDay = calendar.startOfDay(for: now)
    }

    /// Clear today's hard flag (reverse). Caller persists.
    static func clear(_ prefs: UserPreferences) {
        prefs.hardModeDay = nil
    }

    /// Toggle today's hard flag, returning the new state. Caller persists.
    @discardableResult
    static func toggle(_ prefs: UserPreferences, calendar: Calendar = .current, now: Date = .now) -> Bool {
        if isHardToday(prefs, calendar: calendar) {
            clear(prefs)
            return false
        } else {
            markHard(prefs, calendar: calendar, now: now)
            return true
        }
    }

    /// The minimal allow-list of component kinds shown on a hard day. Everything else is
    /// transiently hidden (NOT removed from the persisted board — this is a view-level
    /// filter only). Keeps just: the day's one thing (a collapsed timeline), an energy
    /// check-in, the focus session, and the closing ritual — plus the always-present
    /// capture inbox so a thought is never lost. Score / vitals / streaks / history are
    /// suppressed so a hard day isn't a wall of metrics.
    static let minimalAllowList: Set<ComponentKind> = [
        .dailyTimeline,
        .energyCheckin,
        .focusSession,
        .closingRitual,
        .captureInbox,
        .winsWall,
    ]

    /// Whether `kind` should render on a hard day.
    static func allowsOnHardDay(_ kind: ComponentKind) -> Bool {
        minimalAllowList.contains(kind)
    }

    /// The kind, gentle headline shown atop the board on a hard day.
    static let headline = "Today, just one thing."
    static let subhead = "Hard days are allowed. Pick the smallest next step — or rest. Both count."
}
