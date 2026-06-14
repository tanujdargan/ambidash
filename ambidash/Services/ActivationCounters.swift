import Foundation

// Phase 0 (cohesion + harden) — privacy-safe activation instrumentation.
//
// The plan: "you can't improve retention you can't see" — but the privacy moat is
// "Data Not Collected." The resolution is on-device-only funnel counters: plain
// UserDefaults integers + a first-occurrence timestamp, never sent anywhere, never
// an SDK. Lets us (or a future in-app insights surface) see whether the Week-1 "aha"
// moments actually happen, without collecting anything off-device.

enum ActivationEvent: String, CaseIterable, Identifiable {
    case onboardingCompleted = "act.onboarding_completed"
    case firstGoalCreated = "act.first_goal_created"
    case firstPlanGenerated = "act.first_plan_generated"
    case firstCapture = "act.first_capture"
    case firstReflection = "act.first_reflection"
    case firstMentorLetter = "act.first_mentor_letter"
    case dayPlanCompleted = "act.day_plan_completed"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .onboardingCompleted: "Onboarding completed"
        case .firstGoalCreated: "First goal created"
        case .firstPlanGenerated: "First plan generated"
        case .firstCapture: "First capture"
        case .firstReflection: "First reflection"
        case .firstMentorLetter: "First mentor letter"
        case .dayPlanCompleted: "Finished a day's plan"
        }
    }
}

enum ActivationCounters {
    private static let firstSeenSuffix = ".firstAt"
    /// Injectable test seam; `nonisolated(unsafe)` is safe (UserDefaults is thread-safe).
    nonisolated(unsafe) static var store: UserDefaults = .standard

    /// Record `count` occurrences of an event. Stamps the first-occurrence date once.
    static func record(_ event: ActivationEvent, count: Int = 1) {
        let key = event.rawValue
        store.set(store.integer(forKey: key) + max(0, count), forKey: key)
        let firstKey = key + firstSeenSuffix
        if store.object(forKey: firstKey) == nil {
            store.set(Date.now.timeIntervalSince1970, forKey: firstKey)
        }
    }

    static func count(_ event: ActivationEvent) -> Int { store.integer(forKey: event.rawValue) }

    static func hasOccurred(_ event: ActivationEvent) -> Bool { count(event) > 0 }

    static func firstOccurrence(_ event: ActivationEvent) -> Date? {
        guard let t = store.object(forKey: event.rawValue + firstSeenSuffix) as? Double else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    /// A snapshot of all counters — for a future on-device insights surface or export.
    static func snapshot() -> [ActivationEvent: Int] {
        var out: [ActivationEvent: Int] = [:]
        for e in ActivationEvent.allCases { out[e] = count(e) }
        return out
    }

    static func reset(_ event: ActivationEvent) {
        store.removeObject(forKey: event.rawValue)
        store.removeObject(forKey: event.rawValue + firstSeenSuffix)
    }
}
