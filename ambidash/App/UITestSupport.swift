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

        // Profile + sample goal — only when none exists yet.
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        if existing.isEmpty {
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

        // Active board — seeded INDEPENDENTLY of the profile guard. Without an active
        // board the Dashboard shows the full-screen "Set up your dashboard" template
        // chooser that overlays EVERY tab, hiding the gear/mic/add controls from the
        // smoke tests. Guarded on hasActiveBoard so it's robust even when app data
        // persisted from an earlier run already has a (board-less) profile.
        // .balanced gives a varied component set (score, vitals, goals, nudge, today).
        if !BoardSeeder.hasActiveBoard(in: context) {
            _ = BoardSeeder.seed(template: .balanced, in: context)
            try? context.save()
        }

        // A small daily plan (2 of 3 done) so completion/progress surfaces have real
        // data — the Today's Progress ring shows 67% instead of an empty state.
        let plans = (try? context.fetch(FetchDescriptor<DailyPlan>())) ?? []
        if plans.isEmpty {
            let plan = DailyPlan(date: .now)
            let a1 = PlannedAction(title: "Morning run", timeSlot: "07:00", duration: 30)
            let a2 = PlannedAction(title: "Deep work block", timeSlot: "09:00", duration: 90)
            let a3 = PlannedAction(title: "Read 20 pages", timeSlot: "21:00", duration: 25)
            a1.applyLifecycle(.done)
            a2.applyLifecycle(.done)
            plan.actions = [a1, a2, a3]
            context.insert(plan)
            [a1, a2, a3].forEach { context.insert($0) }
            try? context.save()
        }
    }
}
