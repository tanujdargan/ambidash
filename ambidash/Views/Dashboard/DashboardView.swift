import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @State private var manager = IntegrationManager()
    @State private var showSettings = false
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    private var profile: UserProfile? { profiles.first }
    private var todaySnapshot: IntegrationSnapshot? { snapshots.first }

    private var goals: [Goal] {
        profile?.goals.filter(\.isActive) ?? []
    }

    private var yesterdaySnapshot: IntegrationSnapshot? {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        return snapshots.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    private var streakSummary: StreakService.StreakSummary {
        StreakService.summary(for: goals)
    }

    private var dimensionScores: [LifeDimension: Int] {
        DimensionScoreCalculator.scores(from: goals, snapshot: todaySnapshot)
    }

    private var pulseScore: Int {
        PulseScoreCalculator.pulse(from: dimensionScores)
    }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack(alignment: .top) {
                t.bg
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // Custom header
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(t.faint)
                                    .tracking(0.3)
                                Text(greeting)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(t.ink)
                            }
                            Spacer()
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(t.muted)
                                    .frame(width: 36, height: 36)
                                    .background(t.surface)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(t.hair, lineWidth: 0.5)
                                    )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        PulseScoreView(score: pulseScore, trend: 0)

                        CardView {
                            DimensionBarsView(scores: dimensionScores)
                        }
                        .padding(.horizontal, 16)

                        QuickStatsView(snapshot: todaySnapshot, previousSnapshot: yesterdaySnapshot)
                            .padding(.horizontal, 16)

                        if !goals.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                SectionHeader(title: "Active Goals")
                                    .padding(.horizontal, 16)
                                GoalStripView(goals: goals)
                            }
                        }

                        // Streak summary
                        if streakSummary.totalActiveStreaks > 0 {
                            CardView {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "flame.fill")
                                            .foregroundStyle(t.accent)
                                        Text("\(streakSummary.totalActiveStreaks) active streak\(streakSummary.totalActiveStreaks == 1 ? "" : "s")")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(t.ink)
                                        Spacer()
                                        Text("Best: \(streakSummary.longestCurrentStreak)d")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(t.faint)
                                    }

                                    ForEach(streakSummary.atRiskStreaks, id: \.goalTitle) { risk in
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                                .foregroundStyle(t.accent)
                                            Text("\(risk.goalTitle) streak (\(risk.count)d) ends tonight")
                                                .font(.system(size: 12))
                                                .foregroundStyle(t.accent)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        InsightCardView(goals: goals, snapshot: todaySnapshot)
                            .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)
                }
            }
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
            }
            .refreshable {
                await manager.refreshTodaySnapshot(in: modelContext)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = profile?.name.isEmpty == false ? profile!.name : "there"
        if hour < 12 { return "Good morning, \(name)" }
        if hour < 17 { return "Good afternoon, \(name)" }
        return "Good evening, \(name)"
    }
}
