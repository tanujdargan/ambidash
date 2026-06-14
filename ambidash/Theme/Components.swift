import SwiftUI

// MARK: - Card

struct CardView<Content: View>: View {
    @Environment(ThemeManager.self) private var tm
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .glassCard(cornerRadius: 16)
            .scaleOnPress()
    }
}

// MARK: - Section Label (mono, small caps, tracked)

struct SectionLabel: View {
    @Environment(ThemeManager.self) private var tm
    let title: String

    var body: some View {
        let t = tm.resolved
        Text(title.uppercased())
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(t.muted)
    }
}

// MARK: - Serif Text (for reflection/mentor voice)

struct SerifText: View {
    @Environment(ThemeManager.self) private var tm
    let text: String
    var size: CGFloat = 22
    var italic: Bool = false

    var body: some View {
        let t = tm.resolved
        Text(text)
            .font(t.heading(size))
            .italic(italic)
            .tracking(-0.2)
            .foregroundStyle(t.ink)
    }
}

// MARK: - Mono Text (for data/values)

struct MonoText: View {
    @Environment(ThemeManager.self) private var tm
    let text: String
    var size: CGFloat = 13

    var body: some View {
        let t = tm.resolved
        Text(text)
            .font(.system(size: size, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(t.ink)
    }
}

// MARK: - Primary Button (filled, ink on bg)

struct PrimaryButton: View {
    @Environment(ThemeManager.self) private var tm
    let label: String
    let action: () -> Void

    var body: some View {
        let t = tm.resolved
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(t.bg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(t.ink)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityHint("Double tap to activate")
        .buttonStyle(.scalePress)
    }
}

// MARK: - Ghost Button (outlined)

struct GhostButton: View {
    @Environment(ThemeManager.self) private var tm
    let label: String
    let action: () -> Void

    var body: some View {
        let t = tm.resolved
        Button(action: action) {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(t.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(t.rule, lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Pill Button (small, rounded)

struct PillButton: View {
    @Environment(ThemeManager.self) private var tm
    let label: String
    var primary: Bool = false
    let action: () -> Void

    var body: some View {
        let t = tm.resolved
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .tracking(0.1)
                .foregroundStyle(primary ? t.bg : t.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(primary ? t.ink : .clear)
                .clipShape(Capsule())
                .overlay(
                    primary ? nil : Capsule().stroke(t.rule, lineWidth: 0.5)
                )
        }
        .accessibilityAddTraits(.isButton)
        .buttonStyle(.scalePress)
    }
}

// MARK: - Hairline Rule

struct HairlineRule: View {
    @Environment(ThemeManager.self) private var tm

    var body: some View {
        tm.resolved.hair
            .frame(height: 0.5)
    }
}

// MARK: - Data Row (label + value + trend)

struct DataRowView: View {
    @Environment(ThemeManager.self) private var tm
    let label: String
    let value: String
    var unit: String? = nil
    var trend: String? = nil

    var body: some View {
        let t = tm.resolved
        HStack {
            SectionLabel(title: label)
            Spacer()
            HStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 17, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(t.ink)
                if let unit {
                    Text(unit)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
                if let trend {
                    Text(trend)
                        .font(.system(size: 10, design: .monospaced))
                        // Non-punitive: a downward trend is informational, not a
                        // failure — fade it (deferred), reserve danger for real errors.
                        .foregroundStyle(trend.hasPrefix("+") ? t.ok : t.deferred)
                }
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            HairlineRule()
        }
    }
}

// MARK: - Arc Gauge (vitals style)

struct ArcGauge: View {
    @Environment(ThemeManager.self) private var tm
    let value: Double
    var size: CGFloat = 86
    var strokeWidth: CGFloat = 3.5
    var label: String? = nil

    var body: some View {
        let t = tm.resolved
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(t.hair, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: 0.75 * min(1, max(0, value)))
                    .stroke(t.accent, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(135))

                VStack(spacing: 0) {
                    Text("\(Int(value * 100))")
                        .font(.system(size: 18, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(t.ink)
                    Text("/100")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
            }

            if let label {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(t.muted)
            }
        }
        .accessibilityLabel("\(label ?? "Score"): \(Int(value * 100)) out of 100")
    }
}

// MARK: - Mentor Note

struct MentorNote: View {
    @Environment(ThemeManager.self) private var tm
    let text: String
    var signature: String = "M."

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title: "Note from your mentor")

            Text(text)
                .font(.system(size: 17, weight: tm.typography.serifWeight, design: .serif))
                .italic()
                .tracking(-0.1)
                .lineSpacing(4)
                .foregroundStyle(t.ink)

            Text("— \(signature)")
                .font(.system(size: 14, design: .serif))
                .italic()
                .foregroundStyle(t.muted)
        }
        .padding(18)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(t.hair, lineWidth: 0.5)
        )
        .overlay(alignment: .leading) {
            t.accent
                .frame(width: 2)
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .padding(.vertical, 1)
        }
    }
}

// MARK: - Identity Statement

struct IdentityStatement: View {
    @Environment(ThemeManager.self) private var tm
    let text: String

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "You are becoming")

            Text(text)
                .font(t.heading(24))
                .italic()
                .tracking(-0.3)
                .lineSpacing(2)
                .foregroundStyle(t.ink)
        }
        .padding(.vertical, t.space.section)
        .overlay(alignment: .top) { HairlineRule() }
        .overlay(alignment: .bottom) { HairlineRule() }
    }
}

// MARK: - Sparkline

struct SparklineView: View {
    @Environment(ThemeManager.self) private var tm
    let values: [Double]
    var width: CGFloat = 110
    var height: CGFloat = 30

    var body: some View {
        let t = tm.resolved
        Canvas { context, canvasSize in
            guard values.count > 1 else { return }
            let maxVal = values.max() ?? 1
            let minVal = values.min() ?? 0
            let range = maxVal - minVal > 0 ? maxVal - minVal : 1

            var path = Path()
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) / CGFloat(values.count - 1) * canvasSize.width
                let y = canvasSize.height - ((v - minVal) / range) * canvasSize.height
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }

            context.stroke(path, with: .color(t.ink2), lineWidth: 1.2)

            if let lastValue = values.last {
                let lastX = canvasSize.width
                let lastY = canvasSize.height - ((lastValue - minVal) / range) * canvasSize.height
                context.fill(Circle().path(in: CGRect(x: lastX - 2, y: lastY - 2, width: 4, height: 4)), with: .color(t.ink2))
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Metric Value Formatting

enum MetricFormat {
    /// Compact number: integer when whole, one decimal otherwise.
    static func number(_ value: Double) -> String {
        value == value.rounded()
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    /// Number with an optional trailing unit, e.g. "12 lbs" or "60".
    static func value(_ value: Double, unit: String) -> String {
        let n = number(value)
        return unit.isEmpty ? n : "\(n) \(unit)"
    }
}

// MARK: - Target Progress Bar (measurable goals)

/// A thin track + fill at `percentComplete` width with a small vertical tick at
/// the expected pace fraction (where the goal should be today) and a mono caption
/// like "12 / 20 lbs · 60%". Mirrors GoalListView.goalRow's 2pt bar styling.
struct TargetProgressBar: View {
    @Environment(ThemeManager.self) private var tm
    let goal: Goal
    var maxWidth: CGFloat = 200
    var showCaption: Bool = true

    var body: some View {
        let t = tm.resolved
        let percent = goal.percentComplete
        let pace = TargetMath.expectedPaceFraction(goal)
        let variance = TargetMath.variance(goal)
        let fillColor: Color = {
            switch variance {
            case .ahead: return t.ok
            case .onTrack: return t.ink
            // Non-punitive: behind pace fades to the deferred token, never red.
            case .behind: return t.deferred
            }
        }()

        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1).fill(t.hair)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(fillColor)
                        .frame(width: max(2, geo.size.width * percent))
                    // Pace tick: where the goal should be today.
                    Rectangle()
                        .fill(t.muted)
                        .frame(width: 1.5, height: 6)
                        .offset(x: geo.size.width * pace - 0.75, y: 0)
                }
            }
            .frame(height: 6)
            .frame(maxWidth: maxWidth, alignment: .leading)

            if showCaption {
                Text(captionText)
                    .font(.system(size: 10, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(t.muted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(MetricFormat.value(goal.currentValue, unit: goal.unit)) of \(MetricFormat.value(goal.targetValue, unit: goal.unit)), \(Int((percent * 100).rounded())) percent")
    }

    private var captionText: String {
        let cur = MetricFormat.number(goal.currentValue)
        let tgt = MetricFormat.number(goal.targetValue)
        let unitPart = goal.unit.isEmpty ? "" : " \(goal.unit)"
        let pct = Int((goal.percentComplete * 100).rounded())
        return "\(cur) / \(tgt)\(unitPart) · \(pct)%"
    }
}

// MARK: - Variance Pill

/// A small pill describing pace state, colored via theme danger/muted/ok.
struct VariancePill: View {
    @Environment(ThemeManager.self) private var tm
    let variance: TargetVariance

    var body: some View {
        let t = tm.resolved
        let color: Color
        let label: String
        switch variance {
        case .ahead:
            color = t.ok; label = "Ahead of pace"
        case .onTrack:
            color = t.muted; label = "On pace"
        case .behind:
            // Non-punitive: "behind" is reframed as "not yet" with the deferred token.
            color = t.deferred; label = "Not yet"
        }
        return Text(label.uppercased())
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.5))
    }
}

// MARK: - Status Dot (kept for compatibility)

struct StatusDot: View {
    let status: GoalStatus
    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        Circle()
            .fill(statusColor(t))
            .frame(width: 8, height: 8)
    }

    private func statusColor(_ t: ResolvedTheme) -> Color {
        switch status {
        case .onTrack: t.ok
        case .needsAttention: t.accent
        // Non-punitive: a slipping goal fades (deferred), never shows red.
        case .slipping: t.deferred
        case .paused: t.faint
        }
    }
}

// Legacy compatibility aliases
typealias SectionHeader = SectionLabel
typealias AccentButton = PrimaryButton
