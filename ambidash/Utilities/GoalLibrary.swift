import Foundation

enum GoalLibrary {
    struct GoalTemplate {
        let title: String
        let subtitle: String
        let horizon: GoalHorizon
    }

    static func starterGoals(for domain: GoalDomain) -> [GoalTemplate] {
        switch domain {
        case .body:
            return [
                GoalTemplate(title: "Fix sleep schedule", subtitle: "anchor wake time, no exceptions", horizon: .now),
                GoalTemplate(title: "Compound lifts 3-4x/week", subtitle: "track progressive overload", horizon: .now),
                GoalTemplate(title: "Clean eating", subtitle: "cut the trash, build the habit", horizon: .now),
                GoalTemplate(title: "Lean toned body", subtitle: "visible abs, strong back", horizon: .soon),
            ]
        case .mind:
            return [
                GoalTemplate(title: "Control emotions in the moment", subtitle: "pause before reacting", horizon: .now),
                GoalTemplate(title: "Start therapy or journaling", subtitle: "fix deep-rooted issues", horizon: .now),
                GoalTemplate(title: "Build genuine self-confidence", subtitle: "not bravado — real worth", horizon: .soon),
                GoalTemplate(title: "Reading habit", subtitle: "Kindle there, build the ritual", horizon: .soon),
            ]
        case .craft:
            return [
                GoalTemplate(title: "Do hard things daily", subtitle: "bias toward difficulty always", horizon: .now),
                GoalTemplate(title: "Write deliberately", subtitle: "journal, startup copy, research", horizon: .now),
                GoalTemplate(title: "Launch startup solo", subtitle: "ship the first version", horizon: .soon),
                GoalTemplate(title: "AI research — make your mark", subtitle: "1-2 publications", horizon: .build),
            ]
        case .people:
            return [
                GoalTemplate(title: "Be more social", subtitle: "say yes more, initiate more", horizon: .now),
                GoalTemplate(title: "Make real friends", subtitle: "not acquaintances, actual people", horizon: .soon),
                GoalTemplate(title: "Build deliberate network", subtitle: "5-10 exceptional people", horizon: .soon),
                GoalTemplate(title: "Find the LOML", subtitle: "after foundation is solid", horizon: .build),
            ]
        case .wealth:
            return [
                GoalTemplate(title: "Invest every payday", subtitle: "XEQT compounding + emergency fund", horizon: .now),
                GoalTemplate(title: "Financial independence", subtitle: "startup or salary, get there", horizon: .build),
                GoalTemplate(title: "Buy the Porsche 911", subtitle: "", horizon: .dream),
            ]
        case .adventure:
            return [
                GoalTemplate(title: "Keep gaming", subtitle: "don't disappear in the grind", horizon: .now),
                GoalTemplate(title: "Protect photography", subtitle: "keep the eye sharp", horizon: .now),
                GoalTemplate(title: "Tokyo trip", subtitle: "", horizon: .build),
                GoalTemplate(title: "Private pilot license", subtitle: "", horizon: .dream),
            ]
        }
    }
}
