import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var title: String
    var domainRaw: String
    var priority: Int
    var statusRaw: String
    var createdAt: Date
    var lastProgressDate: Date
    var isActive: Bool
    var horizonRaw: String
    var subtitle: String

    // F2 — measurable target layer (all optional/defaulted; additive migration)
    var metricEnabled: Bool = false
    var unit: String = ""
    var baselineValue: Double = 0
    var targetValue: Double = 0
    var currentValue: Double = 0
    var directionRaw: String = MetricDirection.increase.rawValue

    var profile: UserProfile?
    @Relationship(deleteRule: .cascade) var domainAssessment: DomainAssessment?
    @Relationship(deleteRule: .cascade) var progressEntries: [GoalProgress]
    @Relationship(deleteRule: .cascade) var streak: Streak?
    @Relationship(deleteRule: .cascade) var progressLogs: [ProgressLog] = []

    init(title: String, domain: GoalDomain, priority: Int) {
        self.id = UUID()
        self.title = title
        self.domainRaw = domain.rawValue
        self.priority = priority
        self.statusRaw = GoalStatus.onTrack.rawValue
        self.createdAt = .now
        self.lastProgressDate = .now
        self.isActive = true
        self.horizonRaw = GoalHorizon.now.rawValue
        self.subtitle = ""
        self.progressEntries = []
    }

    var domain: GoalDomain {
        GoalDomain(rawValue: domainRaw) ?? .body
    }

    var status: GoalStatus {
        get { GoalStatus(rawValue: statusRaw) ?? .onTrack }
        set { statusRaw = newValue.rawValue }
    }

    var neglectDays: Int {
        Calendar.current.dateComponents([.day], from: lastProgressDate, to: .now).day ?? 0
    }

    var horizon: GoalHorizon {
        get { GoalHorizon(rawValue: horizonRaw) ?? .now }
        set { horizonRaw = newValue.rawValue }
    }

    var computedStatus: GoalStatus {
        if !isActive { return .paused }
        let days = neglectDays
        if days <= 3 { return .onTrack }
        if days <= 7 { return .needsAttention }
        return .slipping
    }

    // F2 — measurable target accessors
    var direction: MetricDirection {
        get { MetricDirection(rawValue: directionRaw) ?? .increase }
        set { directionRaw = newValue.rawValue }
    }

    var hasTarget: Bool {
        metricEnabled && targetValue != baselineValue
    }

    var percentComplete: Double {
        guard metricEnabled, targetValue != baselineValue else { return 0 }
        let fraction: Double
        switch direction {
        case .increase:
            fraction = (currentValue - baselineValue) / (targetValue - baselineValue)
        case .decrease:
            fraction = (baselineValue - currentValue) / (baselineValue - targetValue)
        }
        return min(max(fraction, 0), 1)
    }
}
