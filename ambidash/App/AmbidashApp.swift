import SwiftUI
import SwiftData

@main
struct AmbidashApp: App {
    @State private var themeManager = ThemeManager()
    @State private var deepLinkTab: Int?

    init() {
        if CommandLine.arguments.contains("--reset-state") {
            UserDefaults.standard.removeObject(forKey: "theme_setup_complete")
            UserDefaults.standard.removeObject(forKey: "onboardingComplete")
        }
        if CommandLine.arguments.contains("--skip-to-dashboard") {
            UserDefaults.standard.set(true, forKey: "theme_setup_complete")
            UserDefaults.standard.set(true, forKey: "onboardingComplete")
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
            CaptureItem.self,
            ActualEvent.self,
            EnergyCheckin.self,
        ])
    }
}
