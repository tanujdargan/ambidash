// ambidashTests/Services/V3TestSupport.swift
//
// Shared in-memory ModelContainer for the V3 SwiftData-backed tests. Mirrors the
// app's registered schema so @Model inserts/relationships behave exactly as in
// production, but is fully in-memory (isStoredInMemoryOnly) so each test is
// isolated and leaves no store on disk.
import Foundation
import SwiftData
@testable import ambidash

enum V3TestSupport {
    /// An in-memory container registering the full V3 model graph. Use a fresh one
    /// per test for isolation.
    static func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self,
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
            configurations: config
        )
    }
}
