// ambidash/Views/Reflect/MonthlyReviewView.swift
import SwiftUI
import SwiftData

struct MonthlyReviewView: View {
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    private var profile: UserProfile? { profiles.first }

    private var monthPlans: [DailyPlan] {
        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        return plans.filter { $0.date >= monthAgo }
    }

    private var monthSnapshots: [IntegrationSnapshot] {
        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        return snapshots.filter { $0.date >= monthAgo }
    }

    private var skipAnalysis: SkipAnalysisService.AnalysisResult {
        SkipAnalysisService.analyze(plans: monthPlans, goals: profile?.goals ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("30-Day Deep Dive")
                    .font(.title2)
                    .fontWeight(.bold)

                if !PremiumGateService.isPremium {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("Monthly deep dives are a Premium feature")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    overviewSection
                    healthTrendsSection
                    skipAnalysisSection
                    goalTrajectorySection
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var overviewSection: some View {
        let totalActions = monthPlans.flatMap(\.actions)
        let doneCount = totalActions.filter { $0.statusRaw == "done" }.count
        let skippedCount = totalActions.filter { $0.statusRaw == "skipped" }.count

        VStack(alignment: .leading, spacing: 8) {
            Text("OVERVIEW")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            HStack(spacing: 24) {
                MonthStatColumn(value: "\(monthPlans.count)", label: "Plans Made", color: .blue)
                MonthStatColumn(value: "\(doneCount)", label: "Completed", color: .green)
                MonthStatColumn(value: "\(skippedCount)", label: "Skipped", color: .red)
                MonthStatColumn(
                    value: totalActions.isEmpty ? "—" : "\(Int(Double(doneCount) / Double(totalActions.count) * 100))%",
                    label: "Success Rate",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var healthTrendsSection: some View {
        if !monthSnapshots.isEmpty {
            let firstHalf = monthSnapshots.suffix(from: monthSnapshots.count / 2)
            let secondHalf = monthSnapshots.prefix(monthSnapshots.count / 2)

            let earlyAvgSleep = firstHalf.map(\.sleepHours).reduce(0, +) / max(Double(firstHalf.count), 1)
            let recentAvgSleep = secondHalf.map(\.sleepHours).reduce(0, +) / max(Double(secondHalf.count), 1)

            let earlyAvgScreen = firstHalf.map(\.screenTimeHours).reduce(0, +) / max(Double(firstHalf.count), 1)
            let recentAvgScreen = secondHalf.map(\.screenTimeHours).reduce(0, +) / max(Double(secondHalf.count), 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("HEALTH TRENDS (first 15d → last 15d)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                TrendRow(
                    label: "Avg Sleep",
                    before: String(format: "%.1fh", earlyAvgSleep),
                    after: String(format: "%.1fh", recentAvgSleep),
                    improved: recentAvgSleep >= earlyAvgSleep
                )
                TrendRow(
                    label: "Avg Screen",
                    before: String(format: "%.1fh", earlyAvgScreen),
                    after: String(format: "%.1fh", recentAvgScreen),
                    improved: recentAvgScreen <= earlyAvgScreen
                )
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var skipAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SKIP ANALYSIS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            Text(skipAnalysis.recommendation)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if !skipAnalysis.patterns.isEmpty {
                ForEach(skipAnalysis.patterns.prefix(3), id: \.goalDomain) { pattern in
                    HStack {
                        Text(pattern.goalDomain.displayName)
                            .font(.caption)
                        Spacer()
                        Text("\(Int(pattern.skipRate * 100))% skip rate")
                            .font(.caption)
                            .foregroundStyle(pattern.skipRate > 0.5 ? .red : pattern.skipRate > 0.3 ? .orange : .green)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var goalTrajectorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GOAL TRAJECTORY")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            let goals = profile?.goals.filter(\.isActive) ?? []
            ForEach(goals) { goal in
                HStack {
                    Image(systemName: goal.domain.icon)
                        .foregroundStyle(goal.computedStatus.color)
                        .frame(width: 20)
                    Text(goal.title)
                        .font(.subheadline)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(goal.computedStatus.label)
                            .font(.caption)
                            .foregroundStyle(goal.computedStatus.color)
                        if let streak = goal.streak, streak.bestCount > 0 {
                            Text("Best: \(streak.bestCount)d")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct MonthStatColumn: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TrendRow: View {
    let label: String
    let before: String
    let after: String
    let improved: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(before) → \(after)")
                .font(.subheadline)
                .fontWeight(.medium)
            Text(improved ? "▲" : "▼")
                .font(.caption)
                .foregroundStyle(improved ? .green : .red)
        }
    }
}
