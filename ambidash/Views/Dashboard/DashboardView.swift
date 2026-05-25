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
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    PulseScoreView(score: pulseScore, trend: 0)

                    DimensionBarsView(scores: dimensionScores)
                        .padding(.horizontal)

                    QuickStatsView(snapshot: todaySnapshot)
                        .padding(.horizontal)

                    if !goals.isEmpty {
                        GoalStripView(goals: goals)
                    }

                    // Streak summary
                    if streakSummary.totalActiveStreaks > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)
                                Text("\(streakSummary.totalActiveStreaks) active streak\(streakSummary.totalActiveStreaks == 1 ? "" : "s")")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Text("Best: \(streakSummary.longestCurrentStreak)d")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(streakSummary.atRiskStreaks, id: \.goalTitle) { risk in
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                    Text("\(risk.goalTitle) streak (\(risk.count)d) ends tonight")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    InsightCardView(goals: goals, snapshot: todaySnapshot)
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .task {
                await manager.requestAllPermissions()
                await manager.refreshTodaySnapshot(in: modelContext)
                await NotificationService.requestPermission()
                NotificationService.scheduleDailyReminder()
                NotificationService.scheduleMorningPlan()
                StreakService.scheduleWarnings(for: goals)
            }
            .refreshable {
                await manager.refreshTodaySnapshot(in: modelContext)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = profile?.name.isEmpty == false ? profile!.name : "there"
        if hour < 12 { return "Good morning, \(name)" }
        if hour < 17 { return "Good afternoon, \(name)" }
        return "Good evening, \(name)"
    }
}
