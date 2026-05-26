import SwiftUI
import SwiftData

@main
struct AmbidashApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
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
