import AppIntents

struct LogProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Goal Progress"
    static let description: IntentDescription = "Mark progress on one of your goals."
    static let openAppWhenRun = false

    @Parameter(title: "Goal Name")
    var goalName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Logged progress on \(goalName).")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Log progress on \(\.$goalName)")
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
