// ambidash/Services/PlanGenerator.swift
import Foundation

enum PlanGenerator {
    struct ActionTemplate {
        let title: String
        let goalTitle: String
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

            let temps = domainTemplates[goal.domain] ?? []
            guard let t = temps.first(where: { $0.1 <= remainingMinutes && !usedKeys.contains("\(goal.title)-\($0.0)") }) else { continue }

            result.append(ActionTemplate(title: t.0, goalTitle: goal.title, domain: goal.domain, durationMinutes: t.1, why: t.2))
            remainingMinutes -= t.1
            usedKeys.insert("\(goal.title)-\(t.0)")
        }

        if result.count < maxActions {
            for goal in sorted where result.count < maxActions && remainingMinutes > 0 {
                let temps = domainTemplates[goal.domain] ?? []
                for t in temps {
                    let key = "\(goal.title)-\(t.0)"
                    if !usedKeys.contains(key) && t.1 <= remainingMinutes && result.count < maxActions {
                        result.append(ActionTemplate(title: t.0, goalTitle: goal.title, domain: goal.domain, durationMinutes: t.1, why: t.2))
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
