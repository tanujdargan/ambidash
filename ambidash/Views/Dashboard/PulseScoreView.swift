import SwiftUI

struct PulseScoreView: View {
    let score: Int
    let trend: Int

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("PULSE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                }
            }

            if trend != 0 {
                Text("\(trend > 0 ? "▲" : "▼") \(abs(trend)) from yesterday")
                    .font(.caption)
                    .foregroundStyle(trend > 0 ? .green : .red)
            }
        }
    }

    private var scoreColor: Color {
        if score >= 70 { return .green }
        if score >= 45 { return .orange }
        return .red
    }
}
