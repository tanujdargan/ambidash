import SwiftUI
import SwiftData

/// v4 goal-workflow: a CONTEXTUAL wake-adjust nudge. When the actual wake time
/// (recorded on first daily open by WakeTracker) drifts late of the `wakeTime`
/// target by an hour or more, gently offer to re-adjust — EITHER right-size the
/// wake goal OR pull the wind-down earlier to support it. Renders nothing when
/// you're on track, so it never nags. Non-punitive: "right-sized", never "you
/// failed to wake up".
struct WakeAdjustComponent: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query private var prefsList: [UserPreferences]

    private var prefs: UserPreferences? { prefsList.first }

    /// Minutes the actual wake ran LATE of the target (nil if unknown / on time).
    private var lateBy: Int? {
        guard let p = prefs, p.lastActualWakeMinutes >= 0,
              let target = Self.minutes(p.wakeTime) else { return nil }
        let d = p.lastActualWakeMinutes - target
        return d >= 60 ? d : nil   // only surface a meaningful (>=1h) drift
    }

    var body: some View {
        let t = tm.resolved
        if let p = prefs, let late = lateBy {
            card(p, late: late, t: t)
        }
        // else: render nothing — no nudge when you're on track.
    }

    @ViewBuilder
    private func card(_ p: UserPreferences, late: Int, t: ResolvedTheme) -> some View {
        let actual = p.lastActualWakeMinutes
        VStack(alignment: .leading, spacing: t.space.component) {
            SectionLabel(title: "Wake Check")

            Text("You started today around \(Self.clock(actual)) — your wake goal is \(p.wakeTime). Want to right-size it?")
                .font(t.body(14))
                .foregroundStyle(t.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                adjustButton("Make \(Self.clock(actual)) my goal", t: t) {
                    p.wakeTime = Self.clock(actual)
                    try? modelContext.save()
                }
                adjustButton("Wind down 30m earlier", t: t) {
                    if let s = Self.minutes(p.sleepTime) {
                        p.sleepTime = Self.clock(max(0, s - 30))
                        try? modelContext.save()
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("component.wakeAdjust")
    }

    @ViewBuilder
    private func adjustButton(_ label: String, t: ResolvedTheme, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(t.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(t.accentSoft)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    static func minutes(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }

    static func clock(_ mins: Int) -> String {
        String(format: "%02d:%02d", (mins / 60) % 24, mins % 60)
    }
}
