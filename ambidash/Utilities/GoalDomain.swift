import Foundation

enum GoalDomain: String, CaseIterable, Codable, Identifiable {
    case fitness, cognitive, social, career, language, screenTime, financial

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fitness: "Fitness & Body"
        case .cognitive: "Cognitive & Learning"
        case .social: "Social & Communication"
        case .career: "Career & Building"
        case .language: "Language"
        case .screenTime: "Screen Time"
        case .financial: "Financial"
        }
    }

    var dimension: LifeDimension {
        switch self {
        case .fitness: .body
        case .cognitive, .language: .mind
        case .screenTime: .focus
        case .social: .social
        case .career, .financial: .growth
        }
    }

    var icon: String {
        switch self {
        case .fitness: "figure.run"
        case .cognitive: "brain.head.profile"
        case .social: "person.2"
        case .career: "briefcase"
        case .language: "character.bubble"
        case .screenTime: "iphone"
        case .financial: "dollarsign.circle"
        }
    }
}
