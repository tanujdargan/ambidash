import SwiftUI

struct QuickStatsView: View {
    let snapshot: IntegrationSnapshot?

    var body: some View {
        HStack(spacing: 12) {
            StatBox(
                value: snapshot.map { String(format: "%.1fh", $0.sleepHours) } ?? "—",
                label: "Sleep",
                color: .purple
            )
            StatBox(
                value: snapshot.map { String(format: "%.1fh", $0.screenTimeHours) } ?? "—",
                label: "Screen",
                color: .red
            )
            StatBox(
                value: snapshot.map { "\(String(format: "%.1f", Double($0.steps) / 1000))k" } ?? "—",
                label: "Steps",
                color: .green
            )
        }
    }
}

private struct StatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(color)
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
