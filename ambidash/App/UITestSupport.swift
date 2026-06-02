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
            goal.isSticky = true   // so the Sticky Notes surface shows a pinned goal
            goal.subtitle = "Sample goal seeded for UI tests"
            goal.profile = profile
            profile.goals = [goal]

            // A 2nd goal in a DIFFERENT domain (+ a subgoal) so the dynamic Categories
            // surface shows two derived groups and a non-zero subgoal count.
            let goal2 = Goal(title: "Ship the app", domain: .craft, priority: 1)
            goal2.isActive = true
            goal2.profile = profile
            let sub = Milestone(title: "Beta to 10 users", period: .month,
                                startDate: .now,
                                endDate: Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now)
            sub.goal = goal2
            goal2.milestones = [sub]

            // Preferences with a WAKE DRIFT (target 06:00, actually woke 09:00 today)
            // so the Wake Check nudge has something to surface. lastWakeRecordDay=today
            // stops WakeTracker from overwriting the seeded actual on launch.
            let prefs = UserPreferences()
            prefs.wakeTime = "06:00"
            prefs.lastActualWakeMinutes = 9 * 60   // 09:00
            prefs.lastWakeRecordDay = Calendar.current.startOfDay(for: .now)
            prefs.profile = profile
            profile.userPreferences = prefs

            context.insert(profile)
            context.insert(goal)
            context.insert(goal2)
            context.insert(sub)
            context.insert(prefs)
            try? context.save()
        }

        // Active board — seeded INDEPENDENTLY of the profile guard. Without an active
        // board the Dashboard shows the full-screen "Set up your dashboard" template
        // chooser that overlays EVERY tab, hiding the gear/mic/add controls from the
        // smoke tests. Guarded on hasActiveBoard so it's robust even when app data
        // persisted from an earlier run already has a (board-less) profile.
        // .balanced gives a varied component set (score, vitals, goals, nudge, today).
        // ALWAYS replace the board (not just when absent): the SwiftData store can
        // persist across app uninstalls, so a board seeded by an EARLIER build would
        // be missing newly-added template components. Replacing every -uitesting
        // launch keeps the board in lock-step with the current .balanced template.
        _ = BoardSeeder.replaceActiveBoard(with: .balanced, in: context)
        try? context.save()

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

        // A dated milestone 2 days out so the Week Ahead look-ahead shows a real
        // deadline ("Midterm") rather than an all-empty week. Guard on the absence of
        // a "Midterm" specifically — other seeds (e.g. goal2's subgoal) also create
        // milestones, so an `isEmpty` guard would wrongly skip this one.
        let milestones = (try? context.fetch(FetchDescriptor<Milestone>())) ?? []
        if !milestones.contains(where: { $0.title == "Midterm" }) {
            let cal = Calendar.current
            let due = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: .now)) ?? .now
            let m = Milestone(title: "Midterm", period: .week, startDate: .now, endDate: due)
            context.insert(m)
            try? context.save()
        }
    }
}
