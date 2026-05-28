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
    @State private var showSettings = false

    private var profile: UserProfile? { profiles.first }
    private var todaySnapshot: IntegrationSnapshot? { snapshots.first }
    private var yesterdaySnapshot: IntegrationSnapshot? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        return snapshots.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    private var goals: [Goal] { activeGoals }

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

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // 1. Header (date + serif subtitle + settings gear)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)).uppercased())
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .tracking(1.6)
                                    .foregroundStyle(t.muted)

                                Text(greeting)
                                    .font(.system(size: 28, weight: .regular, design: .serif))
                                    .tracking(-0.3)
                                    .foregroundStyle(t.ink)
                            }
                            Spacer()
                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 16))
                                    .foregroundStyle(t.muted)
                            }
                            .accessibilityLabel("Settings")
                        }

                        // 2. Composite score + sparkline
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
                            SparklineView(values: [44, 47, 41, 52, 55, 51, 54, 58, 53, 56, 54, Double(compositeScore)], width: 120, height: 48)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Composite score: \(compositeScore) out of 100")
                        .fadeSlideIn(delay: 0)

                        // 3. Arc gauges in 3-col grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 18) {
                            ForEach(Array(LifeDimension.allCases.enumerated()), id: \.element) { index, dim in
                                ArcGauge(
                                    value: Double(dimensionScores[dim] ?? 50) / 100.0,
                                    size: 86,
                                    strokeWidth: 3.5,
                                    label: dim.displayName
                                )
                                .staggeredAppear(index: index)
                            }
                        }

                        // 4. Mentor surfaced
                        InsightCardView(goals: goals, snapshot: todaySnapshot)
                            .fadeSlideIn(delay: 0.1)

                        // 5. Today, narrow
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(title: "Today, narrow")
                            if let plan = todayPlan, !plan.actions.isEmpty {
                                let topActions = plan.actions.sorted { $0.timeSlot < $1.timeSlot }.prefix(3)
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
            .task {
                SeedService.seedIfNeeded(context: modelContext)
                await manager.requestAllPermissions()
                await manager.refreshTodaySnapshot(in: modelContext)
                if !IntegrationManager.skipPermissions {
                    await NotificationService.requestPermission()
                    NotificationService.scheduleDailyReminder()
                    NotificationService.scheduleMorningPlan()
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
