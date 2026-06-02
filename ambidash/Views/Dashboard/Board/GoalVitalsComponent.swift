import SwiftUI
import SwiftData

/// v4 goal-tied vitals: per-goal "are you succeeding?" at a glance. Each active
/// goal shows its computed status (On Track / Needs Attention / Needs Time)
/// straight up, so the dashboard's vitals are tied to the GOALS, not abstract.
/// Non-punitive: a slipping goal renders in the muted `deferred` token, never red —
/// it's a gentle "needs time", never a failure flag.
struct GoalVitalsComponent: View {
    @Environment(ThemeManager.self) private var tm

    @Query(filter: #Predicate<Goal> { $0.isActive }, sort: \Goal.priority)
    private var goals: [Goal]

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: t.space.component) {
            SectionLabel(title: "Goal Vitals")

            if goals.isEmpty {
                Text("Add goals and you'll see, at a glance, whether each is on track.")
                    .font(t.body(12))
                    .foregroundStyle(t.faint)
            } else {
                VStack(spacing: t.space.tight) {
                    ForEach(goals.prefix(6)) { goal in
                        goalRow(goal, t)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("component.goalVitals")
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal, _ t: ResolvedTheme) -> some View {
        let status = goal.computedStatus
        let (label, color) = display(status, t)
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(goal.title)
                .font(t.body(14))
                .foregroundStyle(t.ink)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(color.opacity(0.14))
                .clipShape(Capsule())
        }
    }

    /// Non-punitive mapping: status → (label, theme-token color). Slipping uses the
    /// muted `deferred` token, NOT danger/red.
    private func display(_ status: GoalStatus, _ t: ResolvedTheme) -> (String, Color) {
        switch status {
        case .onTrack:        return ("ON TRACK", t.ok)
        case .needsAttention: return ("NEEDS ATTENTION", t.accent)
        case .slipping:       return ("NEEDS TIME", t.deferred)
        case .paused:         return ("PAUSED", t.muted)
        }
    }
}
