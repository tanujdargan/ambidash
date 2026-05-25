import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var name: String
    var age: Int
    var lifeStage: String
    var timezone: String
    var scaffoldLevel: Int
    var createdAt: Date
    var onboardingComplete: Bool

    @Relationship(deleteRule: .cascade) var coreAssessment: CoreAssessment?
    @Relationship(deleteRule: .cascade) var workStylePreference: WorkStylePreference?
    @Relationship(deleteRule: .cascade) var goals: [Goal]

    init(name: String = "", age: Int = 0, lifeStage: String = "student") {
        self.id = UUID()
        self.name = name
        self.age = age
        self.lifeStage = lifeStage
        self.timezone = TimeZone.current.identifier
        self.scaffoldLevel = 3
        self.createdAt = .now
        self.onboardingComplete = false
        self.goals = []
    }
}
