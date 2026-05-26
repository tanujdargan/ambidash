// ambidash/Views/Reflect/WeeklyReviewView.swift
import SwiftUI
import SwiftData

struct WeeklyReviewView: View {
    @Environment(ThemeManager.self) private var tm
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
        let t = tm.resolved
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Weekly Review")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(t.ink)

                // Action Stats
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Actions")

                        let totalActions = weekPlans.flatMap(\.actions)
                        let doneCount = totalActions.filter { $0.statusRaw == "done" }.count
                        let skippedCount = totalActions.filter { $0.statusRaw == "skipped" }.count

                        HStack(spacing: 24) {
                            StatColumn(value: "\(doneCount)", label: "Completed", color: t.ok)
                            StatColumn(value: "\(skippedCount)", label: "Skipped", color: t.danger)
                            StatColumn(value: "\(weekPlans.count)", label: "Plans Made", color: t.accent)
                        }
                    }
                }

                // Health Averages
                if !weekSnapshots.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Health Averages")

                            let avgSleep = weekSnapshots.map(\.sleepHours).reduce(0, +) / Double(weekSnapshots.count)
                            let avgScreen = weekSnapshots.map(\.screenTimeHours).reduce(0, +) / Double(weekSnapshots.count)
                            let avgSteps = weekSnapshots.map { Double($0.steps) }.reduce(0, +) / Double(weekSnapshots.count)

                            HStack(spacing: 24) {
                                StatColumn(value: String(format: "%.1fh", avgSleep), label: "Avg Sleep", color: avgSleep >= 7 ? t.ok : t.accent)
                                StatColumn(value: String(format: "%.1fh", avgScreen), label: "Avg Screen", color: avgScreen <= 3 ? t.ok : t.danger)
                                StatColumn(value: String(format: "%.0f", avgSteps), label: "Avg Steps", color: avgSteps >= 8000 ? t.ok : t.accent)
                            }
                        }
                    }
                }

                // Goal Health
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Goal Health")

                        let goals = profile?.goals.filter(\.isActive) ?? []
                        ForEach(goals) { goal in
                            HStack {
                                Circle()
                                    .fill(goal.computedStatus.color)
                                    .frame(width: 8, height: 8)
                                Text(goal.title)
                                    .font(.subheadline)
                                    .foregroundStyle(t.ink)
                                Spacer()
                                Text(goal.computedStatus.label)
                                    .font(.caption)
                                    .foregroundStyle(goal.computedStatus.color)
                                if let streak = goal.streak, streak.currentCount > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "flame.fill")
                                            .font(.caption2)
                                            .foregroundStyle(t.accent)
                                        Text("\(streak.currentCount)d")
                                            .font(.caption2)
                                            .foregroundStyle(t.muted)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(tm.resolved.bg)
    }
}

private struct StatColumn: View {
    let value: String
    let label: String
    let color: Color

    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity)
    }
}
