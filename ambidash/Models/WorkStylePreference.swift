import Foundation
import SwiftData

@Model
final class WorkStylePreference {
    var id: UUID = UUID()
    var planFormat: String = ""
    var streaksEnabled: Bool = false
    var notificationIntensity: String = ""
    var maxActionsPerDay: Int = 0

    var profile: UserProfile?

    init(planFormat: PlanFormat = .focusBlocks) {
        self.id = UUID()
        self.planFormat = planFormat.rawValue
        self.streaksEnabled = true
        self.notificationIntensity = "moderate"
        self.maxActionsPerDay = 6
    }

    var format: PlanFormat {
        PlanFormat(rawValue: planFormat) ?? .focusBlocks
    }
}
