import Foundation

enum GoalDomain: String, CaseIterable, Codable, Identifiable {
    case body, mind, craft, people, wealth, adventure

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .body: "Body & Health"
        case .mind: "Mind & Character"
        case .craft: "Craft & Career"
        case .people: "People & Love"
        case .wealth: "Wealth & Freedom"
        case .adventure: "Adventure & Experience"
        }
    }

    var dimension: LifeDimension {
        switch self {
        case .body: .body
        case .mind: .mind
        case .craft: .craft
        case .people: .people
        case .wealth: .wealth
        case .adventure: .adventure
        }
    }

    var icon: String {
        switch self {
        case .body: "figure.strengthtraining.traditional"
        case .mind: "brain.head.profile"
        case .craft: "hammer.fill"
        case .people: "heart.fill"
        case .wealth: "banknote.fill"
        case .adventure: "airplane"
        }
    }
}
