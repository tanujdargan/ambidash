import SwiftUI

struct QuickStatsView: View {
    let snapshot: IntegrationSnapshot?
    let previousSnapshot: IntegrationSnapshot?

    private func trend(current: Double, previous: Double?) -> String? {
        guard let previous, previous > 0 else { return nil }
        let diff = current - previous
        if abs(diff) < 0.1 { return nil }
        return diff > 0 ? "▲" : "▼"
    }

    var body: some View {
        HStack(spacing: 10) {
            StatBox(
                value: snapshot.map { String(format: "%.1fh", $0.sleepHours) } ?? "—",
                label: "Sleep",
                trend: trend(current: snapshot?.sleepHours ?? 0, previous: previousSnapshot?.sleepHours),
                trendIsGood: (snapshot?.sleepHours ?? 0) >= (previousSnapshot?.sleepHours ?? 0)
            )
            StatBox(
                value: snapshot.map { String(format: "%.1fh", $0.screenTimeHours) } ?? "—",
                label: "Screen",
                trend: trend(current: snapshot?.screenTimeHours ?? 0, previous: previousSnapshot?.screenTimeHours),
                trendIsGood: (snapshot?.screenTimeHours ?? 0) <= (previousSnapshot?.screenTimeHours ?? 0)
            )
            StatBox(
                value: snapshot.map { "\(String(format: "%.1f", Double($0.steps) / 1000))k" } ?? "—",
                label: "Steps",
                trend: trend(current: Double(snapshot?.steps ?? 0), previous: previousSnapshot.map { Double($0.steps) }),
                trendIsGood: (snapshot?.steps ?? 0) >= (previousSnapshot?.steps ?? 0)
            )
        }
    }
}

private struct StatBox: View {
    let value: String
    let label: String
    var trend: String? = nil
    var trendIsGood: Bool = true

    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        VStack(spacing: 5) {
            HStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(t.ink)
                if let trend {
                    Text(trend)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(trendIsGood ? t.ok : t.danger)
                }
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(t.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(t.hair, lineWidth: 0.5)
        )
    }
}
