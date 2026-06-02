import SwiftUI
import SwiftData

struct LifeMapView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Goal> { $0.isActive }, sort: \Goal.priority) private var goals: [Goal]
    @State private var selectedGoal: Goal?

    /// When embedded (e.g. inside GoalListView's board mode) the standalone
    /// header and close affordance are suppressed; the host supplies that chrome.
    var embedded: Bool = false

    // Layout constants
    private let cellWidth: CGFloat = 150
    private let labelColumnWidth: CGFloat = 96
    private let cellSpacing: CGFloat = 8

    private var goalsByDomainAndHorizon: [GoalDomain: [GoalHorizon: [Goal]]] {
        groupGoalsByDomainAndHorizon(goals)
    }

    var body: some View {
        Group {
            if embedded {
                board(tm.resolved)
            } else {
                standalone(tm.resolved)
            }
        }
        .sheet(item: $selectedGoal) { goal in
            GoalQuickSheet(goal: goal)
        }
    }

    @ViewBuilder
    private func standalone(_ t: ResolvedTheme) -> some View {
        ZStack(alignment: .topTrailing) {
            t.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header(t)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                    .fadeSlideIn(delay: 0)

                board(t)
            }

            // Close affordance (mirrors sheet dismissal pattern)
            Button {
                Haptics.selection()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(t.muted)
                    .padding(10)
            }
            .accessibilityLabel("Close life map")
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
    }

    // MARK: - Header

    @ViewBuilder
    private func header(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LIFE MAP")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(t.muted)

            Text("Everything, at once.")
                .font(t.heading(28))
                .tracking(-0.3)
                .foregroundStyle(t.ink)
        }
    }

    // MARK: - Board

    @ViewBuilder
    private func board(_ t: ResolvedTheme) -> some View {
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(alignment: .leading, spacing: cellSpacing) {
                horizonHeaderRow(t)

                ForEach(Array(GoalDomain.allCases.enumerated()), id: \.element.id) { index, domain in
                    domainRow(domain, t: t)
                        .staggeredAppear(index: index)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Horizon header row

    @ViewBuilder
    private func horizonHeaderRow(_ t: ResolvedTheme) -> some View {
        HStack(alignment: .bottom, spacing: cellSpacing) {
            // Spacer cell aligned over the pillar-label column
            Color.clear
                .frame(width: labelColumnWidth, height: 1)

            ForEach(GoalHorizon.allCases) { horizon in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Circle().fill(horizon.dotColor).frame(width: 6, height: 6)
                        Text(horizon.displayName.uppercased())
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(t.muted)
                    }
                    Text(horizon.timeframe)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
                .frame(width: cellWidth, alignment: .leading)
            }
        }
    }

    // MARK: - Domain row

    @ViewBuilder
    private func domainRow(_ domain: GoalDomain, t: ResolvedTheme) -> some View {
        let rowGoals = goalsByDomainAndHorizon[domain] ?? [:]
        let domainCount = rowGoals.values.reduce(0) { $0 + $1.count }

        HStack(alignment: .top, spacing: cellSpacing) {
            // Left pillar label
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: domain.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(t.muted)

                Text(domain.displayName.components(separatedBy: " ").first ?? domain.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(t.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(domainCount)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
            .frame(width: labelColumnWidth, alignment: .leading)
            .padding(.top, 10)

            // 4 horizon cells
            ForEach(GoalHorizon.allCases) { horizon in
                cell(domain: domain, horizon: horizon, goals: rowGoals[horizon] ?? [], t: t)
            }
        }
    }

    // MARK: - Cell

    @ViewBuilder
    private func cell(domain: GoalDomain, horizon: GoalHorizon, goals: [Goal], t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if goals.isEmpty {
                Text("—")
                    .font(t.body(14))
                    .foregroundStyle(t.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            } else {
                ForEach(goals) { goal in
                    GoalCellChip(goal: goal, theme: t) {
                        Haptics.selection()
                        selectedGoal = goal
                    }
                }
            }
        }
        .frame(width: cellWidth, alignment: .topLeading)
        .frame(minHeight: 64, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(horizon.dotColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(t.hair, lineWidth: 0.5)
        )
    }

    // MARK: - Grouping

    private func groupGoalsByDomainAndHorizon(_ goals: [Goal]) -> [GoalDomain: [GoalHorizon: [Goal]]] {
        var result: [GoalDomain: [GoalHorizon: [Goal]]] = [:]
        for goal in goals {
            result[goal.domain, default: [:]][goal.horizon, default: []].append(goal)
        }
        return result
    }
}

// MARK: - Goal Cell Chip

private struct GoalCellChip: View {
    let goal: Goal
    let theme: ResolvedTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 6) {
                Circle()
                    .fill(goal.computedStatus.color)
                    .frame(width: 5, height: 5)
                    .padding(.top, 5)

                Text(goal.title)
                    .font(theme.body(12))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }
}
