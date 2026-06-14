import Foundation

// Phase 0 — persistent "original plan" snapshot for the "I feel better" re-entry.
//
// The disruption engine already snapshots a plan in-memory inside DisruptionDiffSheet
// (so DECLINE can undo). But the notification "I_FEEL_BETTER" action needs to restore
// the ORIGINAL morning plan later in the day — after the app was backgrounded — so the
// snapshot must persist. We store the day's first (generated) plan state as Codable
// ActionSnapshots in UserDefaults, keyed by calendar day. Restoring = DisruptionService
// .revert against this snapshot. Old days are pruned so this never grows.
enum PlanSnapshotService {
    nonisolated(unsafe) static var store: UserDefaults = .standard
    private static let prefix = "planSnapshot."

    private static func key(for date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.startOfDay(for: date)
        return prefix + String(Int(day.timeIntervalSince1970))
    }

    /// Capture the plan's current state as THE original for its day — but only once
    /// (the first call for a given day wins, so a later disruption never overwrites the
    /// morning original). Call right after a day's plan is generated + saved.
    static func captureOriginal(_ plan: DailyPlan, now: Date = .now, calendar: Calendar = .current) {
        let k = key(for: plan.date, calendar: calendar)
        guard store.data(forKey: k) == nil else { return }   // don't clobber the original
        let snaps = DisruptionService.snapshot(of: plan, now: now)
        if let data = try? JSONEncoder().encode(snaps) {
            store.set(data, forKey: k)
            pruneOld(keeping: now, calendar: calendar)
        }
    }

    /// The persisted original snapshot for a given day, if one exists.
    static func original(for date: Date, calendar: Calendar = .current) -> [DisruptionService.ActionSnapshot]? {
        guard let data = store.data(forKey: key(for: date, calendar: calendar)) else { return nil }
        return try? JSONDecoder().decode([DisruptionService.ActionSnapshot].self, from: data)
    }

    static func clear(for date: Date, calendar: Calendar = .current) {
        store.removeObject(forKey: key(for: date, calendar: calendar))
    }

    /// Drop snapshots older than yesterday so this never accumulates.
    private static func pruneOld(keeping now: Date, calendar: Calendar = .current) {
        let cutoff = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
        for k in store.dictionaryRepresentation().keys where k.hasPrefix(prefix) {
            if let ts = Double(k.dropFirst(prefix.count)), ts < cutoff.timeIntervalSince1970 {
                store.removeObject(forKey: k)
            }
        }
    }
}
