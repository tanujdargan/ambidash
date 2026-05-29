// ambidash/Views/Reflect/QuarterlyReviewView.swift
import SwiftUI
import SwiftData

/// A read-then-act quarterly review: for each active goal it surfaces the
/// current-quarter checkpoint (current/target value + on-track/slipping status),
/// and offers a "Set next quarter" action that creates the next-period Milestone —
/// a closed loop, unlike the read-only Weekly / Monthly reviews. Reuses
/// MonthlyReviewView's CardView scaffolding plus DataRowView + StatusDot.
struct QuarterlyReviewView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }
    private var goals: [Goal] { profile?.goals?.filter(\.isActive) ?? [] }

    /// Label for the quarter containing `now`, e.g. "Q2 2026".
    private var currentQuarterLabel: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: .now)
        let year = calendar.component(.year, from: .now)
        let q = (month - 1) / 3 + 1
        return "Q\(q) \(year)"
    }

    var body: some View {
        let t = tm.resolved
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("90-Day Checkpoints")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(t.ink)
                    Text(currentQuarterLabel + " · where each goal stands")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(t.muted)
                }

                if goals.isEmpty {
                    emptyState(t)
                } else {
                    ForEach(goals) { goal in
                        goalCard(goal, t: t)
                    }
                }
            }
            .padding()
        }
        .background(t.bg)
    }

    @ViewBuilder
    private func goalCard(_ goal: Goal, t: ResolvedTheme) -> some View {
        let quarterMilestone = MilestoneGenerator.currentMilestone(for: goal, period: .quarter)

        CardView {
            VStack(alignment: .leading, spacing: 12) {
                // Goal header
                HStack(spacing: 8) {
                    Circle().fill(goal.horizon.dotColor).frame(width: 6, height: 6)
                    Text(goal.title)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(t.ink)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: goal.domain.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(t.muted)
                }

                if let milestone = quarterMilestone {
                    quarterDetail(milestone, t: t)
                } else {
                    Text("No checkpoint set for this quarter.")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(t.faint)
                }

                // Closed-loop action: create next quarter's checkpoint.
                HStack {
                    Spacer()
                    PillButton(label: "Set next quarter", primary: true) {
                        setNextQuarter(for: goal, from: quarterMilestone)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func quarterDetail(_ milestone: Milestone, t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                StatusDot(status: milestone.status)
                Text(milestone.title)
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(t.ink2)
                    .lineLimit(2)
                Spacer()
                Text(milestone.status.label.lowercased())
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(statusColor(milestone.status, t))
            }

            VStack(spacing: 0) {
                if milestone.hasTarget {
                    let unitLabel = milestone.unit.isEmpty ? nil : milestone.unit
                    DataRowView(
                        label: "Current",
                        value: MetricFormat.number(milestone.currentValue ?? 0),
                        unit: unitLabel
                    )
                    DataRowView(
                        label: "Target",
                        value: MetricFormat.number(milestone.targetValue ?? 0),
                        unit: unitLabel
                    )
                    DataRowView(
                        label: "Complete",
                        value: "\(Int((milestone.percentComplete * 100).rounded()))",
                        unit: "%"
                    )
                } else {
                    DataRowView(
                        label: "Status",
                        value: milestone.isCompleted ? "Done" : milestone.status.label
                    )
                }
                DataRowView(
                    label: "Ends",
                    value: milestone.endDate.formatted(.dateTime.month(.abbreviated).day())
                )
            }
        }
    }

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        CardView {
            VStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.title)
                    .foregroundStyle(t.faint)
                Text("No active goals to review.")
                    .font(.subheadline)
                    .foregroundStyle(t.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
        }
    }

    // MARK: - Closed loop

    /// Creates the next-quarter checkpoint for `goal`. The new window is the
    /// calendar quarter after `previous` (or after the current quarter when there
    /// is none), matched to `MilestoneGenerator.window` so it aligns with
    /// auto-generated checkpoints.
    private func setNextQuarter(for goal: Goal, from previous: Milestone?) {
        Haptics.success()
        let calendar = Calendar.current

        // Anchor: just past the end of the previous quarter checkpoint, or the
        // start of the quarter after the current one.
        let anchor: Date
        if let previous {
            anchor = previous.endDate.addingTimeInterval(1)
        } else {
            let currentWindow = MilestoneGenerator.window(for: .quarter, containing: .now)
            anchor = currentWindow.end.addingTimeInterval(1)
        }
        let window = MilestoneGenerator.window(for: .quarter, containing: anchor, calendar: calendar)

        // Dedupe: bail if a quarter checkpoint already covers this window. Without
        // this guard, repeated taps pile up identical next-quarter nodes because
        // currentMilestone (which feeds `previous`) only ever returns the
        // window-containing-now node, never the future one we just created.
        if (goal.milestones ?? []).contains(where: { $0.period == .quarter && $0.startDate == window.start }) {
            return
        }

        let milestone = Milestone(
            title: "Next-quarter checkpoint: \(goal.title)",
            period: .quarter,
            startDate: window.start,
            endDate: window.end,
            detail: "Planned in the quarterly review.",
            targetValue: previous?.targetValue,
            currentValue: previous?.targetValue == nil ? nil : 0,
            unit: previous?.unit ?? goal.unit,
            sortIndex: (goal.milestones ?? []).count
        )
        modelContext.insert(milestone)
        milestone.goal = goal
        MilestoneProgressService.refreshStatus(of: milestone)
        try? modelContext.save()
    }

    private func statusColor(_ status: GoalStatus, _ t: ResolvedTheme) -> Color {
        switch status {
        case .onTrack: return t.ok
        case .needsAttention: return t.accent
        case .slipping: return t.danger
        case .paused: return t.faint
        }
    }
}
