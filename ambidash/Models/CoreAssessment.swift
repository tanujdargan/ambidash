import Foundation
import SwiftData

@Model
final class CoreAssessment {
    var id: UUID
    var cognitiveStyle: String
    var peakEnergyTime: String
    var overwhelmResponse: String
    var adhdScore: Int
    var anxietyScore: Int
    var sleepQualitySelfRating: Int
    var lifeSatisfaction: [String: Int]
    var topValues: [String]
    var biggestBlocker: String
    var accountabilityPreference: String
    var assessedAt: Date

    var profile: UserProfile?

    init() {
        self.id = UUID()
        self.cognitiveStyle = ""
        self.peakEnergyTime = ""
        self.overwhelmResponse = ""
        self.adhdScore = 0
        self.anxietyScore = 0
        self.sleepQualitySelfRating = 0
        self.lifeSatisfaction = [:]
        self.topValues = []
        self.biggestBlocker = ""
        self.accountabilityPreference = ""
        self.assessedAt = .now
    }
}
