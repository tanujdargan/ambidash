import Foundation
import SwiftData

@MainActor
enum SyncService {

    // MARK: - Full Sync (push + pull)

    static func fullSync(context: ModelContext, profile: UserProfile?) async {
        guard SupabaseService.shared.isAuthenticated,
              NetworkMonitor.shared.isConnected else { return }

        // Push local → cloud
        if let profile {
            await syncProfileToCloud(profile: profile)
            await syncGoalsToCloud(goals: profile.goals)
        }

        // Pull cloud → local
        await pullGoalsFromCloud(context: context, localGoals: profile?.goals ?? [])

        ErrorLogger.info("Sync completed")
    }

    // MARK: - Push (local → cloud)

    static func syncGoalsToCloud(goals: [Goal]) async {
        guard SupabaseService.shared.isAuthenticated,
              let userId = SupabaseService.shared.userId,
              NetworkMonitor.shared.isConnected else { return }

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
              let userId = SupabaseService.shared.userId,
              NetworkMonitor.shared.isConnected else { return }

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
              let userId = SupabaseService.shared.userId,
              NetworkMonitor.shared.isConnected else { return }

        let data: [String: Any] = [
            "user_id": userId,
            "mood": mood,
            "blockers": blockers,
            "freeform_text": text,
        ]
        _ = await SupabaseService.shared.saveReflection(data)
    }

    // MARK: - Pull (cloud → local) with conflict resolution

    static func pullGoalsFromCloud(context: ModelContext, localGoals: [Goal]) async {
        guard let remoteGoals = await SupabaseService.shared.fetchGoals() else { return }

        let localIds = Set(localGoals.map { $0.id.uuidString })

        for remote in remoteGoals {
            guard let remoteId = remote["id"] as? String else { continue }

            if localIds.contains(remoteId) {
                // Conflict resolution: cloud wins for streak_best (max), local wins for everything else
                if let local = localGoals.first(where: { $0.id.uuidString == remoteId }) {
                    let remoteBest = remote["streak_best"] as? Int ?? 0
                    if remoteBest > (local.streak?.bestCount ?? 0) {
                        local.streak?.bestCount = remoteBest
                    }
                }
            } else {
                // New goal from cloud — create locally
                let title = remote["title"] as? String ?? ""
                let domainRaw = remote["domain"] as? String ?? "body"
                let domain = GoalDomain(rawValue: domainRaw) ?? .body
                let priority = remote["priority"] as? Int ?? 1

                let goal = Goal(title: title, domain: domain, priority: priority)
                goal.subtitle = remote["subtitle"] as? String ?? ""
                goal.horizonRaw = remote["horizon"] as? String ?? "now"
                goal.isActive = remote["is_active"] as? Bool ?? true
                goal.streak = Streak()
                goal.streak?.currentCount = remote["streak_current"] as? Int ?? 0
                goal.streak?.bestCount = remote["streak_best"] as? Int ?? 0
                context.insert(goal)
            }
        }

        try? context.save()
    }
}
