import SwiftUI

struct PulseScoreView: View {
    let score: Int
    let trend: Int

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Glow behind ring
                Circle()
                    .frame(width: 130, height: 130)
                    .shadow(color: AmbidashTheme.accentGlow.opacity(0.3), radius: 20)

                // Background ring
                Circle()
                    .stroke(AmbidashTheme.bgElevated, lineWidth: 8)
                    .frame(width: 120, height: 120)

                // Progress ring
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(AmbidashTheme.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(AmbidashTheme.textPrimary)
                    Text("PULSE")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AmbidashTheme.textTertiary)
                        .tracking(2)
                }
            }

            if trend != 0 {
                Text("\(trend > 0 ? "▲" : "▼") \(abs(trend)) from yesterday")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(trend > 0 ? AmbidashTheme.statusGood : AmbidashTheme.statusBad)
            }
        }
    }
}
