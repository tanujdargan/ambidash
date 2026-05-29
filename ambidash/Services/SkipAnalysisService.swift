// ambidash/Services/SkipAnalysisService.swift
import Foundation
import SwiftData

enum SkipAnalysisService {
    struct SkipPattern {
        let goalDomain: GoalDomain
        let skipRate: Double
        let totalActions: Int
        let skippedActions: Int
        let commonTimeSlots: [String]
    }

    struct AnalysisResult {
        let patterns: [SkipPattern]
        let overallSkipRate: Double
        let mostSkippedDomain: GoalDomain?
        let recommendation: String
        /// #14 — tallies of the captured skip reasons (label → count), most
        /// frequent first. Empty until users start recording reasons.
        let reasonCounts: [(reason: String, count: Int)]
        /// #14 — the single most common captured skip reason, if any.
        let topReason: String?
    }

    static func analyze(plans: [DailyPlan], goals: [Goal]) -> AnalysisResult {
        let allActions = plans.flatMap { $0.actions ?? [] }
        guard !allActions.isEmpty else {
            return AnalysisResult(patterns: [], overallSkipRate: 0, mostSkippedDomain: nil, recommendation: "Not enough data yet.", reasonCounts: [], topReason: nil)
        }

        let skippedActions = allActions.filter { $0.statusRaw == "skipped" }
        let overallRate = Double(skippedActions.count) / Double(allActions.count)

        // #14 — categorize the REAL captured skip reasons now that TodayView's
        // SkipReasonSheet stores them. Bucket by the leading reason label (text
        // before any " — " note), so "Not enough time — meeting" and "Not enough
        // time" tally together.
        var reasonTally: [String: Int] = [:]
        for action in skippedActions {
            guard let raw = action.skipReason?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { continue }
            let bucket = raw.components(separatedBy: " — ").first?.trimmingCharacters(in: .whitespaces) ?? raw
            reasonTally[bucket, default: 0] += 1
        }
        let reasonCounts = reasonTally
            .sorted { $0.value > $1.value }
            .map { (reason: $0.key, count: $0.value) }
        let topReason = reasonCounts.first?.reason

        var domainSkips: [GoalDomain: (total: Int, skipped: Int, timeSlots: [String])] = [:]

        let goalMap: [UUID: Goal] = goals.reduce(into: [:]) { $0[$1.id] = $1 }

        for action in allActions {
            // Resolve to a goal by lineage (goalID) first; fall back to title-match.
            var resolvedDomain: GoalDomain? = nil
            if let goalID = action.goalID, let goal = goalMap[goalID] {
                resolvedDomain = goal.domain
            } else {
                for goal in goals {
                    let temps = PlanGenerator.templates(for: goal.domain)
                    if temps.contains(where: { $0.0 == action.title }) {
                        resolvedDomain = goal.domain
                        break
                    }
                }
            }

            if let domain = resolvedDomain {
                var entry = domainSkips[domain] ?? (total: 0, skipped: 0, timeSlots: [])
                entry.total += 1
                if action.statusRaw == "skipped" {
                    entry.skipped += 1
                    entry.timeSlots.append(action.timeSlot)
                }
                domainSkips[domain] = entry
            }
        }

        let patterns = domainSkips.map { domain, data in
            SkipPattern(
                goalDomain: domain,
                skipRate: data.total > 0 ? Double(data.skipped) / Double(data.total) : 0,
                totalActions: data.total,
                skippedActions: data.skipped,
                commonTimeSlots: Array(Set(data.timeSlots)).sorted()
            )
        }.sorted { $0.skipRate > $1.skipRate }

        let mostSkipped = patterns.first(where: { $0.skipRate > 0.5 })?.goalDomain

        // #14 — when we have captured reasons, let the most common one sharpen the
        // recommendation so it speaks to *why* things slip, not just *that* they do.
        let reasonHint = topReason.map { " Most often you noted: “\($0).”" } ?? ""

        let recommendation: String
        if overallRate > 0.6 {
            recommendation = "You're skipping more than half your actions. Consider reducing your daily plan to fewer, more realistic actions." + reasonHint
        } else if overallRate > 0.3 {
            recommendation = "Some goals are being consistently skipped. Consider whether they're still priorities or if the actions need rescheduling." + reasonHint
        } else if let worst = patterns.first, worst.skipRate > 0.5 {
            recommendation = "Your \(worst.goalDomain.displayName) actions get skipped often. Try scheduling them at a different time." + reasonHint
        } else {
            recommendation = "Your completion rate is solid. Keep it up."
        }

        return AnalysisResult(
            patterns: patterns,
            overallSkipRate: overallRate,
            mostSkippedDomain: mostSkipped,
            recommendation: recommendation,
            reasonCounts: reasonCounts,
            topReason: topReason
        )
    }
}
