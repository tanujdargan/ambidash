import SwiftUI
import SwiftData

/// v4: a "sticky note" surface — goals the user pinned (Goal.isSticky) stay
/// always-visible but glanceable, like a note on the cover of a notebook: there
/// when you want it, never in your face. For must-not-forget goals that aren't
/// top priority. Owns a small @Query (sticky goals aren't in the shared BoardData).
struct StickyGoalsComponent: View {
    @Environment(ThemeManager.self) private var tm

    @Query(filter: #Predicate<Goal> { $0.isSticky }, sort: \Goal.priority)
    private var stickies: [Goal]

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: t.space.component) {
            SectionLabel(title: "Sticky Notes")

            if stickies.isEmpty {
                Text("Pin a goal here to keep it in view — for what matters but isn't urgent.")
                    .font(t.body(12))
                    .foregroundStyle(t.faint)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(stickies) { goal in
                            noteCard(goal, t)
                        }
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
        .accessibilityIdentifier("component.stickyGoals")
    }

    @ViewBuilder
    private func noteCard(_ goal: Goal, _ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "pin.fill")
                .font(.system(size: 9))
                .foregroundStyle(t.accent)
            Text(goal.title)
                .font(t.body(13))
                .foregroundStyle(t.ink)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 128, height: 84, alignment: .topLeading)
        .background(t.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.accent.opacity(0.25), lineWidth: 0.5))
    }
}
