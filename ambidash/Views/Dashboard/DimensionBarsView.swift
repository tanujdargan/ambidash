import SwiftUI

struct DimensionBarsView: View {
    let scores: [LifeDimension: Int]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(LifeDimension.allCases, id: \.self) { dim in
                let score = scores[dim] ?? 50
                HStack(spacing: 10) {
                    Text(dim.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AmbidashTheme.textSecondary)
                        .frame(width: 52, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(AmbidashTheme.bgElevated)

                            RoundedRectangle(cornerRadius: 3)
                                .fill(AmbidashTheme.dimensionColor(for: dim))
                                .frame(width: geo.size.width * CGFloat(score) / 100)
                        }
                    }
                    .frame(height: 6)

                    Text("\(score)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(AmbidashTheme.textPrimary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }
}
