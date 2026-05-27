import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var manager = IntegrationManager()
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]
    @State private var showSettings = false

    private var profile: UserProfile? { profiles.first }
    private var todaySnapshot: IntegrationSnapshot? { snapshots.first }
    private var yesterdaySnapshot: IntegrationSnapshot? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        return snapshots.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    private var goals: [Goal] { profile?.goals.filter(\.isActive) ?? [] }

    private var dimensionScores: [LifeDimension: Int] {
        DimensionScoreCalculator.scores(from: goals, snapshot: todaySnapshot)
    }
    private var compositeScore: Int {
        PulseScoreCalculator.pulse(from: dimensionScores)
    }
    private var streakSummary: StreakService.StreakSummary {
        StreakService.summary(for: goals)
    }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Header with settings
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

                        // Composite score + sparkline
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

                        // Six arc gauges in 3-col grid
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

                        // Mentor surfaced
                        InsightCardView(goals: goals, snapshot: todaySnapshot)
                            .fadeSlideIn(delay: 0.1)

                        // Goal strip
                        if !goals.isEmpty {
                            GoalStripView(goals: goals)
                                .padding(.horizontal, -22)
                        }

                        // Streak section
                        if streakSummary.totalActiveStreaks > 0 {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                        .foregroundStyle(t.accent)
                                    Text("\(streakSummary.totalActiveStreaks) active streak\(streakSummary.totalActiveStreaks == 1 ? "" : "s")")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(t.ink)
                                    Spacer()
                                    Text("Best: \(streakSummary.longestCurrentStreak)d")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(t.faint)
                                }
                                ForEach(streakSummary.atRiskStreaks, id: \.goalTitle) { risk in
                                    HStack(spacing: 6) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption2)
                                            .foregroundStyle(t.accent)
                                        Text("\(risk.goalTitle) streak (\(risk.count)d) ends tonight")
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(t.accent)
                                    }
                                }
                            }
                            .padding(16)
                            .background(t.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
                        }

                        // Today, narrow
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: "Today, narrow")
                            DataRowView(label: "Free time", value: "\(todaySnapshot?.calendarFreeMinutes ?? 0)", unit: "min")
                            DataRowView(label: "Sleep", value: String(format: "%.1f", todaySnapshot?.sleepHours ?? 0), unit: "hr")
                            DataRowView(label: "Steps", value: "\(todaySnapshot?.steps ?? 0)")
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .task {
                await manager.requestAllPermissions()
                await manager.refreshTodaySnapshot(in: modelContext)
                await NotificationService.requestPermission()
                NotificationService.scheduleDailyReminder()
                NotificationService.scheduleMorningPlan()
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
