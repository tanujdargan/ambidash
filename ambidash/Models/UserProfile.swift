import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var age: Int = 0
    var lifeStage: String = ""
    var timezone: String = ""
    var scaffoldLevel: Int = 0
    var createdAt: Date = Date()
    var onboardingComplete: Bool = false

    // v4 mentor-system SCAFFOLD (not the full marketplace). Captures the user's own
    // enrollment state — opt-in mode + progress toward unlocking mentor status. Real
    // cross-user matching + a mentor/mentee link model + commission billing are
    // future work. CloudKit-additive (defaulted scalars, no migration).
    // mentorOptInRaw: "none" | "seekMatch" | "ownMentor"
    var mentorOptInRaw: String = "none"
    /// Days of progress toward unlocking the ability to become a mentor (target 30).
    var mentorProgressDays: Int = 0
    /// This user's own shareable invite code (a UUID, generated lazily). Someone you
    /// invite scans/pastes it to connect. Cross-device sync of the link needs a
    /// backend (future) — for now the code + QR generate and the connect flow works
    /// locally on each device.
    var mentorInviteCode: String = ""
    /// The peer code this user accepted (empty = not connected to anyone yet).
    var connectedPeerCode: String = ""

    @Relationship(deleteRule: .cascade) var coreAssessment: CoreAssessment?
    @Relationship(deleteRule: .cascade) var workStylePreference: WorkStylePreference?
    // FOUNDATION — the user's daily-rhythm preferences ("Your Day"). Optional +
    // cascade so it's CloudKit-safe (additive) and removed with the profile.
    @Relationship(deleteRule: .cascade) var userPreferences: UserPreferences?
    @Relationship(deleteRule: .cascade) var goals: [Goal]?

    init(name: String = "", age: Int = 0, lifeStage: String = "student") {
        self.id = UUID()
        self.name = name
        self.age = age
        self.lifeStage = lifeStage
        self.timezone = TimeZone.current.identifier
        self.scaffoldLevel = 3
        self.createdAt = .now
        self.onboardingComplete = false
    }
}
