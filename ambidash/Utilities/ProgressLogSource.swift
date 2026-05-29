import Foundation

enum ProgressLogSource: String, CaseIterable, Codable, Identifiable {
    case manual, action, integration

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: "Manual"
        case .action: "Action"
        case .integration: "Integration"
        }
    }
}
