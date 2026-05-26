// ambidash/Views/Reflect/WeeklyReviewView.swift
import SwiftUI
import SwiftData

struct WeeklyReviewView: View {
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    private var profile: UserProfile? { profiles.first }

    private var weekPlans: [DailyPlan] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return plans.filter { $0.date >= weekAgo }
    }

    private var weekSnapshots: [IntegrationSnapshot] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        return snapshots.filter { $0.date >= weekAgo }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Weekly Review")
                    .font(.title2)
                    .fontWeight(.bold)

                // Action Stats
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACTIONS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    let totalActions = weekPlans.flatMap(\.actions)
                    let doneCount = totalActions.filter { $0.statusRaw == "done" }.count
                    let skippedCount = totalActions.filter { $0.statusRaw == "skipped" }.count

                    HStack(spacing: 24) {
                        StatColumn(value: "\(doneCount)", label: "Completed", color: .green)
                        StatColumn(value: "\(skippedCount)", label: "Skipped", color: .red)
                        StatColumn(value: "\(weekPlans.count)", label: "Plans Made", color: .blue)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Health Averages
                if !weekSnapshots.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HEALTH AVERAGES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        let avgSleep = weekSnapshots.map(\.sleepHours).reduce(0, +) / Double(weekSnapshots.count)
                        let avgScreen = weekSnapshots.map(\.screenTimeHours).reduce(0, +) / Double(weekSnapshots.count)
                        let avgSteps = weekSnapshots.map { Double($0.steps) }.reduce(0, +) / Double(weekSnapshots.count)

                        HStack(spacing: 24) {
                            StatColumn(value: String(format: "%.1fh", avgSleep), label: "Avg Sleep", color: avgSleep >= 7 ? .green : .orange)
                            StatColumn(value: String(format: "%.1fh", avgScreen), label: "Avg Screen", color: avgScreen <= 3 ? .green : .red)
                            StatColumn(value: String(format: "%.0f", avgSteps), label: "Avg Steps", color: avgSteps >= 8000 ? .green : .orange)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Goal Health
                VStack(alignment: .leading, spacing: 8) {
                    Text("GOAL HEALTH")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.5)

                    let goals = profile?.goals.filter(\.isActive) ?? []
                    ForEach(goals) { goal in
                        HStack {
                            Circle()
                                .fill(goal.computedStatus.color)
                                .frame(width: 8, height: 8)
                            Text(goal.title)
                                .font(.subheadline)
                            Spacer()
                            Text(goal.computedStatus.label)
                                .font(.caption)
                                .foregroundStyle(goal.computedStatus.color)
                            if let streak = goal.streak, streak.currentCount > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                    Text("\(streak.currentCount)d")
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
            .padding()
        }
    }
}

private struct StatColumn: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
