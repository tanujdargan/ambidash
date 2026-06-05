import SwiftUI
import SwiftData

struct GoalListView: View {
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]
    @Query(sort: \Goal.priority) private var allGoals: [Goal]
    @State private var showAddGoal = false
    @State private var selectedGoal: Goal?
    @State private var detailGoal: Goal?
    @State private var searchText = ""
    @State private var filterPillar: GoalDomain?

    private enum GoalViewMode: Hashable { case list, board, byPillar }
    @State private var viewMode: GoalViewMode = .list

    private var profile: UserProfile? { profiles.first }
    private var goals: [Goal] { allGoals }

    private var filteredGoals: [Goal] {
        var result = goals
        if let pillar = filterPillar {
            result = result.filter { $0.domain == pillar }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.subtitle.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    /// Goals filtered by SEARCH only, ignoring the single-pillar filter. The
    /// .byPillar grouping already separates pillars into their own sections, so
    /// honoring the pillar filter there would collapse the overview to one
    /// redundant group. Pillar view groups these so every populated pillar shows.
    private var searchFilteredGoals: [Goal] {
        guard !searchText.isEmpty else { return goals }
        return goals.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                if goals.isEmpty {
                    emptyState(t)
                } else {
                    goalContent(t)
                }
            }
            // This screen draws its own large custom header, like DashboardView.
            // A `.toolbar` with no `.navigationTitle` makes the system nav bar
            // render at an indeterminate/collapsed height with a transparent
            // background, and the custom header lays out UNDERNEATH it (the reported
            // "content hidden behind the nav bar"). Hide the system bar entirely and
            // host the "+" inline in the header instead. NavigationStack is retained
            // because `.navigationDestination` still needs it.
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddGoal) {
                AddGoalView()
            }
            .sheet(item: $selectedGoal) { goal in
                GoalQuickSheet(goal: goal)
            }
            // Drill-in to the full GoalDetailView (per-goal 14-day sparkline +
            // roadmap). Triggered by the trailing chevron affordance on each row,
            // distinct from the quick-glance sheet opened by tapping the row body.
            .navigationDestination(item: $detailGoal) { goal in
                GoalDetailView(goal: goal)
            }
        }
    }

    @ViewBuilder
    private func goalContent(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — custom large title with an inline "+" add affordance, hosted
            // here because the system navigation bar is hidden (see the
            // .toolbar(.hidden) above). Mirrors DashboardView's inline-header pattern.
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR GOALS")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(t.muted)

                    Text("As you've named them.")
                        .font(t.heading(28))
                        .tracking(-0.3)
                        .foregroundStyle(t.ink)
                }
                Spacer(minLength: 8)
                Button { showAddGoal = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                        .foregroundStyle(t.ink)
                }
                .accessibilityLabel("Add goal")
                .accessibilityIdentifier("goals.add")
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .fadeSlideIn(delay: 0)

            // Search + pillar filters apply to the list and the pillar overview
            // (both render from `filteredGoals`); the board runs its own @Query
            // and ignores them, so hide these controls only in board mode.
            if viewMode != .board {
                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(t.faint)
                    TextField("Search goals…", text: $searchText)
                        .font(.system(size: 13))
                        .foregroundStyle(t.ink)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(t.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(t.hair, lineWidth: 0.5))
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
                .fadeSlideIn(delay: 0.05)

                // Pillar filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        FilterChip(label: "All", isSelected: filterPillar == nil, theme: t) {
                            filterPillar = nil
                        }
                        ForEach(GoalDomain.allCases) { domain in
                            FilterChip(label: domain.displayName.components(separatedBy: " ").first ?? domain.displayName, isSelected: filterPillar == domain, theme: t) {
                                filterPillar = (filterPillar == domain) ? nil : domain
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                }
                .padding(.bottom, 6)
            }

            // View mode toggle
            HStack(spacing: 4) {
                ForEach([GoalViewMode.list, .board, .byPillar], id: \.self) { mode in
                    let isSelected = viewMode == mode
                    Button {
                        Haptics.selection()
                        viewMode = mode
                    } label: {
                        Image(systemName: icon(for: mode))
                            .font(.system(size: 11))
                            .foregroundStyle(isSelected ? t.bg : t.muted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? t.ink : .clear)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? .clear : t.hair, lineWidth: 0.5)
                            )
                    }
                    .accessibilityLabel(label(for: mode))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)

            // Content
            switch viewMode {
            case .board:
                LifeMapView(embedded: true)
            case .byPillar:
                pillarContent(t)
            case .list:
                listContent(t)
            }
        }
    }

    private func icon(for mode: GoalViewMode) -> String {
        switch mode {
        case .list: return "list.bullet"
        case .board: return "square.grid.2x2"
        case .byPillar: return "square.stack.3d.up"
        }
    }

    private func label(for mode: GoalViewMode) -> String {
        switch mode {
        case .list: return "List view"
        case .board: return "Board view"
        case .byPillar: return "Pillar view"
        }
    }

    // MARK: - Pillar view (relocated from the dashboard)

    /// Active goals that pass the current search/pillar filter, grouped by pillar.
    /// This is the goals-by-pillar overview that used to live on the dashboard:
    /// for each populated pillar, a header (icon + name + count + status
    /// breakdown) above a horizontal strip of tappable goal chips. Goal chips
    /// drill into GoalDetailView via GoalStripView's existing navigation.
    private var populatedDomains: [GoalDomain] {
        let active = searchFilteredGoals.filter(\.isActive)
        return GoalDomain.allCases.filter { domain in
            active.contains { $0.domain == domain }
        }
    }

    @ViewBuilder
    private func pillarContent(_ t: ResolvedTheme) -> some View {
        let active = searchFilteredGoals.filter(\.isActive)
        ScrollView {
            if populatedDomains.isEmpty {
                Text("No goals match.")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(t.faint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: t.space.component) {
                    ForEach(Array(populatedDomains.enumerated()), id: \.element) { index, domain in
                        let domainGoals = active.filter { $0.domain == domain }
                            .sorted { $0.priority < $1.priority }
                        VStack(alignment: .leading, spacing: 8) {
                            pillarHeader(domain, goals: domainGoals, t: t)
                                .padding(.horizontal, 22)
                            // GoalStripView already pads ±22 so its chips scroll
                            // edge-to-edge; leave it unpadded here.
                            GoalStripView(goals: domainGoals)
                        }
                        .staggeredAppear(index: index)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
    }

    @ViewBuilder
    private func pillarHeader(_ domain: GoalDomain, goals: [Goal], t: ResolvedTheme) -> some View {
        let onTrack = goals.filter { $0.computedStatus == .onTrack }.count
        let attention = goals.filter { $0.computedStatus == .needsAttention }.count
        let slipping = goals.filter { $0.computedStatus == .slipping }.count

        HStack(spacing: 8) {
            Image(systemName: domain.icon)
                .font(.system(size: 12))
                .foregroundStyle(t.muted)
            Text(domain.dimension.displayName)
                .font(t.heading(13))
                .foregroundStyle(t.ink)
            Text("\(goals.count)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(t.faint)
            Spacer()
            HStack(spacing: 8) {
                if onTrack > 0 { statusCount(.onTrack, count: onTrack, t: t) }
                if attention > 0 { statusCount(.needsAttention, count: attention, t: t) }
                if slipping > 0 { statusCount(.slipping, count: slipping, t: t) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(domain.dimension.displayName): \(goals.count) goals, \(onTrack) on track, \(attention) need attention, \(slipping) slipping")
    }

    @ViewBuilder
    private func statusCount(_ status: GoalStatus, count: Int, t: ResolvedTheme) -> some View {
        HStack(spacing: 3) {
            StatusDot(status: status)
                .scaleEffect(0.7)
                .frame(width: 6, height: 6)
            Text("\(count)")
                .font(.system(size: 10, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(t.muted)
        }
    }

    @ViewBuilder
    private func listContent(_ t: ResolvedTheme) -> some View {
        let active = filteredGoals.filter(\.isActive)
        let retired = filteredGoals.filter { !$0.isActive }

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Grouped by horizon
                ForEach(GoalHorizon.allCases, id: \.self) { horizon in
                    let horizonGoals = active.filter { $0.horizon == horizon }
                    if !horizonGoals.isEmpty {
                        horizonSection(horizon, goals: horizonGoals, t: t)
                    }
                }

                // Quietly retired
                if !retired.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .firstTextBaseline) {
                            SectionLabel(title: "Quietly retired")
                            Spacer()
                            Text("\(retired.count)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(t.faint)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 22)
                        .padding(.bottom, 10)

                        VStack(spacing: 0) {
                            ForEach(retired) { goal in
                                goalRowEntry(goal, dotColor: t.faint, t: t, retired: true)
                            }
                        }
                        .padding(.horizontal, 22)
                    }
                }

                // Mentor card
                if active.count > 3 {
                    mentorCard(activeCount: active.count, retiredCount: retired.count, t: t)
                        .padding(.horizontal, 22)
                        .padding(.top, 22)
                        .fadeSlideIn(delay: 0.2)
                }
            }
            .padding(.bottom, 100)
        }
    }

    @ViewBuilder
    private func horizonSection(_ horizon: GoalHorizon, goals: [Goal], t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Circle().fill(horizon.dotColor).frame(width: 6, height: 6)
                    SectionLabel(title: horizon.displayName)
                }
                Text("· \(horizon.timeframe)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
                Spacer()
                Text("\(goals.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
            .padding(.horizontal, 22)
            .padding(.top, 20)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                    goalRowEntry(goal, dotColor: horizon.dotColor, t: t)
                        .staggeredAppear(index: index)
                }
            }
            .padding(.horizontal, 22)
        }
    }

    /// One list entry: the row body taps to the quick-glance sheet, while a
    /// trailing chevron drills into the full GoalDetailView (sparkline + roadmap).
    @ViewBuilder
    private func goalRowEntry(_ goal: Goal, dotColor: Color, t: ResolvedTheme, retired: Bool = false) -> some View {
        HStack(spacing: 4) {
            Button {
                Haptics.selection()
                selectedGoal = goal
            } label: {
                goalRow(goal, dotColor: dotColor, t: t, retired: retired)
            }
            .buttonStyle(.scalePress)

            Button {
                Haptics.selection()
                detailGoal = goal
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(t.faint)
                    .padding(.leading, 4)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open details for \(goal.title)")
        }
        .overlay(alignment: .bottom) { t.hair.frame(height: 0.5) }
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal, dotColor: Color, t: ResolvedTheme, retired: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: goal.goalType.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(retired ? t.faint : t.muted)
                Text(goal.title)
                    .font(t.heading(17))
                    .strikethrough(retired, color: t.faint)
                    .foregroundStyle(retired ? t.faint : t.ink)
            }

            if goal.hasTarget {
                Text("\(MetricFormat.number(goal.currentValue)) / \(MetricFormat.value(goal.targetValue, unit: goal.unit))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.muted)
            } else if goal.isHabitual {
                Text(AdherenceFormat.compact(for: goal))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.muted)
            } else if !goal.subtitle.isEmpty {
                Text(goal.subtitle)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.muted)
            } else {
                Text(GoalHealthService.summaryText(for: goal))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.muted)
            }

            if !retired {
                if goal.hasTarget {
                    TargetProgressBar(goal: goal, maxWidth: 200, showCaption: false)
                } else if goal.isHabitual {
                    AdherenceBar(goal: goal, maxWidth: 200, showCaption: false)
                } else {
                    // Mirror the actual scoring: non-measurable goals are judged by
                    // the STEP-FUNCTION neglect band (≤1d:90, ≤3d:75, ≤5d:55,
                    // ≤7d:40, else decaying), not a linear recency ramp. Fill to the
                    // band value so the bar matches DimensionScoreCalculator.
                    let progress = Double(DimensionScoreCalculator.neglectBandScore(forDays: goal.neglectDays)) / 100.0
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1).fill(t.hair)
                            RoundedRectangle(cornerRadius: 1).fill(t.ink).frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 2)
                    .frame(maxWidth: 200, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(retired ? 0.45 : 1)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func mentorCard(activeCount: Int, retiredCount: Int, t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\"You have \(activeCount) active goals. The honest number you can act on this week is two, maybe three. Pick them — I won't decide for you.\"")
                .font(.system(size: 16, weight: .regular, design: .serif))
                .italic()
                .lineSpacing(3)
                .foregroundStyle(t.ink)

            Text("— Mentor, every Sunday")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(t.muted)
        }
        .padding(16)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
    }

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        EmptyStateView(
            icon: "target",
            title: "No goals yet.",
            subtitle: "Tap + to name what matters.",
            action: { showAddGoal = true },
            actionLabel: "Add a goal"
        )
        .fadeSlideIn(delay: 0.1)
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let theme: ResolvedTheme
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? theme.bg : theme.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? theme.ink : .clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? .clear : theme.hair, lineWidth: 0.5)
                )
        }
    }
}

// MARK: - F3 shared goal-type / adherence helpers
// `AdherenceFormat` moved to Utilities/AdherenceFormat.swift so the shared,
// cross-platform MentorPromptBuilder service can use it on macOS too (this view
// file is iOS-only and excluded from the mac target).

/// A small labeled pill showing a goal's `GoalType`.
struct GoalTypeChip: View {
    let type: GoalType
    let theme: ResolvedTheme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 9))
            Text(type.displayName.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.8)
        }
        .foregroundStyle(theme.muted)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(theme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(theme.hair, lineWidth: 0.5))
    }
}

/// A thin weekly-adherence gauge for habitual goals, mirroring TargetProgressBar's
/// look. The fill represents the fraction of this week's cadence already met.
struct AdherenceBar: View {
    @Environment(ThemeManager.self) private var tm
    let goal: Goal
    var maxWidth: CGFloat = 200
    var showCaption: Bool = true

    var body: some View {
        let t = tm.resolved
        let adherence = goal.adherenceThisWeek
        let fillColor: Color = adherence >= 1.0 ? t.ok : (adherence >= 0.5 ? t.ink : t.muted)

        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1).fill(t.hair)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(fillColor)
                        .frame(width: max(2, geo.size.width * adherence))
                }
            }
            .frame(height: 6)
            .frame(maxWidth: maxWidth, alignment: .leading)

            if showCaption {
                Text(AdherenceFormat.fraction(for: goal))
                    .font(.system(size: 10, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(t.muted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Adherence \(AdherenceFormat.fraction(for: goal))")
    }
}
