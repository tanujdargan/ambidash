import SwiftUI
import SwiftData

struct ReflectView: View {
    @Environment(ThemeManager.self) private var tm
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    @State private var selectedTab = 0

    private var todayPlan: DailyPlan? {
        plans.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }
    }

    private var todayReflection: Reflection? {
        reflections.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }
    }

    private var todaySnapshot: IntegrationSnapshot? {
        snapshots.first
    }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Review Type", selection: $selectedTab) {
                    Text("Daily").tag(0)
                    Text("Weekly").tag(1)
                    Text("Monthly").tag(2)
                }
                .pickerStyle(.segmented)
                .tint(t.accent)
                .padding(.horizontal)
                .padding(.top, 8)

                if selectedTab == 0 {
                    ScrollView {
                        VStack(spacing: 16) {
                            Text("Evening Reflection")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(t.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                                .font(.subheadline)
                                .foregroundStyle(t.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            DailySummaryView(plan: todayPlan, snapshot: todaySnapshot)

                            ReflectionFormView(existingReflection: todayReflection)

                            if todayReflection != nil {
                                HonestMirrorView(
                                    plan: todayPlan,
                                    mood: todayReflection?.mood ?? "",
                                    blockers: todayReflection?.blockers ?? []
                                )
                            }
                        }
                        .padding()
                    }
                    .background(t.bg)
                } else if selectedTab == 1 {
                    WeeklyReviewView()
                } else if selectedTab == 2 {
                    MonthlyReviewView()
                }
            }
            .background(t.bg)
            .navigationTitle("Reflect")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
