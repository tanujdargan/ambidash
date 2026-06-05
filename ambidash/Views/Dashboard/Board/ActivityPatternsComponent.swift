import SwiftUI
import SwiftData

/// ACTIVITY PATTERNS — a read-only insight surface that shows the user's detected
/// productivity/energy/screen-time patterns from their logged history. Non-punitive,
/// confidence-gated: insights only appear once there's enough data to ground them,
/// and the empty state is a calm "a few more days" message, never a deficit.
///
/// Owns small @Querys for recent actuals + energy check-ins (inherently changing as
/// the day is logged), like PatternCheckInComponent — so it is intentionally NOT fed
/// from the static BoardData snapshot.
struct ActivityPatternsComponent: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ActualEvent.date, order: .reverse) private var actuals: [ActualEvent]
    @Query(sort: \EnergyCheckin.date, order: .reverse) private var checkins: [EnergyCheckin]

    @State private var insights: [ActivityInsight] = []
    @State private var screenTimePeak: String?

    private let window = 14

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: t.space.component) {
            header(t)

            if insights.isEmpty {
                emptyState(t)
            } else {
                insightCards(t)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .animation(MotionPreference.animation(.ambidashSpring), value: insights.count)
        .task(id: dataFingerprint) { await recompute() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Activity patterns")
    }

    // MARK: - Header

    @ViewBuilder
    private func header(_ t: ResolvedTheme) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(title: "Your Patterns")
            Spacer()
            if !insights.isEmpty {
                Text("from \(recentActuals.count) blocks")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 13))
                .foregroundStyle(t.muted)
            Text("A few more days of logging and your patterns will appear here.")
                .font(t.body(12))
                .foregroundStyle(t.muted)
        }
    }

    // MARK: - Insight cards

    @ViewBuilder
    private func insightCards(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 8) {
            ForEach(insights.prefix(3)) { insight in
                insightRow(insight, t)
            }

            if let peak = screenTimePeak {
                insightRow(ActivityInsight(
                    id: "screen-peak",
                    title: "Most active on screen \(peak)",
                    detail: "Your screen time concentrates here — worth watching for drift.",
                    symbol: "iphone",
                    sampleSize: 0
                ), t)
            }
        }
    }

    @ViewBuilder
    private func insightRow(_ insight: ActivityInsight, _ t: ResolvedTheme) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.symbol)
                .font(.system(size: 12))
                .foregroundStyle(t.accent)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title)
                    .font(t.body(13))
                    .fontWeight(.medium)
                    .foregroundStyle(t.ink)
                Text(insight.detail)
                    .font(t.body(11))
                    .foregroundStyle(t.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if insight.sampleSize > 0 {
                Text("\(insight.sampleSize)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
        }
        .padding(10)
        .background(t.sunken.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Compute

    private var recentActuals: [ActualEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -window, to: .now)
            ?? Date.now.addingTimeInterval(-Double(window) * 86_400)
        return actuals.filter { $0.date >= cutoff }
    }

    private var recentCheckins: [EnergyCheckin] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -window, to: .now)
            ?? Date.now.addingTimeInterval(-Double(window) * 86_400)
        return checkins.filter { $0.date >= cutoff }
    }

    private var dataFingerprint: String {
        "\(actuals.count)-\(checkins.count)-\(actuals.first?.date.timeIntervalSince1970 ?? 0)"
    }

    private func recompute() async {
        let recent = recentActuals
        let recentE = recentCheckins

        let adherence = LearningService.computeAdherenceByHour(actuals: recent)
        let energy = LearningService.computeEnergyByHour(checkins: recentE)

        let completedCount = recent.filter { $0.completionStatus == .completed }.count

        let detected = ActivityInsights.detect(
            adherenceByHour: adherence,
            energyByHour: energy,
            energySampleCount: recentE.count,
            completedCount: completedCount,
            totalLoggedCount: recent.count,
            reflectionCount: 0
        )

        // Only keep the pattern-style insights (productive window, energy peak, afternoon skip).
        insights = detected.filter {
            $0.id == "productive-window" || $0.id == "energy-peak" || $0.id == "afternoon-skip"
        }

        // Screen time peak (best-effort from shared container).
        let data = await ScreenTimeService.shared.fetchTodayScreenTime()
        if data.totalHours > 0, let top = data.categories.max(by: { $0.value < $1.value }) {
            screenTimePeak = "(\(top.key): \(String(format: "%.1fh", top.value)))"
        } else {
            screenTimePeak = nil
        }
    }
}
