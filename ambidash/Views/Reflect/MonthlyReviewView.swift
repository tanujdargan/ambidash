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
                    .foregroundStyle(AmbidashTheme.textPrimary)

                if !PremiumGateService.isPremium {
                    CardView {
                        VStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.title)
                                .foregroundStyle(AmbidashTheme.textTertiary)
                            Text("Monthly deep dives are a Premium feature")
                                .font(.subheadline)
                                .foregroundStyle(AmbidashTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(16)
                    }
                } else {
                    overviewSection
                    healthTrendsSection
                    skipAnalysisSection
                    goalTrajectorySection
                }
            }
            .padding()
        }
        .background(AmbidashTheme.bgBase)
    }

    @ViewBuilder
    private var overviewSection: some View {
        let totalActions = monthPlans.flatMap(\.actions)
        let doneCount = totalActions.filter { $0.statusRaw == "done" }.count
        let skippedCount = totalActions.filter { $0.statusRaw == "skipped" }.count

        CardView {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Overview")

                HStack(spacing: 24) {
                    MonthStatColumn(value: "\(monthPlans.count)", label: "Plans Made", color: AmbidashTheme.accent)
                    MonthStatColumn(value: "\(doneCount)", label: "Completed", color: AmbidashTheme.statusGood)
                    MonthStatColumn(value: "\(skippedCount)", label: "Skipped", color: AmbidashTheme.statusBad)
                    MonthStatColumn(
                        value: totalActions.isEmpty ? "—" : "\(Int(Double(doneCount) / Double(totalActions.count) * 100))%",
                        label: "Success Rate",
                        color: AmbidashTheme.mindCognitive
                    )
                }
            }
        }
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

            CardView {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Health Trends (first 15d → last 15d)")

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
            }
        }
    }

    @ViewBuilder
    private var skipAnalysisSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Skip Analysis")

                Text(skipAnalysis.recommendation)
                    .font(.subheadline)
                    .foregroundStyle(AmbidashTheme.textPrimary)

                if !skipAnalysis.patterns.isEmpty {
                    ForEach(skipAnalysis.patterns.prefix(3), id: \.goalDomain) { pattern in
                        HStack {
                            Text(pattern.goalDomain.displayName)
                                .font(.caption)
                                .foregroundStyle(AmbidashTheme.textSecondary)
                            Spacer()
                            Text("\(Int(pattern.skipRate * 100))% skip rate")
                                .font(.caption)
                                .foregroundStyle(pattern.skipRate > 0.5 ? AmbidashTheme.statusBad : pattern.skipRate > 0.3 ? AmbidashTheme.statusWarn : AmbidashTheme.statusGood)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var goalTrajectorySection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Goal Trajectory")

                let goals = profile?.goals.filter(\.isActive) ?? []
                ForEach(goals) { goal in
                    HStack {
                        Image(systemName: goal.domain.icon)
                            .foregroundStyle(goal.computedStatus.color)
                            .frame(width: 20)
                        Text(goal.title)
                            .font(.subheadline)
                            .foregroundStyle(AmbidashTheme.textPrimary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(goal.computedStatus.label)
                                .font(.caption)
                                .foregroundStyle(goal.computedStatus.color)
                            if let streak = goal.streak, streak.bestCount > 0 {
                                Text("Best: \(streak.bestCount)d")
                                    .font(.caption2)
                                    .foregroundStyle(AmbidashTheme.textSecondary)
                            }
                        }
                    }
                }
            }
        }
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
                .foregroundStyle(AmbidashTheme.textSecondary)
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
                .foregroundStyle(AmbidashTheme.textSecondary)
            Spacer()
            Text("\(before) → \(after)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(AmbidashTheme.textPrimary)
            Text(improved ? "▲" : "▼")
                .font(.caption)
                .foregroundStyle(improved ? AmbidashTheme.statusGood : AmbidashTheme.statusBad)
        }
    }
}
