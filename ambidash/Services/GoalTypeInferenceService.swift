import Foundation

/// Pure, side-effect-free inference of a sensible `GoalType` for goals that have
/// no explicitly stored type. Used by `Goal.goalType` so existing (pre-F3) goals
/// get a reasonable classification on read with NO migration write.
enum GoalTypeInferenceService {
    static func infer(_ goal: Goal) -> GoalType {
        let haystack = (goal.title + " " + goal.subtitle).lowercased()

        // 1. Explicit weekly-cadence phrasing → recurring practice.
        let recurringPhrases = ["x/week", "x / week", "/week", "per week", "times a week",
                                "times per week", "every payday", "x/wk", "weekly"]
        if recurringPhrases.contains(where: haystack.contains) {
            return .recurring
        }

        // 2. Daily identity behaviors → habit.
        let habitWords = ["daily", "every day", "sleep", "journal", "meditat", "groom",
                          "morning", "night routine", "wake", "bedtime", "habit", "streak"]
        if habitWords.contains(where: haystack.contains) {
            return .habit
        }

        // 3. Single dated checkpoints / one-off achievements → milestone.
        let milestoneWords = ["pr ", " pr", "permanent residency", "publication", "publish a",
                              "fellowship", "license", "certif", "degree", "graduate", "buy the",
                              "purchase", "get accepted", "pass the", "exam", "marathon", "summit"]
        if milestoneWords.contains(where: haystack.contains) {
            return .milestone
        }
        // A genuinely long-horizon, non-measurable goal reads as a one-off dream milestone.
        if goal.horizon == .dream && !goal.hasTarget {
            return .milestone
        }

        // 4. A climbing number toward a target, or saving/investing language → accumulation.
        let accumulationWords = ["fund", "invest", "save", "net worth", "savings", "raise $",
                                 "reach $", "subscribers", "followers", "revenue", "mrr", "weight to"]
        if goal.hasTarget || accumulationWords.contains(where: haystack.contains) {
            return .accumulation
        }

        // 5. Multi-step deliverables on a near/mid horizon → project.
        let projectWords = ["launch", "ship", "build", "write", "create", "design", "develop",
                            "release", "finish", "complete", "start a", "found"]
        if projectWords.contains(where: haystack.contains) {
            return .project
        }
        if goal.horizon == .soon || goal.horizon == .build {
            return .project
        }

        // 6. Sensible default for near-term, undifferentiated goals.
        return .habit
    }
}
