import Foundation
import SwiftData

/// v4 wake-adjust workflow: records the actual wake time (minute-of-day) the FIRST
/// time the app is opened each day, so the Wake Check surface can compare it to the
/// user's `wakeTime` target and gently offer to re-adjust when they drift apart.
/// Idempotent per day (guarded on `lastWakeRecordDay`), so re-opening later in the
/// day never overwrites the morning's first-open time.
enum WakeTracker {
    static func recordIfNeeded(_ context: ModelContext) {
        guard let prefs = (try? context.fetch(FetchDescriptor<UserPreferences>()))?.first else { return }
        let cal = Calendar.current
        if let last = prefs.lastWakeRecordDay, cal.isDateInToday(last) { return }
        let now = Date()
        let comps = cal.dateComponents([.hour, .minute], from: now)
        let wakeMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        prefs.lastActualWakeMinutes = wakeMin
        prefs.lastWakeRecordDay = cal.startOfDay(for: now)
        // Maintain a rolling 7-day history for multi-week drift detection.
        prefs.recentWakeMinutes.insert(wakeMin, at: 0)
        if prefs.recentWakeMinutes.count > 7 { prefs.recentWakeMinutes = Array(prefs.recentWakeMinutes.prefix(7)) }
        try? context.save()
    }
}
