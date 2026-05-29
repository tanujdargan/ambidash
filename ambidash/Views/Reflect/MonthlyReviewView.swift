// ambidash/Views/Reflect/MonthlyReviewView.swift
import SwiftUI
import SwiftData

struct MonthlyReviewView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    private var profile: UserProfile? { profiles.first }

    /// Drives the AddMilestoneView sheet for setting/editing a month objective.
    @State private var commitmentContext: CommitmentContext?

    /// Wraps the goal + (optional) milestone being edited so a single sheet item
    /// drives both "set a fresh month objective" and "edit the existing one".
    private struct CommitmentContext: Identifiable {
        let id = UUID()
        let goal: Goal
        let editing: Milestone?
    }

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
        let t = tm.resolved
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("30-Day Deep Dive")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(t.ink)

                if !PremiumGateService.isPremium {
                    CardView {
                        VStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.title)
                                .foregroundStyle(t.faint)
                            Text("Monthly deep dives are a Premium feature")
                                .font(.subheadline)
                                .foregroundStyle(t.muted)
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

                // Forward planning: set this month's objectives. Rendered for ALL
                // users (premium and free) — committing the month is a core
                // planning feature and is intentionally not behind the gate that
                // covers the retrospective deep-dive analytics above.
                planThisMonthSection
            }
            .padding()
        }
        .background(tm.resolved.bg)
        .sheet(item: $commitmentContext) { ctx in
            AddMilestoneView(goal: ctx.goal, parent: nil, editing: ctx.editing)
        }
    }

    // MARK: - Plan this month (forward-looking)

    /// A writable "plan this month" surface analogous to WeeklyReviewView's
    /// "Plan this week": each active goal shows its current month Milestone (the
    /// monthly objective) with target/progress + status, plus an inline control
    /// to set or edit it. Reuses the existing AddMilestoneView sheet.
    @ViewBuilder
    private var planThisMonthSection: some View {
        let t = tm.resolved
        let goals = profile?.goals.filter(\.isActive) ?? []

        CardView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader(title: "Plan this month")
                    Text("What each goal asks of you this month.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(t.faint)
                }

                if goals.isEmpty {
                    Text("No active goals to commit to yet.")
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(t.muted)
                } else {
                    ForEach(goals) { goal in
                        commitmentRow(goal: goal, milestone: WeeklyPlanService.currentMonthMilestone(for: goal), t: t)
                    }
                }
            }
        }
    }

    /// One goal's monthly objective row: title + (objective line / status /
    /// progress) and a Set/Edit control.
    @ViewBuilder
    private func commitmentRow(goal: Goal, milestone: Milestone?, t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(goal.horizon.dotColor).frame(width: 6, height: 6)
                Text(goal.title)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(t.ink)
                    .lineLimit(1)
                Spacer()
                if let milestone {
                    StatusDot(status: milestone.status)
                }
            }

            if let milestone {
                Text(milestone.title)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(t.ink2)
                    .lineLimit(2)

                if milestone.hasTarget {
                    DataRowView(
                        label: "Progress",
                        value: "\(MetricFormat.number(milestone.currentValue ?? 0)) / \(MetricFormat.number(milestone.targetValue ?? 0))",
                        unit: milestone.unit.isEmpty ? nil : milestone.unit
                    )
                    commitmentProgressBar(milestone, t: t)
                }

                HStack {
                    Spacer()
                    PillButton(label: "Edit objective") {
                        Haptics.light()
                        commitmentContext = CommitmentContext(goal: goal, editing: milestone)
                    }
                }
            } else {
                HStack {
                    Text("No objective set.")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(t.faint)
                    Spacer()
                    PillButton(label: "Set objective") {
                        Haptics.light()
                        let created = WeeklyPlanService.ensureMonthMilestone(for: goal, context: modelContext)
                        try? modelContext.save()
                        commitmentContext = CommitmentContext(goal: goal, editing: created)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { t.hair.frame(height: 0.5) }
    }

    /// A thin track + fill at the objective's percentComplete, mirroring the
    /// roadmap's milestone bar styling.
    @ViewBuilder
    private func commitmentProgressBar(_ milestone: Milestone, t: ResolvedTheme) -> some View {
        let pct = milestone.percentComplete
        let fill: Color = {
            switch milestone.status {
            case .onTrack: return t.ok
            case .needsAttention: return t.accent
            case .slipping: return t.danger
            case .paused: return t.ink
            }
        }()
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1).fill(t.hair)
                RoundedRectangle(cornerRadius: 1)
                    .fill(fill)
                    .frame(width: max(2, geo.size.width * pct))
            }
        }
        .frame(height: 6)
    }

    @ViewBuilder
    private var overviewSection: some View {
        let t = tm.resolved
        let totalActions = monthPlans.flatMap(\.actions)
        let doneCount = totalActions.filter { $0.statusRaw == "done" }.count
        let skippedCount = totalActions.filter { $0.statusRaw == "skipped" }.count

        CardView {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Overview")

                HStack(spacing: 24) {
                    MonthStatColumn(value: "\(monthPlans.count)", label: "Plans Made", color: t.accent)
                    MonthStatColumn(value: "\(doneCount)", label: "Completed", color: t.ok)
                    MonthStatColumn(value: "\(skippedCount)", label: "Skipped", color: t.danger)
                    MonthStatColumn(
                        value: totalActions.isEmpty ? "—" : "\(Int(Double(doneCount) / Double(totalActions.count) * 100))%",
                        label: "Success Rate",
                        color: AmbidashTheme.dimensionColor(for: .mind)
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
        let t = tm.resolved
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Skip Analysis")

                Text(skipAnalysis.recommendation)
                    .font(.subheadline)
                    .foregroundStyle(t.ink)

                if !skipAnalysis.patterns.isEmpty {
                    ForEach(skipAnalysis.patterns.prefix(3), id: \.goalDomain) { pattern in
                        HStack {
                            Text(pattern.goalDomain.displayName)
                                .font(.caption)
                                .foregroundStyle(t.muted)
                            Spacer()
                            Text("\(Int(pattern.skipRate * 100))% skip rate")
                                .font(.caption)
                                .foregroundStyle(pattern.skipRate > 0.5 ? t.danger : pattern.skipRate > 0.3 ? t.accent : t.ok)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var goalTrajectorySection: some View {
        let t = tm.resolved
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
                            .foregroundStyle(t.ink)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(goal.computedStatus.label)
                                .font(.caption)
                                .foregroundStyle(goal.computedStatus.color)
                            if let streak = goal.streak, streak.bestCount > 0 {
                                Text("Best: \(streak.bestCount)d")
                                    .font(.caption2)
                                    .foregroundStyle(t.muted)
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

    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TrendRow: View {
    let label: String
    let before: String
    let after: String
    let improved: Bool

    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(t.muted)
            Spacer()
            Text("\(before) → \(after)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(t.ink)
            Text(improved ? "▲" : "▼")
                .font(.caption)
                .foregroundStyle(improved ? t.ok : t.danger)
        }
    }
}
