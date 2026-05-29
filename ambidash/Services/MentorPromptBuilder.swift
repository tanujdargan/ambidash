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

    /// A cadence/adherence descriptor for a habitual (habit/recurring) goal, e.g.
    /// " · habitual: 2 of 3 this week (recurring 3x/wk)". Empty for non-habitual goals.
    private static func habitualLine(for goal: Goal) -> String {
        guard goal.isHabitual else { return "" }
        let logged = AdherenceFormat.loggedThisWeek(for: goal)
        let target = AdherenceFormat.target(for: goal)
        let kind = goal.goalType.displayName.lowercased()
        return " · habitual: \(logged) of \(target) this week (\(kind) \(target)x/wk)"
    }

    /// How far short of this week's cadence a habitual goal is, as a fraction
    /// (0 = met or exceeded, 1 = nothing logged). Used to surface the most
    /// behind-cadence habitual goals first instead of treating off-days as neglect.
    private static func adherenceShortfall(for goal: Goal) -> Double {
        max(0, 1 - goal.adherenceThisWeek)
    }

    /// A unified attention score for ordering goals in the plan prompt. Habitual
    /// goals are scored by their weekly adherence shortfall (off-days don't count
    /// as neglect); other goals by raw neglect days. Scaling keeps a fully-missed
    /// habitual week (score 7) comparable to a week of neglect for a one-off goal.
    private static func attentionScore(for goal: Goal) -> Double {
        if goal.isHabitual {
            return adherenceShortfall(for: goal) * 7
        }
        return Double(goal.neglectDays)
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
            context += habitualLine(for: goal)
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

        context += "\nGive ONE specific, actionable insight (2-3 sentences max). Connect data points the user wouldn't notice. For goals with a measurable target, watch the number: if a goal is BEHIND pace, call out the gap and what would close it. For habitual goals, judge by weekly cadence (the \"X of Y this week\" figure), not days since last touch — an off-day for a 3x/week goal is not a lapse. Be direct, not generic. No pleasantries."

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

        context += "\nGOALS (most in need of attention first):\n"
        // Rank habitual goals by how far short of this week's cadence they are
        // (an off-day for a 3x/wk goal is NOT neglect); rank the rest by raw
        // neglect days. Habitual goals behind cadence sort ahead of on-track ones.
        let sorted = goals.filter(\.isActive).sorted { lhs, rhs in
            attentionScore(for: lhs) > attentionScore(for: rhs)
        }
        for goal in sorted {
            if goal.isHabitual {
                context += "- [id: \(goal.id.uuidString)] \(goal.title): priority \(goal.priority)"
            } else {
                context += "- [id: \(goal.id.uuidString)] \(goal.title): \(goal.neglectDays) days neglected, priority \(goal.priority)"
            }
            context += measurableLine(for: goal)
            context += habitualLine(for: goal)
            context += "\n"
        }

        if let snap = snapshot {
            context += "\nTODAY'S STATE:\n"
            context += "- Slept \(String(format: "%.1f", snap.sleepHours))h, \(snap.steps) steps, \(snap.calendarFreeMinutes)min free\n"
        }

        context += "\nRespond with a JSON array of actions. Each action: {\"title\": \"...\", \"why\": \"...\", \"duration_minutes\": N, \"time_slot\": \"HH:MM\", \"goal_id\": \"uuid-string\", \"amount\": N, \"metric\": \"unit\"}\n"
        context += "Every action MUST set goal_id to exactly one UUID from the GOALS list above. Do not invent or hallucinate goal IDs. Each action advances exactly one goal from the list.\n"
        context += "For goals with a measurable target, size the action to move the number: set \"amount\" to the increment this action should add (in the goal's unit) and \"metric\" to that unit; omit both for goals without a target.\n"
        context += "Create \(profile?.workStylePreference?.maxActionsPerDay ?? 6) actions max. Prioritize goals that are BEHIND pace toward their target, then habitual goals short of their weekly cadence, then neglected one-off goals. For habitual goals, judge by the weekly cadence shown (e.g. \"2 of 3 this week\"): a goal that has already met its cadence needs no action today, and an off-day is NOT neglect — do not push a habitual goal just because a day or two passed. Fit into free time. Adjust intensity based on sleep quality."

        return context
    }
}
