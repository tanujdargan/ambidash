import AppIntents
import Foundation
import SwiftData

struct LogProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Goal Progress"
    static let description: IntentDescription = "Mark progress on one of your goals."
    static let openAppWhenRun = false

    @Parameter(title: "Goal Name")
    var goalName: String?

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(try LogProgressIntent.sharedContainer())

        guard let goal = try resolveGoal(in: context) else {
            return .result(dialog: "I couldn't find an active goal to log progress on.")
        }

        // Reuse the real logging primitive used by Today completions and the
        // goal quick/detail sheets so streaks, weekly adherence, and
        // last-progress all advance exactly the same way as in-app logging.
        ProgressLogService.logCheckIn(goal: goal, source: .manual, context: context)
        try context.save()

        return .result(dialog: "Logged progress on \(goal.title).")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log progress on \(\.$goalName)")
    }

    // MARK: - Goal resolution

    /// Finds the goal to log against. When the user named a goal, matches it
    /// case-insensitively (exact first, then a substring contains). Otherwise —
    /// and as a fallback when the spoken name matches nothing — logs against the
    /// most-neglected active goal so the intent always does something real.
    private func resolveGoal(in context: ModelContext) throws -> Goal? {
        let descriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.isActive }
        )
        let activeGoals = try context.fetch(descriptor)
        guard !activeGoals.isEmpty else { return nil }

        if let spoken = goalName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !spoken.isEmpty {
            let needle = spoken.lowercased()
            if let exact = activeGoals.first(where: { $0.title.lowercased() == needle }) {
                return exact
            }
            if let partial = activeGoals.first(where: { $0.title.lowercased().contains(needle) }) {
                return partial
            }
        }

        // Most-neglected active goal: the one untouched the longest.
        return activeGoals.max { $0.lastProgressDate > $1.lastProgressDate }
    }

    // MARK: - Shared container

    /// Opens a ModelContainer over the same default on-disk store the app writes
    /// to, using an identical schema so reads/writes land in the live data set.
    /// The app uses SwiftUI's `.modelContainer(for:)` with the default
    /// (non-CloudKit) configuration, so we mirror that here.
    static func sharedContainer() throws -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            CoreAssessment.self,
            WorkStylePreference.self,
            Goal.self,
            DomainAssessment.self,
            GoalProgress.self,
            Streak.self,
            IntegrationSnapshot.self,
            DailyPlan.self,
            PlannedAction.self,
            Reflection.self,
            MentorFeedback.self,
            ProgressLog.self,
            Milestone.self,
        ])
        let configuration = ModelConfiguration(schema: schema)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

struct GeneratePlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate Today's Plan"
    static let description: IntentDescription = "Create a daily action plan from your goals."
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct AmbidashShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogProgressIntent(),
            phrases: [
                "Log progress in \(.applicationName)",
                "Update my goals in \(.applicationName)",
            ],
            shortTitle: "Log Progress",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: GeneratePlanIntent(),
            phrases: [
                "Generate my plan in \(.applicationName)",
                "What should I do today in \(.applicationName)",
            ],
            shortTitle: "Today's Plan",
            systemImageName: "calendar"
        )
    }
}
