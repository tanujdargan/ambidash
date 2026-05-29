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

    // F3 — type + frequency layer (all optional/defaulted; additive migration)
    var goalTypeRaw: String = ""
    var timesPerWeek: Int = 0
    var recurrenceRaw: String = GoalRecurrence.none.rawValue

    var profile: UserProfile?
    @Relationship(deleteRule: .cascade) var domainAssessment: DomainAssessment?
    @Relationship(deleteRule: .cascade) var progressEntries: [GoalProgress]
    @Relationship(deleteRule: .cascade) var streak: Streak?
    @Relationship(deleteRule: .cascade) var progressLogs: [ProgressLog] = []
    // C1 — decomposition chain: the goal's Milestone tree (year → quarter →
    // month → week). Cascade so deleting a goal removes its checkpoints.
    @Relationship(deleteRule: .cascade, inverse: \Milestone.goal) var milestones: [Milestone] = []

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

    // F3 — type + frequency accessors

    /// The goal's classification. When no type was explicitly stored (e.g. pre-F3
    /// goals), infers a sensible default on read via `GoalTypeInferenceService` so
    /// no migration write is needed. Setter persists the explicit choice.
    var goalType: GoalType {
        get {
            if let stored = GoalType(rawValue: goalTypeRaw) { return stored }
            return GoalTypeInferenceService.infer(self)
        }
        set { goalTypeRaw = newValue.rawValue }
    }

    var recurrence: GoalRecurrence {
        get { GoalRecurrence(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }

    /// Habit and recurring goals are judged by cadence/adherence rather than a
    /// deliverable or a climbing number.
    var isHabitual: Bool {
        goalType.isHabitual
    }

    /// Fraction (0...1) of this calendar week's intended cadence that has been met,
    /// derived from progress logs recorded since the start of the week. Habitual
    /// goals with no explicit `timesPerWeek` are treated as a once-this-week target.
    var adherenceThisWeek: Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
            ?? calendar.startOfDay(for: .now)
        let logsThisWeek = progressLogs.filter { $0.date >= weekStart }.count
        let target = max(timesPerWeek, 1)
        return min(max(Double(logsThisWeek) / Double(target), 0), 1)
    }
}
