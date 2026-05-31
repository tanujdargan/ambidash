import SwiftUI
import SwiftData

/// macOS entry point for AmbiDash.
///
/// This target SHARES the model layer, the platform-agnostic services, and the
/// theme with the live iOS app. It deliberately uses the SAME ModelContainer
/// configuration (the same 15 @Model entities + the same CloudKit-backed
/// `iCloud.com.ambidash.app` container) so data round-trips with iOS
/// automatically: CloudKit's private database syncs across devices signed into
/// the same Apple ID with no extra sync code.
///
/// IMPORTANT: keep this model list IDENTICAL to `AmbidashApp.swift` (iOS). A
/// divergence would cause a CloudKit schema mismatch.
@main
struct AmbidashMacApp: App {
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            MacRootView()
                .environment(themeManager)
                .preferredColorScheme(themeManager.isDark ? .dark : .light)
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(for: [
            UserProfile.self,
            CoreAssessment.self,
            WorkStylePreference.self,
            UserPreferences.self,
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
            Board.self,
            BoardComponent.self,
        ])
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        Settings {
            MacSettingsView()
                .environment(themeManager)
        }
    }
}
