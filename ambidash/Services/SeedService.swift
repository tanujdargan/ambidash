import Foundation
import SwiftData

@MainActor
enum SeedService {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>()
        let existingProfiles = (try? context.fetch(descriptor)) ?? []
        guard existingProfiles.isEmpty else { return }
        guard UserDefaults.standard.bool(forKey: "onboardingComplete") else { return }

        let profile = UserProfile(name: "Tanuj", age: 21)
        profile.lifeStage = "student · engineer · founder-curious"
        profile.onboardingComplete = true

        let assessment = CoreAssessment()
        assessment.cognitiveStyle = "deep_blocks"
        assessment.peakEnergyTime = "morning"
        assessment.overwhelmResponse = "hyperfocus"
        assessment.adhdScore = 5
        assessment.anxietyScore = 2
        assessment.topValues = ["career", "health", "learning"]
        assessment.biggestBlocker = "focus"
        assessment.accountabilityPreference = "want_it"
        profile.coreAssessment = assessment

        let pref = WorkStylePreference(planFormat: .focusBlocks)
        profile.workStylePreference = pref

        // Add all 52 goals from life map
        var priority = 1
        for domain in GoalDomain.allCases {
            for template in GoalLibrary.starterGoals(for: domain) {
                let goal = Goal(title: template.title, domain: domain, priority: priority)
                goal.subtitle = template.subtitle
                goal.horizon = template.horizon
                // F3 — set curated type/cadence, falling back to inference.
                goal.goalType = template.goalType ?? GoalTypeInferenceService.infer(goal)
                goal.timesPerWeek = template.timesPerWeek
                goal.recurrence = recurrence(for: goal.goalType, timesPerWeek: template.timesPerWeek)
                goal.streak = Streak()
                // Simulate some progress
                if template.horizon == .now {
                    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 0...3), to: .now)!
                    goal.streak?.currentCount = Int.random(in: 1...15)
                    goal.streak?.bestCount = Int.random(in: 5...20)
                } else if template.horizon == .soon {
                    goal.lastProgressDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 2...7), to: .now)!
                }
                goal.profile = profile
                priority += 1
            }
        }

        context.insert(profile)
        try? context.save()
        ErrorLogger.info("Seeded profile with \(profile.goals?.count ?? 0) goals")
    }

    /// Maps an F3 type + cadence to a recurrence rule for seeded goals.
    private static func recurrence(for type: GoalType, timesPerWeek: Int) -> GoalRecurrence {
        switch type {
        case .habit: return .daily
        case .recurring: return timesPerWeek >= 7 ? .daily : .weekly
        case .project, .milestone, .accumulation: return .none
        }
    }
}
