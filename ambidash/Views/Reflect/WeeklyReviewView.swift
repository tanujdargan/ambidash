import SwiftUI
import SwiftData
import Charts

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
        return snapshots.filter { $0.date >= weekAgo }.sorted { $0.date < $1.date }
    }

    var body: some View {
        let t = tm.resolved
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(title: "This week")
                    Text("Honest charts. No badges.")
                        .font(.system(size: 28, weight: .regular, design: .serif))
                        .tracking(-0.3)
                        .foregroundStyle(t.ink)
                }

                // Action completion chart
                actionChart(t)

                // Sleep trend chart
                if !weekSnapshots.isEmpty {
                    sleepChart(t)
                }

                // Goal health
                goalHealthSection(t)

                // Mentor note
                MentorNote(
                    text: "You finished what you started on \(weekPlans.filter { plan in plan.actions.allSatisfy { $0.statusRaw == "done" } }.count) of \(weekPlans.count) days. Patterns are more honest than intentions.",
                    signature: "M."
                )
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .background(t.bg)
    }

    @ViewBuilder
    private func actionChart(_ t: ResolvedTheme) -> some View {
        let totalActions = weekPlans.flatMap(\.actions)
        let doneCount = totalActions.filter { $0.statusRaw == "done" }.count
        let skippedCount = totalActions.filter { $0.statusRaw == "skipped" }.count
        let pendingCount = totalActions.count - doneCount - skippedCount

        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Actions")

            // Bar chart data
            let data: [(String, Int, Color)] = [
                ("Done", doneCount, t.ok),
                ("Skipped", skippedCount, t.danger),
                ("Pending", pendingCount, t.faint),
            ]

            Chart(data, id: \.0) { item in
                BarMark(
                    x: .value("Count", item.1),
                    y: .value("Status", item.0)
                )
                .foregroundStyle(item.2)
                .cornerRadius(3)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.muted)
                }
            }
            .frame(height: 80)

            // Summary
            HStack(spacing: 16) {
                Text("\(doneCount)")
                    .font(.system(size: 32, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(t.ink)
                + Text(" / \(totalActions.count)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(t.faint)

                Spacer()

                if totalActions.count > 0 {
                    Text("\(Int(Double(doneCount) / Double(totalActions.count) * 100))% completion")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(t.muted)
                }
            }
        }
        .padding(16)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    @ViewBuilder
    private func sleepChart(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel(title: "Sleep")
                Spacer()
                Text("7 D")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
            }

            Chart(weekSnapshots, id: \.id) { snap in
                LineMark(
                    x: .value("Day", snap.date, unit: .day),
                    y: .value("Hours", snap.sleepHours)
                )
                .foregroundStyle(t.ink)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                AreaMark(
                    x: .value("Day", snap.date, unit: .day),
                    y: .value("Hours", snap.sleepHours)
                )
                .foregroundStyle(t.ink.opacity(0.06))

                PointMark(
                    x: .value("Day", snap.date, unit: .day),
                    y: .value("Hours", snap.sleepHours)
                )
                .foregroundStyle(t.ink)
                .symbolSize(16)
            }
            .chartYScale(domain: 0...12)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(t.muted)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 4, 8, 12]) { value in
                    AxisGridLine().foregroundStyle(t.hair)
                    AxisValueLabel()
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
            }
            .frame(height: 140)

            // Average
            let avg = weekSnapshots.map(\.sleepHours).reduce(0, +) / max(Double(weekSnapshots.count), 1)
            HStack {
                Text("\(String(format: "%.1f", avg))")
                    .font(.system(size: 24, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(t.ink)
                Text("hr avg")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(t.muted)
                Spacer()
                Text(avg >= 7 ? "on target" : "below 7hr target")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(avg >= 7 ? t.ok : t.danger)
            }
        }
        .padding(16)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    @ViewBuilder
    private func goalHealthSection(_ t: ResolvedTheme) -> some View {
        let goals = profile?.goals.filter(\.isActive) ?? []

        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(title: "Goal health")

            ForEach(goals) { goal in
                HStack(spacing: 10) {
                    Circle().fill(goal.horizon.dotColor).frame(width: 6, height: 6)

                    Text(goal.title)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundStyle(t.ink)
                        .lineLimit(1)

                    Spacer()

                    Text(goal.computedStatus.label.lowercased())
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(t.muted)

                    if let streak = goal.streak, streak.currentCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(t.accent)
                            Text("\(streak.currentCount)d")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(t.faint)
                        }
                    }
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { t.hair.frame(height: 0.5) }
            }
        }
        .padding(16)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }
}
