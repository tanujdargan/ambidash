// ambidash/Services/LearningService+ActivityDigest.swift
//
// v5 feat/v5-activity-logging — the LearningService extension that detects activity PATTERNS and
// folds them into a weekly digest, on top of the data the app already logs (ActualEvent /
// EnergyCheckin / Reflection). Pure aggregation lives in `weeklyDigest(actuals:…)`; a thin
// @MainActor convenience fetches the last N days from a ModelContext.
import Foundation
import SwiftData

extension LearningService {

    /// Build the weekly digest from already-fetched activity. Pure + testable: filters to the last
    /// 7 days, tallies completion outcomes + average energy, and runs pattern detection.
    static func weeklyDigest(
        actuals: [ActualEvent],
        checkins: [EnergyCheckin],
        reflectionDayCount: Int,
        now: Date = .now
    ) -> WeeklyDigest {
        let weekAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let recent = actuals.filter { $0.date >= weekAgo && $0.date <= now }
        let recentCheckins = checkins.filter { $0.date >= weekAgo && $0.date <= now }

        let completed = recent.filter { $0.completionStatus == .completed }.count
        let partial = recent.filter { $0.completionStatus == .partial }.count
        let abandoned = recent.filter { $0.completionStatus == .abandoned }.count

        let adherence = computeAdherenceByHour(actuals: recent)
        let energyByHour = computeEnergyByHour(checkins: recentCheckins)
        let avgEnergy = recentCheckins.isEmpty
            ? nil
            : Double(recentCheckins.map(\.clampedLevel).reduce(0, +)) / Double(recentCheckins.count)

        let insights = ActivityInsights.detect(
            adherenceByHour: adherence,
            energyByHour: energyByHour,
            energySampleCount: recentCheckins.count,
            completedCount: completed,
            totalLoggedCount: recent.count,
            reflectionCount: reflectionDayCount
        )

        return WeeklyDigest(
            completedCount: completed,
            partialCount: partial,
            abandonedCount: abandoned,
            totalLogged: recent.count,
            averageEnergy: avgEnergy,
            reflectionCount: reflectionDayCount,
            insights: insights
        )
    }

    /// Convenience: fetch the last `days` of logged activity from a ModelContext and build the
    /// digest. Reflection count is the number of DISTINCT days the user reflected in the window.
    @MainActor
    static func weeklyDigest(from context: ModelContext, days: Int = 7, now: Date = .now) -> WeeklyDigest {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now)
            ?? now.addingTimeInterval(-Double(days) * 86_400)
        let actuals = (try? context.fetch(FetchDescriptor<ActualEvent>(predicate: #Predicate { $0.date >= cutoff }))) ?? []
        let checkins = (try? context.fetch(FetchDescriptor<EnergyCheckin>(predicate: #Predicate { $0.date >= cutoff }))) ?? []
        let reflections = (try? context.fetch(FetchDescriptor<Reflection>(predicate: #Predicate { $0.date >= cutoff }))) ?? []
        let reflectionDays = Set(reflections.map { Calendar.current.startOfDay(for: $0.date) }).count
        return weeklyDigest(actuals: actuals, checkins: checkins, reflectionDayCount: reflectionDays, now: now)
    }
}
