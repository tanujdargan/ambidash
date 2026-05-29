import Foundation
import SwiftData

enum DataExportService {
    static func exportJSON(profile: UserProfile, plans: [DailyPlan], reflections: [Reflection], snapshots: [IntegrationSnapshot]) -> Data? {
        var export: [String: Any] = [:]

        export["exported_at"] = ISO8601DateFormatter().string(from: .now)
        export["app_version"] = "1.0.0"

        export["profile"] = [
            "name": profile.name,
            "age": profile.age,
            "life_stage": profile.lifeStage,
            "created_at": ISO8601DateFormatter().string(from: profile.createdAt),
            "scaffold_level": profile.scaffoldLevel,
        ]

        if let assessment = profile.coreAssessment {
            export["assessment"] = [
                "cognitive_style": assessment.cognitiveStyle,
                "peak_energy_time": assessment.peakEnergyTime,
                "adhd_score": assessment.adhdScore,
                "anxiety_score": assessment.anxietyScore,
                "top_values": assessment.topValues,
                "biggest_blocker": assessment.biggestBlocker,
            ]
        }

        export["goals"] = (profile.goals ?? []).map { goal -> [String: Any] in
            [
                "title": goal.title,
                "subtitle": goal.subtitle,
                "domain": goal.domainRaw,
                "horizon": goal.horizonRaw,
                "priority": goal.priority,
                "is_active": goal.isActive,
                "created_at": ISO8601DateFormatter().string(from: goal.createdAt),
                "last_progress": ISO8601DateFormatter().string(from: goal.lastProgressDate),
                "neglect_days": goal.neglectDays,
                "streak_current": goal.streak?.currentCount ?? 0,
                "streak_best": goal.streak?.bestCount ?? 0,
            ]
        }

        export["plans_count"] = plans.count
        export["reflections_count"] = reflections.count
        export["snapshots_count"] = snapshots.count

        let recentPlans = plans.prefix(30).map { plan -> [String: Any] in
            [
                "date": ISO8601DateFormatter().string(from: plan.date),
                "action_count": plan.actionCount,
                "done": (plan.actions ?? []).filter { $0.statusRaw == "done" }.count,
                "skipped": (plan.actions ?? []).filter { $0.statusRaw == "skipped" }.count,
            ]
        }
        export["recent_plans"] = Array(recentPlans)

        return try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys])
    }
}
