import Foundation

enum GoalLibrary {
    struct GoalTemplate {
        let title: String
        let subtitle: String
        let horizon: GoalHorizon
    }

    static let totalCount = 52

    static func starterGoals(for domain: GoalDomain) -> [GoalTemplate] {
        switch domain {
        case .body:
            return [
                // NOW (4)
                GoalTemplate(title: "Fix sleep", subtitle: "anchor wake time, no weekend exceptions", horizon: .now),
                GoalTemplate(title: "Clean eating", subtitle: "cut the trash, build the habit", horizon: .now),
                GoalTemplate(title: "Compound lifts 3–4x/week", subtitle: "track progressive overload", horizon: .now),
                GoalTemplate(title: "Grooming locked in", subtitle: "smell good, look intentional daily", horizon: .now),
                // SOON (3)
                GoalTemplate(title: "Dressing sense", subtitle: "one audit, build 3 reliable fits", horizon: .soon),
                GoalTemplate(title: "Lean toned body", subtitle: "visible abs, no love handles, strong back", horizon: .soon),
                GoalTemplate(title: "Running — 5K baseline", subtitle: "optional from there", horizon: .soon),
            ]
        case .mind:
            return [
                // NOW (4)
                GoalTemplate(title: "Honour dad's dying wish", subtitle: "stop rushing depth for speed", horizon: .now),
                GoalTemplate(title: "Fix deep-rooted issues", subtitle: "start therapy or journaling, now", horizon: .now),
                GoalTemplate(title: "Control emotions and anger", subtitle: "in the moment", horizon: .now),
                GoalTemplate(title: "Fix oversharing", subtitle: "pause before revealing", horizon: .now),
                // SOON (5)
                GoalTemplate(title: "Build genuine self-confidence", subtitle: "and self-worth", horizon: .soon),
                GoalTemplate(title: "Balance thinking", subtitle: "not overthinking, not under-thinking", horizon: .soon),
                GoalTemplate(title: "Reading habit", subtitle: "Kindle there, build the ritual around it", horizon: .soon),
                GoalTemplate(title: "Learn to ask for help", subtitle: "you named it, it's real", horizon: .soon),
                GoalTemplate(title: "Register wins before raising the bar", subtitle: "feel what you've built", horizon: .soon),
                // BUILD (2)
                GoalTemplate(title: "Settle relationship with dad's memory", subtitle: "what he means going forward", horizon: .build),
                GoalTemplate(title: "Develop a personal philosophy", subtitle: "your non-negotiables, your worldview", horizon: .build),
            ]
        case .craft:
            return [
                // NOW (4)
                GoalTemplate(title: "Crush Amazon internship", subtitle: "get the return offer", horizon: .now),
                GoalTemplate(title: "Do hard things", subtitle: "bias toward difficulty always", horizon: .now),
                GoalTemplate(title: "Restart off the cuff challenge", subtitle: "daily, recorded, no excuses", horizon: .now),
                GoalTemplate(title: "Write deliberately", subtitle: "journal, startup copy, research clarity", horizon: .now),
                // SOON (4)
                GoalTemplate(title: "Launch startup solo", subtitle: "ship the first version", horizon: .soon),
                GoalTemplate(title: "Canadian PR process", subtitle: "start gathering docs", horizon: .soon),
                GoalTemplate(title: "Public speaking", subtitle: "command a room, not just articulate sentences", horizon: .soon),
                GoalTemplate(title: "Fellowship applications", subtitle: "Neo, Thiel, KP, Interact, On Deck", horizon: .soon),
                // BUILD (4)
                GoalTemplate(title: "Grow the startup to real traction", subtitle: "", horizon: .build),
                GoalTemplate(title: "AI research — 1–2 publications", subtitle: "make your mark", horizon: .build),
                GoalTemplate(title: "Be cracked at what you do", subtitle: "the best in every room", horizon: .build),
                GoalTemplate(title: "Canadian PR secured", subtitle: "", horizon: .build),
            ]
        case .people:
            return [
                // NOW (2)
                GoalTemplate(title: "Be more social", subtitle: "say yes more, initiate more", horizon: .now),
                GoalTemplate(title: "Go active on X", subtitle: "post to think, not to perform", horizon: .now),
                // SOON (4)
                GoalTemplate(title: "Make real friends", subtitle: "not acquaintances, actual people", horizon: .soon),
                GoalTemplate(title: "Become a gentleman", subtitle: "how you carry yourself every day", horizon: .soon),
                GoalTemplate(title: "Build deliberate network", subtitle: "5–10 exceptional people you'd call at 2am", horizon: .soon),
                GoalTemplate(title: "Decide what kind of son to be for mom", subtitle: "on your terms, with boundaries", horizon: .soon),
                // BUILD (2)
                GoalTemplate(title: "Learn to be a great partner", subtitle: "respect, effort, presence", horizon: .build),
                GoalTemplate(title: "Find the LOML", subtitle: "after foundation is solid, give her the world", horizon: .build),
            ]
        case .wealth:
            return [
                // NOW (1)
                GoalTemplate(title: "XEQT compounding", subtitle: "invest every payday, build emergency fund", horizon: .now),
                // BUILD (1)
                GoalTemplate(title: "Financial independence", subtitle: "startup or salary, doesn't matter, get there", horizon: .build),
                // DREAM (3)
                GoalTemplate(title: "Buy the Porsche 911", subtitle: "", horizon: .dream),
                GoalTemplate(title: "Buy the house", subtitle: "", horizon: .dream),
                GoalTemplate(title: "Everything else material", subtitle: "after she's happy, after you're proud", horizon: .dream),
            ]
        case .adventure:
            return [
                // NOW (2)
                GoalTemplate(title: "Keep gaming", subtitle: "don't let yourself disappear in the grind", horizon: .now),
                GoalTemplate(title: "Protect photography and videography", subtitle: "keep the eye sharp", horizon: .now),
                // SOON (1)
                GoalTemplate(title: "Get into cars, drones, RC", subtitle: "mechanical passion, hands-on discipline", horizon: .soon),
                // BUILD (4)
                GoalTemplate(title: "Tokyo trip", subtitle: "", horizon: .build),
                GoalTemplate(title: "Leh Ladakh", subtitle: "mountain roads, bikes, the whole thing", horizon: .build),
                GoalTemplate(title: "Germany — Nordschleife lap", subtitle: "", horizon: .build),
                GoalTemplate(title: "Switzerland — alpine mountain pass runs", subtitle: "", horizon: .build),
                // DREAM (2)
                GoalTemplate(title: "Private pilot license (PPL)", subtitle: "", horizon: .dream),
                GoalTemplate(title: "Type rating — Cirrus or family jet", subtitle: "", horizon: .dream),
            ]
        }
    }
}
