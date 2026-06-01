import SwiftUI
import SwiftData

/// CAPTURE on macOS (design principle #4 — the universal <2-second dump, the app's
/// single most-validated feature). The service layer (`CaptureService`) is already
/// platform-agnostic and the `CaptureItem` model is registered in the mac
/// ModelContainer; only the desktop UI was missing. This file supplies both:
///
///  • `MacCaptureCard` — an inbox surface for the dashboard: an inline capture
///    field plus the recent un-triaged items, each with one-tap gentle triage
///    (Goal / Today / Keep / Drop) reusing the shared `CaptureService` transitions.
///  • `MacCaptureSheet` — a focused capture sheet presented from the Cmd-K
///    "New Capture" command, mirroring the iOS QuickCaptureSheet's burst-dump flow.
///
/// Calm, never a form, never a red "unprocessed" badge — an un-triaged inbox just
/// waits.

/// A dashboard card: capture a thought inline, and triage what's waiting.
struct MacCaptureCard: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext

    /// Recent un-triaged captures, newest first. A small @Query (the inbox is meant
    /// to stay shallow); CloudKit syncs whatever was captured on iPhone into here.
    @Query(
        filter: #Predicate<CaptureItem> { $0.statusRaw == "inbox" },
        sort: \CaptureItem.createdAt,
        order: .reverse
    ) private var inbox: [CaptureItem]

    @State private var draft: String = ""
    @FocusState private var fieldFocused: Bool

    private var canCapture: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let theme = tm.resolved
        MacCard("Capture") {
            Text("Dump a thought — no category needed. Sort it later, or never.")
                .font(theme.body(12))
                .foregroundStyle(theme.muted)

            // Inline <2s capture path.
            HStack(spacing: 10) {
                TextField("a thought, a task, a someday…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(theme.body(14))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1...4)
                    .focused($fieldFocused)
                    .onSubmit(captureCurrent)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.sunken)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(theme.hair, lineWidth: 1)
                    )

                Button(action: captureCurrent) {
                    Text("Capture")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(canCapture ? theme.bg : theme.faint)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(canCapture ? AnyShapeStyle(theme.accent) : AnyShapeStyle(theme.surface))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canCapture)
            }

            if inbox.isEmpty {
                Text("Nothing waiting. Captures from any device land here.")
                    .font(theme.body(13))
                    .foregroundStyle(theme.muted)
                    .padding(.top, 2)
            } else {
                Divider().overlay(theme.hair)
                ForEach(inbox) { item in
                    MacCaptureRow(item: item)
                    if item.id != inbox.last?.id {
                        Divider().overlay(theme.hair)
                    }
                }
            }
        }
    }

    private func captureCurrent() {
        guard canCapture else { return }
        guard CaptureService.capture(draft, in: modelContext) != nil else { return }
        draft = ""
        fieldFocused = true
    }
}

/// One inbox row: the thought + its four gentle triage actions. Each maps directly
/// to a shared `CaptureService` transition, so triage behaves identically to iOS.
private struct MacCaptureRow: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    let item: CaptureItem

    var body: some View {
        let theme = tm.resolved
        VStack(alignment: .leading, spacing: 8) {
            Text(item.text)
                .font(theme.body(14))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                triageButton("Goal", "flag", theme) {
                    CaptureService.promoteToGoal(item, in: modelContext)
                }
                triageButton("Today", "calendar", theme) {
                    CaptureService.promoteToTodayTask(item, in: modelContext)
                }
                triageButton("Keep", "archivebox", theme) {
                    CaptureService.archive(item, in: modelContext)
                }
                triageButton("Drop", "xmark", theme) {
                    CaptureService.drop(item, in: modelContext)
                }
                Spacer()
                Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(theme.faint)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func triageButton(_ label: String, _ icon: String, _ theme: ResolvedTheme, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.sunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(theme.hair, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// A focused capture sheet presented from the Cmd-K "New Capture" command. Stays
/// open across captures so a brain-dump session is one flow (they burst-group via
/// CaptureService), with a quiet "N captured" confirmation — mirroring iOS.
struct MacCaptureSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var sessionCount: Int = 0
    @FocusState private var fieldFocused: Bool

    private var canCapture: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let theme = tm.resolved
        VStack(alignment: .leading, spacing: 16) {
            Text("What's on your mind?")
                .font(theme.heading(22))
                .foregroundStyle(theme.ink)

            Text("Dump it here — no category needed. Sort it later, or never.")
                .font(theme.body(13))
                .foregroundStyle(theme.muted)

            TextField("a thought, a task, a someday…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(theme.body(15))
                .foregroundStyle(theme.ink)
                .lineLimit(2...8)
                .focused($fieldFocused)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.sunken)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.hair, lineWidth: 1)
                )

            HStack(spacing: 10) {
                if sessionCount > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.ok)
                        Text(sessionCount == 1 ? "Captured." : "\(sessionCount) captured.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(theme.muted)
                    }
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(action: captureCurrent) {
                    Text("Capture")
                        .font(.system(size: 13, weight: .semibold))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canCapture)
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(theme.bg)
        .onAppear { fieldFocused = true }
    }

    private func captureCurrent() {
        guard canCapture else { return }
        guard CaptureService.capture(text, in: modelContext) != nil else { return }
        text = ""
        sessionCount += 1
        fieldFocused = true
    }
}
