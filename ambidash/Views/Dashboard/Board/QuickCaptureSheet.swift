import SwiftUI
import SwiftData

/// The <2-second universal capture entry point (design principle #4). A single
/// auto-focused text field and one "Capture" action — NO category, NO goal, NO due
/// date. The thought lands in the inbox and the field clears so consecutive dumps
/// stay in flow (they burst-group automatically via `CaptureService`). The sheet
/// stays open across captures so a brain-dump session is one gesture; "Done"
/// dismisses. Calm, motion-respecting, never a form.
struct QuickCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm

    @State private var text: String = ""
    /// A tiny, transient confirmation line ("Captured.") after each save, so the
    /// user gets quiet feedback without leaving the field.
    @State private var justCaptured: Bool = false
    /// How many landed this session — a gentle, non-pressuring count.
    @State private var sessionCount: Int = 0
    @FocusState private var fieldFocused: Bool

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    Text("What's on your mind?")
                        .font(t.heading(22))
                        .foregroundStyle(t.ink)
                        .padding(.top, 8)

                    Text("Dump it here — no category needed. Sort it later, or never.")
                        .font(.system(size: 13))
                        .foregroundStyle(t.muted)

                    // Multiline capture: a vertical-axis TextField inserts a newline on
                    // return (it ignores submitLabel/onSubmit), so the keyboard Capture
                    // button below is the explicit submit path for the burst-dump flow.
                    TextField("", text: $text, axis: .vertical)
                        .font(.system(size: 16))
                        .foregroundStyle(t.ink)
                        .tint(t.accent)
                        .lineLimit(1...6)
                        .focused($fieldFocused)
                        .padding(14)
                        .background(t.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: 0.5))
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("a thought, a task, a someday…")
                                    .font(.system(size: 16))
                                    .foregroundStyle(t.faint)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 22)
                                    .allowsHitTesting(false)
                            }
                        }

                    HStack(spacing: 10) {
                        if justCaptured {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(t.ok)
                                Text(sessionCount == 1 ? "Captured." : "\(sessionCount) captured.")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(t.muted)
                            }
                            .transition(.opacity)
                        }
                        Spacer()
                        Button(action: captureCurrent) {
                            Text("Capture")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(canCapture ? t.bg : t.faint)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(canCapture ? AnyShapeStyle(t.accent) : AnyShapeStyle(t.surface))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.scalePress)
                        .disabled(!canCapture)
                        .accessibilityLabel("Capture thought")
                    }

                    Spacer()
                }
                .padding(.horizontal, 22)
            }
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Capture", action: captureCurrent)
                        .disabled(!canCapture)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { fieldFocused = true }
    }

    private var canCapture: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Persist the current text, clear the field, and keep focus for the next dump.
    private func captureCurrent() {
        guard canCapture else { return }
        guard CaptureService.capture(text, in: modelContext) != nil else { return }
        Haptics.light()
        text = ""
        sessionCount += 1
        withAnimation(MotionPreference.animation(.ambidashSpring)) { justCaptured = true }
        fieldFocused = true
    }
}
