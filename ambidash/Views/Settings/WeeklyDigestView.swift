// ambidash/Views/Settings/WeeklyDigestView.swift
//
// v5 feat/v5-activity-logging — the weekly digest screen. Reads the last 7 days of logged
// activity (ActualEvent / EnergyCheckin / Reflection) and surfaces the detected patterns as calm,
// non-punitive insight cards, with a small at-a-glance stat row. Renders an empty-but-kind state
// when there isn't enough logged yet.
import SwiftUI
import SwiftData

struct WeeklyDigestView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    // Re-query the raw logs so the digest recomputes live as activity is logged.
    @Query private var actuals: [ActualEvent]
    @Query private var checkins: [EnergyCheckin]
    @Query private var reflections: [Reflection]

    private var digest: WeeklyDigest {
        let now = Date.now
        let weekAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let reflectionDays = Set(
            reflections.filter { $0.date >= weekAgo }.map { Calendar.current.startOfDay(for: $0.date) }
        ).count
        return LearningService.weeklyDigest(
            actuals: actuals, checkins: checkins, reflectionDayCount: reflectionDays, now: now
        )
    }

    var body: some View {
        let t = tm.resolved
        let d = digest
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Your week in review")
                    .font(t.heading(22)).foregroundStyle(t.ink)
                Text("Patterns from what you actually did — no judgment, just a mirror.")
                    .font(t.body(13)).foregroundStyle(t.muted)

                if d.hasContent {
                    statRow(t, d)
                    insightCards(t, d)
                } else {
                    emptyState(t)
                }
            }
            .padding(22)
        }
        .background(t.bg)
        .navigationTitle("Weekly Digest")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("weeklydigest.screen")
    }

    @ViewBuilder
    private func statRow(_ t: ResolvedTheme, _ d: WeeklyDigest) -> some View {
        HStack(spacing: 12) {
            stat(t, value: "\(d.completedCount)", label: "Done")
            stat(t, value: "\(d.partialCount)", label: "Partial")
            stat(t, value: d.averageEnergyLabel, label: "Avg energy")
            stat(t, value: "\(d.reflectionCount)", label: "Reflected")
        }
    }

    @ViewBuilder
    private func stat(_ t: ResolvedTheme, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(t.heading(18)).foregroundStyle(t.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func insightCards(_ t: ResolvedTheme, _ d: WeeklyDigest) -> some View {
        if d.insights.isEmpty {
            Text("A few more days of activity and patterns will start to show here.")
                .font(t.body(13)).foregroundStyle(t.muted)
                .padding(.top, 4)
        } else {
            VStack(spacing: 12) {
                ForEach(d.insights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.symbol)
                            .font(.system(size: 18))
                            .foregroundStyle(t.accent)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(insight.title).font(t.heading(15)).foregroundStyle(t.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(insight.detail).font(t.body(12)).foregroundStyle(t.muted)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("from \(insight.sampleSize) \(insight.sampleSize == 1 ? "entry" : "entries")")
                                .font(.system(size: 10, design: .monospaced)).foregroundStyle(t.faint)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(t.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 26)).foregroundStyle(t.muted)
            Text("Nothing to review yet")
                .font(t.heading(16)).foregroundStyle(t.ink)
            Text("As you complete blocks, log energy, and reflect, your weekly patterns will appear here — most-productive hours, energy peaks, and gentle nudges.")
                .font(t.body(13)).foregroundStyle(t.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
