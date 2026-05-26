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
        HStack(spacing: 12) {
            StatBox(
                value: snapshot.map { String(format: "%.1fh", $0.sleepHours) } ?? "—",
                label: "Sleep",
                color: .purple,
                trend: trend(current: snapshot?.sleepHours ?? 0, previous: previousSnapshot?.sleepHours),
                trendIsGood: (snapshot?.sleepHours ?? 0) >= (previousSnapshot?.sleepHours ?? 0)
            )
            StatBox(
                value: snapshot.map { String(format: "%.1fh", $0.screenTimeHours) } ?? "—",
                label: "Screen",
                color: .red,
                trend: trend(current: snapshot?.screenTimeHours ?? 0, previous: previousSnapshot?.screenTimeHours),
                trendIsGood: (snapshot?.screenTimeHours ?? 0) <= (previousSnapshot?.screenTimeHours ?? 0)
            )
            StatBox(
                value: snapshot.map { "\(String(format: "%.1f", Double($0.steps) / 1000))k" } ?? "—",
                label: "Steps",
                color: .green,
                trend: trend(current: Double(snapshot?.steps ?? 0), previous: previousSnapshot.map { Double($0.steps) }),
                trendIsGood: (snapshot?.steps ?? 0) >= (previousSnapshot?.steps ?? 0)
            )
        }
    }
}

private struct StatBox: View {
    let value: String
    let label: String
    let color: Color
    var trend: String? = nil
    var trendIsGood: Bool = true

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                if let trend {
                    Text(trend)
                        .font(.system(size: 10))
                        .foregroundStyle(trendIsGood ? .green : .red)
                }
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
