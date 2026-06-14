import Foundation

// Phase 0 (cohesion + harden) — lightweight on-device feature gating.
//
// The product plan's "finish-or-hide" rule: a focused v1 must never surface a
// half-built feature (it reads as "too much / unfinished"). These flags let us
// honestly HIDE not-yet-shippable surfaces — body-doubling presence, cross-user
// mentor matching, social feed — behind a single switch, defaulting OFF, with a
// DEBUG QA panel to flip them. No remote config, no network: purely local
// UserDefaults so it never touches the "Data Not Collected" privacy posture.

enum FeatureFlag: String, CaseIterable, Identifiable {
    case bodyDoubling = "feature.bodyDoubling"
    case mentorMatching = "feature.mentorMatching"
    case socialFeed = "feature.socialFeed"

    var id: String { rawValue }

    /// Ship-default. Every gated stub is OFF for the focused v1.
    var defaultEnabled: Bool { false }

    var displayName: String {
        switch self {
        case .bodyDoubling: "Body-doubling presence"
        case .mentorMatching: "Mentor matching"
        case .socialFeed: "Social feed / accountability"
        }
    }
}

enum FeatureFlags {
    /// Injectable so tests stay hermetic (never touch `.standard`). `nonisolated(unsafe)`
    /// is safe here — UserDefaults is itself thread-safe; this is only a test seam.
    nonisolated(unsafe) static var store: UserDefaults = .standard

    /// Whether a flag is on. Unset → the flag's ship-default (OFF for all stubs).
    static func isEnabled(_ flag: FeatureFlag) -> Bool {
        guard store.object(forKey: flag.rawValue) != nil else { return flag.defaultEnabled }
        return store.bool(forKey: flag.rawValue)
    }

    static func set(_ flag: FeatureFlag, _ enabled: Bool) {
        store.set(enabled, forKey: flag.rawValue)
    }

    /// Reset a flag to its ship-default (used by the QA panel / tests).
    static func reset(_ flag: FeatureFlag) {
        store.removeObject(forKey: flag.rawValue)
    }
}
