import Foundation
import SwiftData

@MainActor
enum SyncService {
    static func syncGoalsToCloud(goals: [Goal]) async {
        guard SupabaseService.shared.isAuthenticated,
              let userId = SupabaseService.shared.userId else { return }

        for goal in goals {
            let data: [String: Any] = [
                "id": goal.id.uuidString,
                "user_id": userId,
                "title": goal.title,
                "subtitle": goal.subtitle,
                "domain": goal.domainRaw,
                "horizon": goal.horizonRaw,
                "priority": goal.priority,
                "is_active": goal.isActive,
                "last_progress_date": ISO8601DateFormatter().string(from: goal.lastProgressDate),
                "streak_current": goal.streak?.currentCount ?? 0,
                "streak_best": goal.streak?.bestCount ?? 0,
            ]
            _ = await SupabaseService.shared.upsertGoal(data)
        }
    }

    static func syncProfileToCloud(profile: UserProfile) async {
        guard SupabaseService.shared.isAuthenticated,
              let userId = SupabaseService.shared.userId else { return }

        var data: [String: Any] = [
            "id": userId,
            "name": profile.name,
            "age": profile.age,
            "life_stage": profile.lifeStage,
            "scaffold_level": profile.scaffoldLevel,
            "plan_format": profile.workStylePreference?.planFormat ?? "focusBlocks",
            "max_actions_per_day": profile.workStylePreference?.maxActionsPerDay ?? 6,
        ]

        if let assessment = profile.coreAssessment {
            data["cognitive_style"] = assessment.cognitiveStyle
            data["peak_energy_time"] = assessment.peakEnergyTime
            data["overwhelm_response"] = assessment.overwhelmResponse
            data["adhd_score"] = assessment.adhdScore
            data["anxiety_score"] = assessment.anxietyScore
            data["top_values"] = assessment.topValues
            data["biggest_blocker"] = assessment.biggestBlocker
            data["accountability_preference"] = assessment.accountabilityPreference
        }

        _ = await SupabaseService.shared.upsertProfile(data)
    }

    static func syncReflectionToCloud(mood: String, blockers: [String], text: String) async {
        guard SupabaseService.shared.isAuthenticated,
              let userId = SupabaseService.shared.userId else { return }

        let data: [String: Any] = [
            "user_id": userId,
            "mood": mood,
            "blockers": blockers,
            "freeform_text": text,
        ]
        _ = await SupabaseService.shared.saveReflection(data)
    }
}
