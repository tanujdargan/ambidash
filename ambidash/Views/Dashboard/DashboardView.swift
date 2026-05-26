import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
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
        NavigationStack {
            ZStack(alignment: .top) {
                AmbidashTheme.bgBase
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AmbidashTheme.spacingLG) {

                        // Custom header
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AmbidashTheme.textTertiary)
                                    .tracking(0.3)
                                Text(greeting)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(AmbidashTheme.textPrimary)
                            }
                            Spacer()
                            Button {
                                showSettings = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(AmbidashTheme.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(AmbidashTheme.bgElevated)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(AmbidashTheme.border, lineWidth: 0.5)
                                    )
                            }
                        }
                        .padding(.horizontal, AmbidashTheme.spacingMD)
                        .padding(.top, AmbidashTheme.spacingSM)

                        PulseScoreView(score: pulseScore, trend: 0)

                        CardView {
                            DimensionBarsView(scores: dimensionScores)
                        }
                        .padding(.horizontal, AmbidashTheme.spacingMD)

                        QuickStatsView(snapshot: todaySnapshot, previousSnapshot: yesterdaySnapshot)
                            .padding(.horizontal, AmbidashTheme.spacingMD)

                        if !goals.isEmpty {
                            VStack(alignment: .leading, spacing: AmbidashTheme.spacingSM) {
                                SectionHeader(title: "Active Goals")
                                    .padding(.horizontal, AmbidashTheme.spacingMD)
                                GoalStripView(goals: goals)
                            }
                        }

                        // Streak summary
                        if streakSummary.totalActiveStreaks > 0 {
                            CardView {
                                VStack(alignment: .leading, spacing: AmbidashTheme.spacingSM) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "flame.fill")
                                            .foregroundStyle(AmbidashTheme.statusWarn)
                                        Text("\(streakSummary.totalActiveStreaks) active streak\(streakSummary.totalActiveStreaks == 1 ? "" : "s")")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundStyle(AmbidashTheme.textPrimary)
                                        Spacer()
                                        Text("Best: \(streakSummary.longestCurrentStreak)d")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(AmbidashTheme.textTertiary)
                                    }

                                    ForEach(streakSummary.atRiskStreaks, id: \.goalTitle) { risk in
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption2)
                                                .foregroundStyle(AmbidashTheme.statusWarn)
                                            Text("\(risk.goalTitle) streak (\(risk.count)d) ends tonight")
                                                .font(.system(size: 12))
                                                .foregroundStyle(AmbidashTheme.statusWarn)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, AmbidashTheme.spacingMD)
                        }

                        InsightCardView(goals: goals, snapshot: todaySnapshot)
                            .padding(.horizontal, AmbidashTheme.spacingMD)
                    }
                    .padding(.vertical, AmbidashTheme.spacingMD)
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
