import Foundation

enum LifeDimension: String, CaseIterable, Codable {
    case body, mind, focus, social, growth

    var displayName: String {
        switch self {
        case .body: "Body"
        case .mind: "Mind"
        case .focus: "Focus"
        case .social: "Social"
        case .growth: "Growth"
        }
    }

    var color: String {
        switch self {
        case .body: "green"
        case .mind: "purple"
        case .focus: "blue"
        case .social: "pink"
        case .growth: "orange"
        }
    }
}
