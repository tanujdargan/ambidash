import Foundation

enum LifeDimension: String, CaseIterable, Codable {
    case body, mind, craft, people, wealth, adventure

    var displayName: String {
        switch self {
        case .body: "Body"
        case .mind: "Mind"
        case .craft: "Craft"
        case .people: "People"
        case .wealth: "Wealth"
        case .adventure: "Adventure"
        }
    }

    var fullName: String {
        switch self {
        case .body: "Body & Health"
        case .mind: "Mind & Character"
        case .craft: "Craft & Career"
        case .people: "People & Love"
        case .wealth: "Wealth & Freedom"
        case .adventure: "Adventure & Experience"
        }
    }
}
