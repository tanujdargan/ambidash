import SwiftUI

// The breakdown math (`ScoreBreakdown`) and the sheet target
// (`ScoreBreakdownTarget`) now live in Services/ScoreBreakdown.swift so they can
// be shared with the macOS dashboard (the iOS Views/ directory is excluded from
// the mac target). This file keeps only the iOS card UI.

// MARK: - Score Breakdown Card (sheet)

/// An honest, tappable explanation of a score. Reads the real inputs and weights
/// from `ScoreBreakdown` (which mirrors `DimensionScoreCalculator` /
/// `PulseScoreCalculator`) — no invented formulas. For the composite it lists the
/// six dimension scores and their average; for a single dimension it traces every
/// contributing goal's neglect band + attainment blend, then any snapshot
/// bonus/penalty, to the final score on the arc gauge.
struct ScoreBreakdownCard: View {
    @Environment(ThemeManager.self) private var tm

    let target: ScoreBreakdownTarget
    let goals: [Goal]
    let snapshot: IntegrationSnapshot?
    let dimensionScores: [LifeDimension: Int]
    let compositeScore: Int

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    handle(t)
                    switch target {
                    case .composite: compositeBody(t)
                    case .dimension(let dim): dimensionBody(dim, t)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(20)
    }

    @ViewBuilder
    private func handle(_ t: ResolvedTheme) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(t.faint)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
    }

    // MARK: Composite

    @ViewBuilder
    private func compositeBody(_ t: ResolvedTheme) -> some View {
        let dims = LifeDimension.allCases
        let values = dims.map { dimensionScores[$0] ?? 50 }

        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "Composite score breakdown")
            Text("\(compositeScore)/100")
                .font(.system(size: 32, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(t.ink)
        }

        Text("The composite is the plain average of all six dimension scores — no weighting. Tap any dimension above its arc gauge to see how that number is built.")
            .font(.system(size: 13, design: .serif))
            .foregroundStyle(t.ink2)
            .lineSpacing(3)

        VStack(spacing: 0) {
            ForEach(Array(dims.enumerated()), id: \.element) { _, dim in
                DataRowView(label: dim.fullName, value: "\(dimensionScores[dim] ?? 50)")
            }
        }

        // Honest formula trace using the live values.
        let sum = values.reduce(0, +)
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "Formula")
            Text("(\(values.map(String.init).joined(separator: " + "))) ÷ \(dims.count) = \(sum) ÷ \(dims.count) = \(compositeScore)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(t.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: 0.5))
    }

    // MARK: Dimension

    @ViewBuilder
    private func dimensionBody(_ dim: LifeDimension, _ t: ResolvedTheme) -> some View {
        let detail = ScoreBreakdown.detail(for: dim, goals: goals, snapshot: snapshot)

        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "\(dim.fullName) score")
            Text("\(detail.finalScore)/100")
                .font(.system(size: 32, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(t.ink)
        }

        if !detail.hasGoals {
            Text("No active goals in \(dim.fullName) yet, so this dimension defaults to a neutral 50. Add a goal here to make this score real.")
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(t.ink2)
                .lineSpacing(3)
        } else {
            Text("Each goal scores on recency (a neglect band by days since progress). Measurable goals blend that band 50/50 with how far they've climbed toward target. The dimension is the average of those goal scores.")
                .font(.system(size: 13, design: .serif))
                .foregroundStyle(t.ink2)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(title: "Contributing goals")
                ForEach(detail.goalLines) { line in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(line.title)
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(t.ink)
                        Text(line.explanation)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(t.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) { HairlineRule() }
                }
            }

            DataRowView(label: "Goal average", value: "\(detail.baseScore)")
        }

        // Snapshot bonus / penalty trace.
        if let adj = detail.adjustment {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(title: dim == .body ? "Sleep bonus" : "Screen-time penalty")
                Text("\(adj.label) → \(adj.bonusValue)/100, blended with the goal average: (\(adj.beforeScore) + \(adj.bonusValue)) ÷ 2 = \(adj.afterScore)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(t.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: 0.5))
        } else if dim == .body || dim == .craft {
            Text(dim == .body
                 ? "Connect Health data to fold a sleep bonus into this score."
                 : "Connect screen-time data to fold a focus penalty into this score.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(t.faint)
        }
    }
}
