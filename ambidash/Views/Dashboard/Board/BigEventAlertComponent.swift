import SwiftUI
import SwiftData

/// BIG-EVENT ALERT — when a milestone deadline is 3 days away, surfaces a prominent
/// card with a countdown, suggested focus actions, and deferrable routine items. Calm
/// by default: renders nothing when no big events are imminent.
///
/// Owns a @Query for milestones (needs live due-date data) and today's plan actions.
struct BigEventAlertComponent: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Milestone.endDate) private var milestones: [Milestone]
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]

    @State private var adjustment: BigEventAdjustment?
    @State private var applied = false

    var body: some View {
        let t = tm.resolved
        Group {
            if let adjustment, !applied {
                card(adjustment, t)
            } else if applied {
                acknowledgement(t)
            } else {
                Color.clear.frame(height: 0)
            }
        }
        .animation(MotionPreference.animation(.ambidashSpring), value: adjustment?.milestone.id)
        .animation(MotionPreference.animation(.ambidashSpring), value: applied)
        .task(id: dataFingerprint) { recompute() }
    }

    // MARK: - Card

    @ViewBuilder
    private func card(_ adj: BigEventAdjustment, _ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: t.space.component) {
            header(adj, t)

            Text(adj.suggestion)
                .font(t.body(13))
                .foregroundStyle(t.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !adj.priorityActions.isEmpty {
                actionList("Focus today", adj.priorityActions, symbol: "target", t)
            }

            if !adj.deferrableActions.isEmpty {
                actionList("Can wait", adj.deferrableActions, symbol: "arrow.turn.down.right", t)
            }

            Button {
                applyAdjustment(adj)
            } label: {
                Text("Adjust my plan")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(t.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(t.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(t.accent.opacity(0.5), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
            }
            .buttonStyle(.scalePress)
            .accessibilityLabel("Adjust my plan for \(adj.milestone.title)")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Big event alert: \(adj.milestone.title)")
    }

    @ViewBuilder
    private func header(_ adj: BigEventAdjustment, _ t: ResolvedTheme) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 12))
                .foregroundStyle(t.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(adj.milestone.title)
                    .font(t.body(13))
                    .fontWeight(.semibold)
                    .foregroundStyle(t.ink)
                Text(adj.countdownPhrase)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.muted)
            }
            Spacer(minLength: 4)
        }
    }

    @ViewBuilder
    private func actionList(_ label: String, _ items: [String], symbol: String, _ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 9))
                    .foregroundStyle(t.muted)
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(t.muted)
            }
            ForEach(items, id: \.self) { item in
                Text("  \(item)")
                    .font(t.body(12))
                    .foregroundStyle(t.ink)
            }
        }
    }

    // MARK: - Acknowledgement

    @ViewBuilder
    private func acknowledgement(_ t: ResolvedTheme) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 13))
                .foregroundStyle(t.accent)
            Text("Plan adjusted — deferrable items moved to tomorrow.")
                .font(t.body(12))
                .foregroundStyle(t.muted)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    // MARK: - Actions

    private func applyAdjustment(_ adj: BigEventAdjustment) {
        Haptics.success()
        guard let todayPlan = todayPlan else { applied = true; return }

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
        let actions = todayPlan.actions ?? []

        for action in actions {
            if adj.deferrableActions.contains(action.title) {
                MultiDayPlannerService.move(action, to: tomorrow, in: plans, context: modelContext)
            }
        }
        try? modelContext.save()

        applied = true
        adjustment = nil

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(MotionPreference.animation(.ambidashSpring)) { applied = false }
        }
    }

    // MARK: - Compute

    private var todayPlan: DailyPlan? {
        let cal = Calendar.current
        return plans.first { cal.isDateInToday($0.date) }
    }

    private var dataFingerprint: String {
        "\(milestones.count)-\(plans.count)-\(milestones.first?.endDate.timeIntervalSince1970 ?? 0)"
    }

    private func recompute() {
        let todayActions = todayPlan?.actions ?? []
        adjustment = MultiDayPlannerService.bigEventPlanAdjustments(
            milestones: milestones,
            todayActions: todayActions
        )
    }
}
