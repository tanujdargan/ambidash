import Foundation
import SwiftData

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
        goal.progressLogs.append(log)
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
}
