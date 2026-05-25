import SwiftUI
import SwiftData

struct ReflectView: View {
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

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
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Evening Reflection")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DailySummaryView(plan: todayPlan, snapshot: todaySnapshot)

                    ReflectionFormView(existingReflection: todayReflection)
                }
                .padding()
            }
            .navigationTitle("Reflect")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
