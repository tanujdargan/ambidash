import SwiftUI
import SwiftData

@main
struct AmbidashApp: App {
    @State private var themeManager = ThemeManager()
    @State private var deepLinkTab: Int?

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
            Goal.self,
            DomainAssessment.self,
            GoalProgress.self,
            Streak.self,
            IntegrationSnapshot.self,
            DailyPlan.self,
            PlannedAction.self,
            Reflection.self,
            MentorFeedback.self,
        ])
    }
}
