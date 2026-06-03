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
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now.addingTimeInterval(-86400)
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

    /// The compute-once snapshot fed to every board component. Built a single time
    /// per render from the view's @Query data + derived properties, so no
    /// component renderer issues its own query or sees stale data.
    private var boardData: BoardData {
        BoardData(
            profile: profile,
            todaySnapshot: todaySnapshot,
            yesterdaySnapshot: yesterdaySnapshot,
            activeGoals: activeGoals,
            latestGoals: latestGoals,
            todayPlan: todayPlan,
            dimensionScores: dimensionScores,
            compositeScore: compositeScore,
            streakSummary: streakSummary,
            compositeHistory: compositeHistory,
            lowestDimension: dimensionScores.min(by: { $0.value < $1.value })?.key,
            isHardDay: HardModeService.isHardToday(profile?.userPreferences)
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

                        // 2. Configurable component board. Computes shared data
                        // ONCE (boardData) and renders the ordered components of the
                        // hardcoded "balanced" template via ComponentRegistry,
                        // wrapping the existing dashboard surfaces (composite score,
                        // vitals grid, latest goals, mentor, today-narrow, identity
                        // line). Tap-score → breakdown and tap-goal → detail are
                        // preserved through onTapScore + the components' own
                        // NavigationLinks (this NavigationStack hosts them).
                        BoardView(boardData: boardData) { target in
                            scoreBreakdown = target
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
                    .padding(.bottom, 100)
                }
                .accessibilityIdentifier("dashboard.scroll")
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
                    // Provisional auth (no upfront wall) + clamp every scheduler to
                    // the user's real waking window so nothing fires while asleep.
                    if let prefs = profile?.userPreferences {
                        NotificationService.configureWakingWindow(wake: prefs.wakeTime, sleep: prefs.sleepTime)
                    }
                    await NotificationService.requestPermission()
                    NotificationService.scheduleDailyReminder()
                    NotificationService.scheduleMorningPlan()
                    // CLOSING RITUAL — gentle evening invite to wrap the day and pick
                    // tomorrow's one thing. Idempotent + clamped to waking-evening.
                    NotificationService.scheduleClosingRitualReminder()
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
                    // REST-DAY BANK — gently evaluate earned rest days once per day from
                    // the user's best live streak. Non-punitive: this only ever ADDS to
                    // the bank; it never penalizes. Idempotent per day via prefs stamp.
                    if let prefs = profile.userPreferences {
                        let earned = RestBankService.evaluateEarn(
                            prefs,
                            longestLiveStreak: streakSummary.longestCurrentStreak
                        )
                        if earned > 0 { try? modelContext.save() }
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

    private func updateWidgetData() {
        let defaults = UserDefaults(suiteName: "group.com.ambidash.app")
        defaults?.set(compositeScore, forKey: "widget_composite")
        defaults?.set(goals.count, forKey: "widget_pillars")
        if let topGoal = goals.max(by: { $0.neglectDays < $1.neglectDays }) {
            defaults?.set(topGoal.title, forKey: "widget_top_goal")
            defaults?.set(GoalHealthService.summaryText(for: topGoal), forKey: "widget_top_status")
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
struct LatestGoalCard: View {
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
                    .font(t.heading(15))
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
