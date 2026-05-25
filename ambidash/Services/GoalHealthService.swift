import Foundation

enum GoalHealthService {
    static func status(for goal: Goal) -> GoalStatus {
        goal.computedStatus
    }

    static func summaryText(for goal: Goal) -> String {
        let days = goal.neglectDays
        switch goal.computedStatus {
        case .onTrack:
            if days == 0 {
                return "Active today"
            }
            return "Last active \(days) day\(days == 1 ? "" : "s") ago"
        case .needsAttention:
            return "No progress in \(days) days"
        case .slipping:
            return "Neglected for \(days) days"
        case .paused:
            return "Paused"
        }
    }
}
