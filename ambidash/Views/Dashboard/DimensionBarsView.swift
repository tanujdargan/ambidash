import SwiftUI

struct DimensionBarsView: View {
    let scores: [LifeDimension: Int]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(LifeDimension.allCases, id: \.self) { dim in
                let score = scores[dim] ?? 50
                HStack {
                    Text(dim.displayName)
                        .font(.caption)
                        .frame(width: 50, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(barColor(score))
                                .frame(width: geo.size.width * CGFloat(score) / 100)
                        }
                    }
                    .frame(height: 8)

                    Text("\(score)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    private func barColor(_ score: Int) -> Color {
        if score >= 70 { return .green }
        if score >= 45 { return .orange }
        return .red
    }
}
