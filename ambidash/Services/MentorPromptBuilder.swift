// ambidash/Services/MentorPromptBuilder.swift
import Foundation

enum MentorPromptBuilder {
    /// A measurable/variance descriptor for a goal with a target, e.g.
    /// " · measurable: 12/20 lbs (60%), behind pace (on-pace today: 15 lbs)".
    private static func measurableLine(for goal: Goal) -> String {
        guard goal.hasTarget else { return "" }
        let unit = goal.unit.isEmpty ? "" : " \(goal.unit)"
        let current = format(goal.currentValue)
        let target = format(goal.targetValue)
        let expected = format(TargetMath.expectedValue(goal))
        let percent = Int((goal.percentComplete * 100).rounded())
        let pace: String
        switch TargetMath.variance(goal) {
        case .ahead: pace = "ahead of pace"
        case .onTrack: pace = "on pace"
        case .behind: pace = "BEHIND pace"
        }
        let dir = goal.direction == .increase ? "increasing" : "decreasing"
        return " · measurable: \(current)/\(target)\(unit) (\(percent)%, \(dir)), \(pace) (on-pace value today: \(expected)\(unit))"
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    static func insightPrompt(goals: [Goal], snapshot: IntegrationSnapshot?, streakSummary: String) -> String {
        var context = "You are an AI mentor inside ambidash, a life dashboard app. Your role is to spot patterns the user wouldn't notice themselves.\n\n"
        context += "USER'S GOALS:\n"
        for goal in goals where goal.isActive {
            let status = goal.computedStatus.label
            let days = goal.neglectDays
            context += "- \(goal.title) (\(goal.domain.displayName)): \(status), \(days) days since progress"
            if let streak = goal.streak, streak.currentCount > 0 {
                context += ", \(streak.currentCount)-day streak"
            }
            context += measurableLine(for: goal)
            context += "\n"
        }

        if let snap = snapshot {
            context += "\nTODAY'S DATA:\n"
            context += "- Sleep: \(String(format: "%.1f", snap.sleepHours)) hours\n"
            context += "- Steps: \(snap.steps)\n"
            context += "- Workouts: \(snap.workoutCount)\n"
            context += "- Screen time: \(String(format: "%.1f", snap.screenTimeHours)) hours\n"
            context += "- Calendar free time: \(snap.calendarFreeMinutes) minutes\n"
        }

        if !streakSummary.isEmpty {
            context += "\nSTREAKS: \(streakSummary)\n"
        }

        context += "\nGive ONE specific, actionable insight (2-3 sentences max). Connect data points the user wouldn't notice. For goals with a measurable target, watch the number: if a goal is BEHIND pace, call out the gap and what would close it. Be direct, not generic. No pleasantries."

        return context
    }

    static func planPrompt(goals: [Goal], snapshot: IntegrationSnapshot?, profile: UserProfile?) -> String {
        var context = "You are an AI mentor generating a daily action plan. Create specific, time-aware actions.\n\n"

        if let profile {
            context += "USER: \(profile.name), age \(profile.age)\n"
            if let assessment = profile.coreAssessment {
                context += "Peak energy: \(assessment.peakEnergyTime)\n"
                context += "Focus style: \(assessment.cognitiveStyle)\n"
                context += "Overwhelm response: \(assessment.overwhelmResponse)\n"
            }
            if let pref = profile.workStylePreference {
                context += "Preferred format: \(pref.format.displayName)\n"
                context += "Max actions/day: \(pref.maxActionsPerDay)\n"
            }
        }

        context += "\nGOALS (sorted by neglect):\n"
        let sorted = goals.filter(\.isActive).sorted { $0.neglectDays > $1.neglectDays }
        for goal in sorted {
            context += "- [id: \(goal.id.uuidString)] \(goal.title): \(goal.neglectDays) days neglected, priority \(goal.priority)"
            context += measurableLine(for: goal)
            context += "\n"
        }

        if let snap = snapshot {
            context += "\nTODAY'S STATE:\n"
            context += "- Slept \(String(format: "%.1f", snap.sleepHours))h, \(snap.steps) steps, \(snap.calendarFreeMinutes)min free\n"
        }

        context += "\nRespond with a JSON array of actions. Each action: {\"title\": \"...\", \"why\": \"...\", \"duration_minutes\": N, \"time_slot\": \"HH:MM\", \"goal_id\": \"uuid-string\", \"amount\": N, \"metric\": \"unit\"}\n"
        context += "Every action MUST set goal_id to exactly one UUID from the GOALS list above. Do not invent or hallucinate goal IDs. Each action advances exactly one goal from the list.\n"
        context += "For goals with a measurable target, size the action to move the number: set \"amount\" to the increment this action should add (in the goal's unit) and \"metric\" to that unit; omit both for goals without a target.\n"
        context += "Create \(profile?.workStylePreference?.maxActionsPerDay ?? 6) actions max. Prioritize goals that are BEHIND pace toward their target, then neglected goals. Fit into free time. Adjust intensity based on sleep quality."

        return context
    }
}
