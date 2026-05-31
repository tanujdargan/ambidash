import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var manager = IntegrationManager()
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query(filter: #Predicate<Goal> { $0.isActive }, sort: \Goal.priority) private var activeGoals: [Goal]
    // Recency-ordered active goals for the "3 latest goals" section. Sorting on
    // the stored `lastProgressDate` (bumped by ProgressLogService on every log,
    // check-in, and completed PlannedAction) keeps this list reactive: completing
    // an action during the day re-orders the trio live. createdAt is the natural
    // fallback ordering since a goal's lastProgressDate is set at creation.
    @Query(filter: #Predicate<Goal> { $0.isActive }, sort: \Goal.lastProgressDate, order: .reverse) private var recentlyActiveGoals: [Goal]
    @State private var showSettings = false
    @State private var showLifeMap = false
    // Tap-a-score → honest breakdown sheet. Nil while dismissed.
    @State private var scoreBreakdown: ScoreBreakdownTarget?

    private var profile: UserProfile? { profiles.first }
    private var todaySnapshot: IntegrationSnapshot? { snapshots.first }
    private var yesterdaySnapshot: IntegrationSnapshot? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        return snapshots.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    private var goals: [Goal] { activeGoals }

    /// The three most-recently-active goals, by recency of progress activity.
    /// Re-orders live as actions complete (the underlying @Query sorts on the
    /// stored lastProgressDate, which ProgressLogService bumps on each touch).
    private var latestGoals: [Goal] { Array(recentlyActiveGoals.prefix(3)) }

    private var dimensionScores: [LifeDimension: Int] {
        DimensionScoreCalculator.scores(from: goals, snapshot: todaySnapshot)
    }
    private var compositeScore: Int {
        PulseScoreCalculator.pulse(from: dimensionScores)
    }
    private var streakSummary: StreakService.StreakSummary {
        StreakService.summary(for: goals)
    }
    private var todayPlan: DailyPlan? {
        plans.first { Calendar.current.isDateInToday($0.date) }
    }

    /// Real 14-day composite history aggregated from persisted GoalProgress,
    /// terminating at the live composite. Replaces the former hardcoded mock.
    private var compositeHistory: [Double] {
        CompositeHistoryCalculator.dailyComposite(
            from: goals,
            days: 14,
            todayComposite: compositeScore
        )
    }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: t.space.section) {
                        // 1. Header (date + serif subtitle + settings gear)
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)).uppercased())
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .tracking(1.6)
                                    .foregroundStyle(t.muted)

                                Text(greeting)
                                    .font(t.heading(28))
                                    .tracking(-0.3)
                                    .foregroundStyle(t.ink)
                            }
                            Spacer()
                            Button { showLifeMap = true } label: {
                                Image(systemName: "tablecells")
                                    .font(.system(size: 16))
                                    .foregroundStyle(t.muted)
                            }
                            .accessibilityLabel("Life map")
                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 16))
                                    .foregroundStyle(t.muted)
                            }
                            .accessibilityLabel("Settings")
                        }

                        // 2. Composite score + sparkline — tap for an honest
                        // breakdown of how the composite is averaged.
                        Button {
                            Haptics.selection()
                            scoreBreakdown = .composite
                        } label: {
                            HStack(alignment: .bottom, spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    SectionLabel(title: "Composite")
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("\(compositeScore)")
                                            .font(.system(size: 56, design: .monospaced))
                                            .monospacedDigit()
                                            .tracking(-2)
                                            .foregroundStyle(t.ink)
                                        Text("/100")
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundStyle(t.faint)
                                    }
                                }
                                Spacer()
                                SparklineView(values: compositeHistory, width: 120, height: 48)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .scaleOnPress()
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Composite score: \(compositeScore) out of 100. Tap for breakdown.")
                        .fadeSlideIn(delay: 0)

                        // 3. Arc gauges in 3-col grid — each taps to its
                        // dimension's per-goal score breakdown.
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 18) {
                            ForEach(Array(LifeDimension.allCases.enumerated()), id: \.element) { index, dim in
                                Button {
                                    Haptics.selection()
                                    scoreBreakdown = .dimension(dim)
                                } label: {
                                    ArcGauge(
                                        value: Double(dimensionScores[dim] ?? 50) / 100.0,
                                        size: 86,
                                        strokeWidth: 3.5,
                                        label: dim.displayName
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .scaleOnPress()
                                .staggeredAppear(index: index)
                            }
                        }

                        // 3b. The three most-recently-active goals. The full
                        // goals-by-pillar overview now lives under the Goals tab
                        // (GoalListView · Pillar mode); the dashboard surfaces just
                        // the live trio so completing actions through the day keeps
                        // the freshest work in view.
                        latestGoalsSection(t)

                        // 4. Mentor surfaced
                        InsightCardView(goals: goals, snapshot: todaySnapshot)
                            .fadeSlideIn(delay: 0.1)

                        // 5. Today, narrow
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Today, narrow")
                            if let plan = todayPlan, !(plan.actions ?? []).isEmpty {
                                let topActions = (plan.actions ?? []).sorted { $0.timeSlot < $1.timeSlot }.prefix(3)
                                ForEach(Array(topActions), id: \.id) { action in
                                    DataRowView(label: action.title, value: action.timeSlot, unit: "\(action.durationMinutes)m")
                                }
                            } else {
                                DataRowView(label: "Free time", value: "\(todaySnapshot?.calendarFreeMinutes ?? 0)", unit: "min")
                                DataRowView(label: "Sleep", value: String(format: "%.1f", todaySnapshot?.sleepHours ?? 0), unit: "hr")
                                DataRowView(label: "Steps", value: "\(todaySnapshot?.steps ?? 0)")
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
                    .padding(.bottom, 100)
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $scoreBreakdown) { target in
                ScoreBreakdownCard(
                    target: target,
                    goals: goals,
                    snapshot: todaySnapshot,
                    dimensionScores: dimensionScores,
                    compositeScore: compositeScore
                )
                .environment(tm)
            }
            .fullScreenCover(isPresented: $showLifeMap) {
                LifeMapView()
                    .environment(tm)
                    .environment(\.modelContext, modelContext)
            }
            .task {
                await manager.requestAllPermissions()
                await manager.refreshTodaySnapshot(in: modelContext)
                if !IntegrationManager.skipPermissions {
                    await NotificationService.requestPermission()
                    NotificationService.scheduleDailyReminder()
                    NotificationService.scheduleMorningPlan()
                    // Review-ritual reminders (idempotent: each removes its pending
                    // request by stable identifier before re-adding), safe per appear.
                    StreakService.scheduleWeeklyReviewReminder()
                    StreakService.scheduleMonthlyReviewReminder()
                    StreakService.scheduleQuarterlyReviewReminder()
                }
                StreakService.scheduleWarnings(for: goals)
                StreakService.scheduleDriftNudges(for: goals)
                if let profile {
                    if let newLevel = ScaffoldingService.shouldUpdateLevel(for: profile) {
                        profile.scaffoldLevel = newLevel.rawValue
                        try? modelContext.save()
                    }
                }
                updateWidgetData()
                SpotlightService.indexGoals(goals)
                for goal in goals {
                    GoalProgressTracker.recordDaily(goal: goal, context: modelContext)
                }
                try? modelContext.save()
                // Cloud sync (push + pull with conflict resolution)
                await SyncService.fullSync(context: modelContext, profile: profile)
            }
            .refreshable {
                await manager.refreshTodaySnapshot(in: modelContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await manager.refreshTodaySnapshot(in: modelContext)
                    }
                }
            }
        }
        .preferredColorScheme(tm.isDark ? .dark : .light)
    }

    /// The three most-recently-active goals as compact tappable cards. Each card
    /// drills into GoalDetailView via the existing navigation (the richer
    /// tap-to-expand detail card is a later pass). The trio re-orders live as the
    /// day progresses because `latestGoals` is fed by a recency-sorted @Query.
    @ViewBuilder
    private func latestGoalsSection(_ t: ResolvedTheme) -> some View {
        if !latestGoals.isEmpty {
            VStack(alignment: .leading, spacing: t.space.component) {
                HStack(alignment: .firstTextBaseline) {
                    SectionLabel(title: "Latest goals")
                    Spacer()
                    Text("Most recently active")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.faint)
                }

                VStack(spacing: 8) {
                    ForEach(Array(latestGoals.enumerated()), id: \.element.id) { index, goal in
                        NavigationLink {
                            GoalDetailView(goal: goal)
                        } label: {
                            LatestGoalCard(goal: goal)
                        }
                        .buttonStyle(.plain)
                        .scaleOnPress()
                        .staggeredAppear(index: index)
                    }
                }
            }
            .fadeSlideIn(delay: 0.08)
        }
    }

    private func updateWidgetData() {
        let defaults = UserDefaults(suiteName: "group.com.ambidash.app")
        defaults?.set(compositeScore, forKey: "widget_composite")
        defaults?.set(goals.count, forKey: "widget_pillars")
        if let topGoal = goals.max(by: { $0.neglectDays < $1.neglectDays }) {
            defaults?.set(topGoal.title, forKey: "widget_top_goal")
            defaults?.set(GoalHealthService.summaryText(for: topGoal), forKey: "widget_top_status")
        }
    }

    private var identityText: String {
        let lowestDim = dimensionScores.min(by: { $0.value < $1.value })
        switch lowestDim?.key {
        case .body: return "someone who treats their body as the instrument it is."
        case .mind: return "someone whose mind is sharper than their impulses."
        case .craft: return "someone who does the work, not just plans it."
        case .people: return "someone whose attention belongs to the people in front of them."
        case .wealth: return "someone whose freedom isn't borrowed."
        case .adventure: return "someone who lives, not just optimizes."
        case nil: return "someone who finishes what they start."
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = profile?.name.isEmpty == false ? profile!.name : ""
        let suffix = name.isEmpty ? "" : ", \(name)"
        if hour < 12 { return "Good morning\(suffix)." }
        if hour < 17 { return "Steady, not striving." }
        return "Close the loop\(suffix)."
    }
}

/// A compact, tappable card for one goal on the dashboard's "Latest goals"
/// section: pillar icon + title + horizon/status dots, a one-line context line,
/// and a thin progress indicator that mirrors how the goal is judged (target
/// attainment, weekly adherence, or recency). Tapping drills into the existing
/// GoalDetailView; the richer inline detail card arrives in a later pass.
private struct LatestGoalCard: View {
    let goal: Goal
    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: goal.domain.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(t.muted)
                    .frame(width: 16)
                Text(goal.title)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(t.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Circle()
                    .fill(goal.horizon.dotColor)
                    .frame(width: 5, height: 5)
                StatusDot(status: goal.computedStatus)
                    .scaleEffect(0.7)
                    .frame(width: 6, height: 6)
            }

            Text(contextLine)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(t.muted)
                .lineLimit(1)

            progressIndicator(t)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(goal.title), \(goal.domain.displayName), \(goal.computedStatus.label)")
    }

    /// One-line context that matches how this goal type is measured.
    private var contextLine: String {
        if goal.hasTarget {
            return "\(MetricFormat.number(goal.currentValue)) / \(MetricFormat.value(goal.targetValue, unit: goal.unit))"
        } else if goal.isHabitual {
            return AdherenceFormat.compact(for: goal)
        } else if !goal.subtitle.isEmpty {
            return goal.subtitle
        }
        return GoalHealthService.summaryText(for: goal)
    }

    @ViewBuilder
    private func progressIndicator(_ t: ResolvedTheme) -> some View {
        if goal.hasTarget {
            TargetProgressBar(goal: goal, maxWidth: .infinity, showCaption: false)
        } else if goal.isHabitual {
            AdherenceBar(goal: goal, maxWidth: .infinity, showCaption: false)
        } else {
            // Mirror the actual scoring: non-measurable goals are judged by the
            // STEP-FUNCTION neglect band (≤1d:90, ≤3d:75, ≤5d:55, ≤7d:40, else
            // decaying), not a linear recency ramp. Fill the bar to the band value
            // so it matches DimensionScoreCalculator instead of misrepresenting it.
            let progress = Double(DimensionScoreCalculator.neglectBandScore(forDays: goal.neglectDays)) / 100.0
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1).fill(t.hair)
                    RoundedRectangle(cornerRadius: 1).fill(t.ink).frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 2)
        }
    }
}
