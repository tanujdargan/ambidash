import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var manager = IntegrationManager()
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    private var profile: UserProfile? { profiles.first }
    private var todaySnapshot: IntegrationSnapshot? { snapshots.first }

    private var goals: [Goal] {
        profile?.goals.filter(\.isActive) ?? []
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

                    InsightCardView()
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .task {
                await manager.requestAllPermissions()
                await manager.refreshTodaySnapshot(in: modelContext)
            }
            .refreshable {
                await manager.refreshTodaySnapshot(in: modelContext)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
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
