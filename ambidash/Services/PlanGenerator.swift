// ambidash/Services/PlanGenerator.swift
import Foundation

enum PlanGenerator {
    struct ActionTemplate {
        let title: String
        let goalTitle: String
        let goalID: UUID
        let domain: GoalDomain
        let durationMinutes: Int
        let why: String
    }

    static let domainTemplates: [GoalDomain: [(String, Int, String)]] = [
        .body: [
            ("Workout session", 45, "Consistency builds the body you want"),
            ("30-minute walk", 30, "Active recovery and fresh air"),
            ("Stretching routine", 15, "Flexibility prevents injury"),
        ],
        .mind: [
            ("Deep reading session", 45, "Build knowledge that compounds"),
            ("Learn something new (video/article)", 30, "Expand your mental models"),
            ("Practice recall on recent learning", 20, "Retrieval strengthens memory"),
            ("Language practice", 20, "Daily practice builds fluency"),
            ("Phone-free block", 60, "Reclaim your attention"),
            ("Delete or mute one notification source", 5, "Reduce digital noise"),
        ],
        .craft: [
            ("Deep work on main project", 90, "Focused work moves the needle"),
            ("Code review or skill practice", 45, "Sharpen the saw"),
            ("Research/planning session", 30, "Strategy before execution"),
        ],
        .people: [
            ("Reach out to one person", 10, "Relationships need maintenance"),
            ("Social challenge: start a conversation", 15, "Growth happens outside comfort zones"),
        ],
        .wealth: [
            ("Review budget or spending", 20, "Awareness drives better decisions"),
            ("Work on income-generating project", 60, "Build assets, not just habits"),
        ],
        .adventure: [
            ("Do something new today", 60, "Novel experiences expand who you are"),
            ("Plan an experience", 20, "Anticipation is half the joy"),
        ],
    ]

    static func templates(for domain: GoalDomain) -> [(String, Int, String)] {
        domainTemplates[domain] ?? []
    }

    /// F3 — a goalType-aware action shaped to *how* the goal is pursued. Returns
    /// nil for types with no specific override so the caller falls back to the
    /// per-domain templates. Habit/recurring actions are sized to cadence.
    static func typeTemplate(for goal: Goal) -> (String, Int, String)? {
        switch goal.goalType {
        case .habit:
            return ("Show up today: \(goal.title)", 20,
                    "Daily consistency is the whole game for this one")
        case .recurring:
            let perWeek = max(goal.timesPerWeek, 1)
            let cadence = perWeek == 1 ? "this week" : "(\(perWeek)x/week)"
            return ("Do your \(goal.title) session \(cadence)", 45,
                    "Hit your weekly cadence — adherence beats intensity")
        case .project:
            return ("Take the next step on \(goal.title)", 60,
                    "Projects move forward one concrete step at a time")
        case .milestone:
            return ("Advance toward: \(goal.title)", 45,
                    "Close the gap to this checkpoint")
        case .accumulation:
            let unit = goal.unit.isEmpty ? "the number" : goal.unit
            return ("Move \(unit) on \(goal.title)", 30,
                    "Small, regular gains compound toward the target")
        }
    }

    /// Ordered action candidates for a goal: the goalType-aware action first (if
    /// any), then the per-domain templates as fallback. Additive refinement over
    /// the prior domain-only selection.
    static func candidateTemplates(for goal: Goal) -> [(String, Int, String)] {
        let domain = domainTemplates[goal.domain] ?? []
        if let typed = typeTemplate(for: goal) {
            return [typed] + domain
        }
        return domain
    }

    static func generateActions(for goals: [Goal], freeMinutes: Int, maxActions: Int) -> [ActionTemplate] {
        let active = goals.filter(\.isActive)
        guard !active.isEmpty else { return [] }

        let sorted = active.sorted { a, b in
            if a.neglectDays != b.neglectDays { return a.neglectDays > b.neglectDays }
            return a.priority < b.priority
        }

        var result: [ActionTemplate] = []
        var remainingMinutes = freeMinutes
        var usedKeys: Set<String> = []

        for goal in sorted {
            if result.count >= maxActions || remainingMinutes <= 0 { break }

            // F3 — prefer a goalType-aware action, then fall back to per-domain templates.
            let temps = candidateTemplates(for: goal)
            guard let t = temps.first(where: { $0.1 <= remainingMinutes && !usedKeys.contains("\(goal.title)-\($0.0)") }) else { continue }

            result.append(ActionTemplate(title: t.0, goalTitle: goal.title, goalID: goal.id, domain: goal.domain, durationMinutes: t.1, why: t.2))
            remainingMinutes -= t.1
            usedKeys.insert("\(goal.title)-\(t.0)")
        }

        if result.count < maxActions {
            for goal in sorted where result.count < maxActions && remainingMinutes > 0 {
                let temps = candidateTemplates(for: goal)
                for t in temps {
                    let key = "\(goal.title)-\(t.0)"
                    if !usedKeys.contains(key) && t.1 <= remainingMinutes && result.count < maxActions {
                        result.append(ActionTemplate(title: t.0, goalTitle: goal.title, goalID: goal.id, domain: goal.domain, durationMinutes: t.1, why: t.2))
                        remainingMinutes -= t.1
                        usedKeys.insert(key)
                        break
                    }
                }
            }
        }

        return result
    }
}
