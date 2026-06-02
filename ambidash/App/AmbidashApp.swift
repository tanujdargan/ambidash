import SwiftUI
import SwiftData

@main
struct AmbidashApp: App {
    @State private var themeManager = ThemeManager()
    @State private var deepLinkTab: Int?
    // Owns the UNUserNotificationCenterDelegate so the gentle-check-in interactive
    // actions are live from launch (categories alone are inert without a delegate).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        if CommandLine.arguments.contains("--reset-state") {
            UserDefaults.standard.removeObject(forKey: "theme_setup_complete")
            UserDefaults.standard.removeObject(forKey: "onboardingComplete")
        }
        if CommandLine.arguments.contains("--skip-to-dashboard") {
            UserDefaults.standard.set(true, forKey: "theme_setup_complete")
            UserDefaults.standard.set(true, forKey: "onboardingComplete")
        }
        // TEST-ONLY deterministic launch. When the harness passes "-uitesting" we
        // skip every onboarding gate (theme setup, assessment, goal declaration)
        // and pin a known typography so UI tests land straight on MainTabView. The
        // matching UserProfile + sample Goal are seeded into the SwiftData store in
        // RootView (where the modelContext is available). Inert without the flag.
        if UITestSupport.isActive {
            UserDefaults.standard.set(true, forKey: "theme_setup_complete")
            UserDefaults.standard.set(true, forKey: "onboardingComplete")
            UserDefaults.standard.set("technical", forKey: "theme_typography")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(deepLinkTab: $deepLinkTab)
                .environment(themeManager)
                .preferredColorScheme(themeManager.isDark ? .dark : .light)
                .onOpenURL { url in
                    if let link = DeepLink.from(url: url) {
                        deepLinkTab = link.tabIndex
                    }
                }
                // A notification tap / action routes its deep link here so taps on
                // gentle check-ins land the user on the right tab.
                .onReceive(NotificationCenter.default.publisher(for: NotificationDelegate.deepLinkNotification)) { note in
                    if let tab = note.userInfo?["tabIndex"] as? Int {
                        deepLinkTab = tab
                    }
                }
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
    }
}
