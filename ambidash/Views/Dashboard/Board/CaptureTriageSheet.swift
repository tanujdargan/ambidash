import SwiftUI
import SwiftData

/// The gentle triage flow for ONE inbox item (design principle #4). It shows the
/// captured thought and four one-tap outcomes — make a goal, add to today, keep
/// (archive), or drop — never pressuring, never a red "unprocessed" verdict.
///
/// On appear it asks `CaptureDecomposeService` for a SUGGESTION (on-device
/// Foundation Models → BYOK → plain heuristic) and gently pre-highlights the
/// suggested action + offers the model's refined title. The suggestion is a
/// convenience: every action is always available and the user can ignore it. If no
/// model is present the heuristic still pre-selects something sensible, so triage is
/// fully usable with zero AI.
struct CaptureTriageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm

    let item: CaptureItem

    @State private var suggestion: CaptureDecomposeService.Suggestion?
    @State private var loadingSuggestion = true

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        thought(t)
                        suggestionBanner(t)
                        actions(t)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                }
            }
            .navigationTitle("Triage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await loadSuggestion() }
    }

    // MARK: - Sections

    @ViewBuilder
    private func thought(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(title: "You captured")
            Text(item.text)
                .font(t.heading(19))
                .foregroundStyle(t.ink)
                .lineSpacing(3)
        }
    }

    @ViewBuilder
    private func suggestionBanner(_ t: ResolvedTheme) -> some View {
        if loadingSuggestion {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(t.accent)
                Text("Thinking about this gently…")
                    .font(.system(size: 12))
                    .foregroundStyle(t.muted)
            }
        } else if let s = suggestion, s.kind != .unknown {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundStyle(t.accent)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestionLine(s))
                        .font(.system(size: 12))
                        .foregroundStyle(t.ink2)
                    Text(originLine(s.origin))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(t.faint)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 11))
        }
    }

    @ViewBuilder
    private func actions(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 10) {
            triageButton(
                .makeGoal, title: "Make a goal", icon: "flag", t: t,
                highlighted: suggested == .makeGoal
            ) { promoteToGoal() }

            triageButton(
                .makeTask, title: "Add to today", icon: "circle", t: t,
                highlighted: suggested == .makeTask
            ) { promoteToTask() }

            triageButton(
                .archive, title: "Keep it, set aside", icon: "archivebox", t: t,
                highlighted: suggested == .archive
            ) { archive() }

            // Drop is intentionally the quietest, most muted option — never the
            // visually loud default, and never framed as failure.
            triageButton(
                .drop, title: "Let it go", icon: "xmark", t: t,
                highlighted: false, muted: true
            ) { drop() }
        }
    }

    @ViewBuilder
    private func triageButton(
        _ action: CaptureTriageAction,
        title: String,
        icon: String,
        t: ResolvedTheme,
        highlighted: Bool,
        muted: Bool = false,
        perform: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.light()
            perform()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(muted ? t.faint : (highlighted ? t.accent : t.muted))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 15, weight: highlighted ? .semibold : .regular))
                    .foregroundStyle(muted ? t.muted : t.ink)
                Spacer()
                if highlighted {
                    Text("suggested")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(t.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlighted ? AnyShapeStyle(t.accentSoft) : AnyShapeStyle(t.surface))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(highlighted ? t.accent.opacity(0.4) : t.hair, lineWidth: highlighted ? 1 : 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    // MARK: - Suggestion plumbing

    private var suggested: CaptureTriageAction? { suggestion?.suggestedAction }

    private func suggestionLine(_ s: CaptureDecomposeService.Suggestion) -> String {
        switch s.kind {
        case .task:
            if let m = s.durationMinutes { return "Looks like a small task (~\(m) min)." }
            return "Looks like a small task."
        case .goal: return "Reads like a longer-range goal."
        case .note: return "Feels more like a note to keep."
        case .unknown: return ""
        }
    }

    private func originLine(_ origin: CaptureDecomposeService.Suggestion.Origin) -> String {
        switch origin {
        case .onDevice: return "on-device · private"
        case .byok: return "your AI key"
        case .heuristic: return "quick guess"
        }
    }

    /// The title to use when promoting: prefer the model's calm restatement, fall
    /// back to the raw captured text.
    private var promoteTitle: String {
        let refined = suggestion?.refinedTitle.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return refined.isEmpty ? item.text : refined
    }

    private func loadSuggestion() async {
        let result = await CaptureDecomposeService.suggest(for: item.text)
        await MainActor.run {
            withAnimation(MotionPreference.animation(.ambidashSpring)) {
                suggestion = result
                loadingSuggestion = false
            }
        }
    }

    // MARK: - Actions (each dismisses after its gentle transition)

    private func promoteToGoal() {
        let goal = CaptureService.promoteToGoal(item, in: modelContext)
        goal.title = promoteTitle
        try? modelContext.save()
        dismiss()
    }

    private func promoteToTask() {
        let action = CaptureService.promoteToTodayTask(item, in: modelContext)
        action.title = promoteTitle
        if let minutes = suggestion?.durationMinutes, minutes > 0 {
            action.durationMinutes = minutes
        }
        try? modelContext.save()
        dismiss()
    }

    private func archive() {
        CaptureService.archive(item, in: modelContext)
        dismiss()
    }

    private func drop() {
        CaptureService.drop(item, in: modelContext)
        dismiss()
    }
}
