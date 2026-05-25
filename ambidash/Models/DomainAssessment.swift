import Foundation
import SwiftData

@Model
final class DomainAssessment {
    var id: UUID
    var domainRaw: String
    var answers: [String: String]
    var assessedAt: Date

    var goal: Goal?

    init(domain: GoalDomain) {
        self.id = UUID()
        self.domainRaw = domain.rawValue
        self.answers = [:]
        self.assessedAt = .now
    }

    var domain: GoalDomain {
        GoalDomain(rawValue: domainRaw) ?? .fitness
    }
}
