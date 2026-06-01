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
            ReflectionPhoto.self,
            MentorFeedback.self,
            ProgressLog.self,
            Milestone.self,
            Board.self,
            BoardComponent.self,
            CaptureItem.self,
            ActualEvent.self,
            EnergyCheckin.self,
        ])
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // CAPTURE everywhere — a global Cmd-K "New Capture" so the universal dump
            // (design principle #4) is one keystroke away from any screen, mirroring
            // the always-accessible Capture pill on iOS. The command posts a
            // notification the root window observes to present the capture sheet.
            CommandGroup(after: .newItem) {
                Button("New Capture") {
                    NotificationCenter.default.post(name: .macNewCapture, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }

        Settings {
            MacSettingsView()
                .environment(themeManager)
        }
    }
}
