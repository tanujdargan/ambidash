import Foundation
import SwiftData

/// TEST-ONLY launch support. Everything here is gated on the `-uitesting` launch
/// argument and is completely inert in a normal user launch (the flag is never
/// present in production). It exists so XCUITest can land deterministically on
/// MainTabView with a known, seeded data shape instead of fighting onboarding.
enum UITestSupport {
    /// True only when the app was launched by the UI-test harness.
    static var isActive: Bool {
        CommandLine.arguments.contains("-uitesting")
    }

    /// Seed a minimal but valid UserProfile (name "Test", age 21) plus one sample
    /// Goal into the SwiftData store, idempotently. Safe to call on every launch:
    /// it no-ops once a profile already exists. Only ever invoked under `isActive`.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        guard isActive else { return }

        // Already seeded (or a real profile exists) → leave the store untouched.
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard existing.isEmpty else { return }

        let profile = UserProfile(name: "Test", age: 21, lifeStage: "student")
        profile.onboardingComplete = true

        let goal = Goal(title: "Run a 5K", domain: .body, priority: 0)
        goal.isActive = true
        goal.subtitle = "Sample goal seeded for UI tests"
        goal.profile = profile
        profile.goals = [goal]

        context.insert(profile)
        context.insert(goal)
        try? context.save()
    }
}
