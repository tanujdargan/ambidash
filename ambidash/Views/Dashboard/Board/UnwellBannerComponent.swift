import SwiftUI
import SwiftData

/// Recovery-mode banner shown when the user has flagged "I'm not feeling well".
/// Displays a gentle message, the day count, and a single "I'm feeling better"
/// dismissal. Renders nothing when `isUnwellMode` is false. Owns a small @Query
/// for UserPreferences (mutated on dismiss), so it is intentionally NOT fed from
/// the static BoardData snapshot.
struct UnwellBannerComponent: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query private var prefsList: [UserPreferences]

    private var prefs: UserPreferences? { prefsList.first }

    private var dayCount: Int {
        guard let since = prefs?.unwellSince else { return 1 }
        let days = Calendar.current.dateComponents([.day], from: since, to: .now).day ?? 0
        return max(1, days + 1)
    }

    var body: some View {
        let t = tm.resolved
        if let p = prefs, p.isUnwellMode {
            card(t, dayCount: dayCount, dismiss: {
                p.isUnwellMode = false
                p.unwellSince = nil
                try? modelContext.save()
            })
        }
    }

    @ViewBuilder
    private func card(_ t: ResolvedTheme, dayCount: Int, dismiss: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: t.space.component) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "heart")
                    .font(.system(size: 14))
                    .foregroundStyle(t.accent)
                Text("Recovery mode")
                    .font(t.heading(15))
                    .foregroundStyle(t.ink)
            }

            Text("Take it easy. Only essentials today.")
                .font(t.body(13))
                .foregroundStyle(t.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Day \(dayCount) \u{2014} no rush.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(t.faint)

            Button {
                Haptics.success()
                dismiss()
            } label: {
                Text("I\u{2019}m feeling better")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(t.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(t.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("component.unwellBanner")
    }
}
