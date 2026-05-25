import Foundation

enum PlanFormat: String, CaseIterable, Codable, Identifiable {
    case focusBlocks, singleAction, priorityList

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .focusBlocks: "Focus Blocks"
        case .singleAction: "Single Next Action"
        case .priorityList: "Priority List"
        }
    }

    var description: String {
        switch self {
        case .focusBlocks: "Time-slotted actions with reasoning. Best for structured learners."
        case .singleAction: "One action at a time. Best if you get overwhelmed easily."
        case .priorityList: "Ranked list, no strict times. Best if you're self-directed."
        }
    }
}
