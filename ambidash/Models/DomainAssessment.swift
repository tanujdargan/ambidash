import Foundation
import SwiftData

@Model
final class DomainAssessment {
    var id: UUID = UUID()
    var domainRaw: String = ""
    var answers: [String: String] = [:]
    var assessedAt: Date = Date()

    var goal: Goal?

    init(domain: GoalDomain) {
        self.id = UUID()
        self.domainRaw = domain.rawValue
        self.answers = [:]
        self.assessedAt = .now
    }

    var domain: GoalDomain {
        GoalDomain(rawValue: domainRaw) ?? .body
    }
}
