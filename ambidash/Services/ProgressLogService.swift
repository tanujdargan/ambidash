import Foundation
import SwiftData
import WidgetKit

enum ProgressLogService {
    /// Record a measurable progress update by setting an absolute new value.
    /// Creates a ProgressLog, updates the goal's currentValue/lastProgressDate,
    /// bumps the streak, and fires a loss-framing nudge on regression.
    @discardableResult
    static func record(
        goal: Goal,
        newValue: Double,
        source: ProgressLogSource = .manual,
        note: String = "",
        context: ModelContext
    ) -> ProgressLog {
        let previousValue = goal.currentValue
        let amount = newValue - previousValue
        return apply(
            goal: goal,
            amount: amount,
            newValue: newValue,
            previousValue: previousValue,
            source: source,
            note: note,
            context: context
        )
    }

    /// Record a measurable progress update by adding an increment to currentValue.
    @discardableResult
    static func record(
        goal: Goal,
        amount: Double,
        source: ProgressLogSource = .manual,
        note: String = "",
        context: ModelContext
    ) -> ProgressLog {
        let previousValue = goal.currentValue
        let newValue = previousValue + amount
        return apply(
            goal: goal,
            amount: amount,
            newValue: newValue,
            previousValue: previousValue,
            source: source,
            note: note,
            context: context
        )
    }

    /// Records a non-measurable check-in: marks today as touched, advances the
    /// streak (cadence-aware for habitual goals), and writes a zero-amount log so
    /// weekly adherence reflects the touch. Used by Today completions and the
    /// goal detail/quick sheets.
    static func logCheckIn(
        goal: Goal,
        source: ProgressLogSource = .manual,
        context: ModelContext
    ) {
        goal.lastProgressDate = .now
        if goal.isHabitual {
            let log = ProgressLog(amount: 0, resultingValue: goal.currentValue, source: source)
            context.insert(log)
            log.goal = goal
            goal.streak?.recordActivity(forCadence: goal.timesPerWeek)
        } else {
            goal.streak?.recordActivity()
        }
        refreshWidget(context: context)
    }

    private static func apply(
        goal: Goal,
        amount: Double,
        newValue: Double,
        previousValue: Double,
        source: ProgressLogSource,
        note: String,
        context: ModelContext
    ) -> ProgressLog {
        let log = ProgressLog(amount: amount, resultingValue: newValue, note: note, source: source)
        context.insert(log)
        log.goal = goal
        goal.currentValue = newValue
        goal.lastProgressDate = .now
        goal.streak?.recordActivity()

        if isRegression(goal: goal, previousValue: previousValue, newValue: newValue) {
            let unitLabel = goal.unit.isEmpty ? goal.title : goal.unit
            NotificationService.scheduleLossFramingNudge(
                metric: unitLabel,
                currentValue: formatted(newValue, unit: goal.unit),
                previousValue: formatted(previousValue, unit: goal.unit)
            )
        }

        refreshWidget(context: context)
        return log
    }

    /// A regression is movement away from the target: a decrease for `.increase`
    /// goals, or an increase for `.decrease` goals.
    private static func isRegression(goal: Goal, previousValue: Double, newValue: Double) -> Bool {
        guard goal.metricEnabled else { return false }
        switch goal.direction {
        case .increase: return newValue < previousValue
        case .decrease: return newValue > previousValue
        }
    }

    private static func formatted(_ value: Double, unit: String) -> String {
        let number = value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
        return unit.isEmpty ? number : "\(number) \(unit)"
    }

    // MARK: - Widget refresh

    /// Rebuilds the rich App Group snapshot the widget renders (composite score,
    /// today's goal-linked tasks, multi-goal at-a-glance) from the live data
    /// store, then forces the widget to reload. Called at the end of the central
    /// logging path so every manual / action / Siri log keeps the widget honest.
    /// Best-effort and failure-tolerant: a fetch or encode failure never blocks
    /// a log from being recorded.
    private static func refreshWidget(context: ModelContext) {
        WidgetSnapshotWriter.write(context: context)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Widget snapshot writer

/// Serializes the data the widget extension renders into App Group UserDefaults.
/// The widget owns the matching decode shape (ambidash-widget/WidgetSharedData.swift);
/// the two communicate purely via this JSON because the app's CloudKit-backed
/// SwiftData container can't be co-opened from the extension.
enum WidgetSnapshotWriter {
    private static let appGroup = "group.com.ambidash.app"
    private static let snapshotKey = "widget_snapshot_v1"

    // Mirror of the widget's decode structs. Field names == JSON keys, so the
    // widget's WidgetVitalsSnapshot/WidgetTask/WidgetGoalSummary decode 1:1.
    private struct WidgetTaskDTO: Codable {
        var id: UUID
        var title: String
        var timeSlot: String
        var durationMinutes: Int
        var goalID: UUID?
        var goalTitle: String
        var domainRaw: String
        var isDone: Bool
    }

    private struct GoalSummary: Codable {
        var id: UUID
        var title: String
        var domainRaw: String
        var statusRaw: String
        var neglectDays: Int
        var percentComplete: Double?
        var streakCount: Int
    }

    private struct Snapshot: Codable {
        var generatedAt: Date
        var compositeScore: Int
        var pillarsActive: Int
        var topGoalTitle: String
        var topGoalStatus: String
        var tasks: [WidgetTaskDTO]
        var goals: [GoalSummary]
    }

    static func write(context: ModelContext) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }

        // Active goals, by priority.
        let goalDescriptor = FetchDescriptor<Goal>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.priority)]
        )
        let activeGoals = (try? context.fetch(goalDescriptor)) ?? []

        // Today's plan (most recent matching today's calendar day).
        let planDescriptor = FetchDescriptor<DailyPlan>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let plans = (try? context.fetch(planDescriptor)) ?? []
        let todayPlan = plans.first { Calendar.current.isDateInToday($0.date) }

        // Composite score reuses the same calculators the dashboard uses.
        let snapshotDescriptor = FetchDescriptor<IntegrationSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let latestSnapshot = (try? context.fetch(snapshotDescriptor))?.first
        let dimensionScores = DimensionScoreCalculator.scores(from: activeGoals, snapshot: latestSnapshot)
        let composite = PulseScoreCalculator.pulse(from: dimensionScores)

        // Today's pending, goal-linked tasks (sorted by time slot, capped).
        let tasks: [WidgetTaskDTO] = (todayPlan?.actions ?? [])
            .filter { $0.statusRaw == "pending" }
            .sorted { $0.timeSlot < $1.timeSlot }
            .prefix(6)
            .map { action in
                let goal = action.goalID.flatMap { id in activeGoals.first { $0.id == id } }
                return WidgetTaskDTO(
                    id: action.id,
                    title: action.title,
                    timeSlot: action.timeSlot,
                    durationMinutes: action.durationMinutes,
                    goalID: action.goalID,
                    goalTitle: action.goalTitleSnapshot ?? goal?.title ?? "",
                    domainRaw: goal?.domain.rawValue ?? "",
                    isDone: false
                )
            }

        let goals: [GoalSummary] = activeGoals.prefix(6).map { goal in
            GoalSummary(
                id: goal.id,
                title: goal.title,
                domainRaw: goal.domain.rawValue,
                statusRaw: goal.computedStatus.rawValue,
                neglectDays: goal.neglectDays,
                percentComplete: goal.hasTarget ? goal.percentComplete : nil,
                streakCount: goal.streak?.currentCount ?? 0
            )
        }

        let topGoal = activeGoals.max(by: { $0.neglectDays < $1.neglectDays })
        let snapshot = Snapshot(
            generatedAt: .now,
            compositeScore: composite,
            pillarsActive: activeGoals.count,
            topGoalTitle: topGoal?.title ?? "Open AmbiDash",
            topGoalStatus: topGoal.map { GoalHealthService.summaryText(for: $0) } ?? "",
            tasks: tasks,
            goals: goals
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
    }
}
