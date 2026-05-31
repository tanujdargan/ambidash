import SwiftUI
import SwiftData

/// ENERGY / spoons (design principle #6) — a one-tap, <2-second energy check-in as a
/// dashboard component. Five gentle battery glyphs; tap one and it's logged. NEVER
/// punitive: a low reading is information, not failure (no red, no "you're depleted"
/// scolding). When the user has already checked in recently the component shows that
/// reading calmly with a quiet "tap to update".
///
/// Owns a small `@Query` for today's check-ins (inherently mutated by tapping), like
/// CaptureInboxComponent — so it is intentionally NOT fed from the static BoardData
/// snapshot.
struct EnergyCheckinComponent: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    /// Today's check-ins, newest first. Filtered to today so the component reflects
    /// "how are you right now" rather than history.
    @Query(sort: \EnergyCheckin.date, order: .reverse)
    private var allCheckins: [EnergyCheckin]

    @State private var justLogged = false

    private var todayCheckins: [EnergyCheckin] {
        let cal = Calendar.current
        return allCheckins.filter { cal.isDateInToday($0.date) }
    }

    private var latest: EnergyCheckin? { todayCheckins.first }

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: t.space.component) {
            header(t)
            picker(t)
            if let latest {
                Text(footnote(for: latest))
                    .font(.system(size: 11))
                    .foregroundStyle(t.muted)
            } else {
                Text("Tap how much you've got — takes a second, never a judgment.")
                    .font(.system(size: 11))
                    .foregroundStyle(t.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .animation(MotionPreference.animation(.ambidashSpring), value: latest?.id)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Energy check-in")
    }

    @ViewBuilder
    private func header(_ t: ResolvedTheme) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(title: "Energy")
            Spacer()
            if let latest {
                Text(EnergyLevel.resolve(latest.clampedLevel).shortLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
        }
    }

    @ViewBuilder
    private func picker(_ t: ResolvedTheme) -> some View {
        let current = latest?.clampedLevel
        HStack(spacing: 8) {
            ForEach(EnergyLevel.allCases) { level in
                let on = current == level.rawValue
                Button {
                    log(level.rawValue)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: level.symbol)
                            .font(.system(size: 18))
                            .foregroundStyle(on ? t.accent : t.muted)
                        Text(level.shortLabel)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(on ? t.ink : t.faint)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(on ? t.accentSoft : t.sunken.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(on ? t.accent.opacity(0.5) : t.hair.opacity(0.6), lineWidth: on ? 1 : 0.5)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .scaleOnPress()
                .accessibilityLabel(level.label)
            }
        }
    }

    private func footnote(for checkin: EnergyCheckin) -> String {
        let rel = checkin.date.formatted(.relative(presentation: .named))
        return "\(EnergyLevel.resolve(checkin.clampedLevel).label) · \(rel) · tap to update"
    }

    /// Log (or update) the current energy. To keep the inbox of check-ins clean, an
    /// update within the same hour overwrites the most recent reading rather than
    /// stacking a near-duplicate; otherwise a fresh check-in is recorded.
    private func log(_ level: Int) {
        Haptics.success()
        if let recent = latest,
           Date.now.timeIntervalSince(recent.date) < 3600 {
            recent.level = max(1, min(5, level))
            recent.date = .now
        } else {
            let checkin = EnergyCheckin(date: .now, level: level, note: "")
            modelContext.insert(checkin)
        }
        try? modelContext.save()
    }
}
