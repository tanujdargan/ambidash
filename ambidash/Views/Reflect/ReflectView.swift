import SwiftUI
import SwiftData

struct ReflectView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]
    @Query private var profiles: [UserProfile]

    @State private var selectedTab = 0
    @State private var q1Text = ""
    @State private var q2Text = ""
    @State private var q3Text = ""
    @FocusState private var reflectionFocused: Bool
    /// Tracks a "Send to Mentor" round-trip so the primary button can show progress
    /// and not double-fire.
    @State private var isSendingToMentor = false
    /// Transient note: AI is unreachable (no key / not signed in), so M. can't reply.
    /// The letter is still saved — mirrors MentorView so the send never appears silent.
    @State private var noReplyNote = false
    /// Transient note: an attempted reply failed (network/edge/decode/empty reply).
    @State private var replyFailedNote = false
    /// CLOSING RITUAL — presents the gentle end-of-day flow (also reachable from the
    /// dashboard "Close the Day" component + the evening notification).
    @State private var showClosingRitual = false

    private var todayPlan: DailyPlan? {
        plans.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }
    }

    private var todayReflection: Reflection? {
        reflections.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }
    }

    private var todaySnapshot: IntegrationSnapshot? {
        snapshots.first
    }

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Review Type", selection: $selectedTab) {
                    Text("Daily").tag(0)
                    Text("Weekly").tag(1)
                    Text("Monthly").tag(2)
                    Text("Quarterly").tag(3)
                }
                .pickerStyle(.segmented)
                .tint(t.accent)
                .padding(.horizontal)
                .padding(.top, 8)

                if selectedTab == 0 {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            Text("EVENING · " + Date.now.formatted(.dateTime.hour().minute()))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(t.muted)
                                .padding(.horizontal, 22)
                                .padding(.top, 8)
                                .fadeSlideIn(delay: 0)

                            Text("Three questions.\nTake your time.")
                                .font(t.heading(28))
                                .tracking(-0.3)
                                .lineSpacing(2)
                                .foregroundStyle(t.ink)
                                .padding(.horizontal, 22)
                                .padding(.top, 14)
                                .fadeSlideIn(delay: 0.1)

                            // CLOSING RITUAL — gentle one-tap entry to the calm
                            // end-of-day wrap (celebrate today + tomorrow's one thing).
                            Button {
                                showClosingRitual = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "moon.stars")
                                        .font(.system(size: 13))
                                        .foregroundStyle(t.accent)
                                    Text("Close the day")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(t.ink)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(t.faint)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .background(t.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: 0.5))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 22)
                            .padding(.top, 18)
                            .fadeSlideIn(delay: 0.15)

                            // Day summary (compact)
                            if let plan = todayPlan {
                                let doneCount = (plan.actions ?? []).filter { $0.statusRaw == "done" }.count
                                let total = (plan.actions ?? []).count
                                HStack(spacing: 16) {
                                    DataRowView(label: "Done", value: "\(doneCount)/\(total)")
                                    if let snap = todaySnapshot {
                                        DataRowView(label: "Sleep", value: String(format: "%.1fh", snap.sleepHours))
                                    }
                                }
                                .padding(.horizontal, 22)
                                .padding(.top, 18)
                            }

                            // Three reflection questions
                            VStack(spacing: t.space.section) {
                                ReflectionQuestion(number: 1,
                                    question: "What did you actually do today?",
                                    hint: "Not what was on the list. What you did.",
                                    text: $q1Text,
                                    reflection: resolveReflection,
                                    photoReflection: todayReflection,
                                    focused: $reflectionFocused)
                                    .fadeSlideIn(delay: 0.2)
                                ReflectionQuestion(number: 2,
                                    question: "Where did the time you can't account for go?",
                                    hint: "Approximate is fine.",
                                    text: $q2Text,
                                    reflection: resolveReflection,
                                    photoReflection: todayReflection,
                                    focused: $reflectionFocused)
                                    .fadeSlideIn(delay: 0.3)
                                ReflectionQuestion(number: 3,
                                    question: "What is one thing tomorrow's you will need from tonight's you?",
                                    hint: "",
                                    text: $q3Text,
                                    reflection: resolveReflection,
                                    photoReflection: todayReflection,
                                    focused: $reflectionFocused)
                                    .fadeSlideIn(delay: 0.4)
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 28)

                            // Honest mirror (if saved)
                            if todayReflection != nil {
                                HonestMirrorView(plan: todayPlan, mood: todayReflection?.mood ?? "", blockers: todayReflection?.blockers ?? [])
                                    .padding(.horizontal, 22)
                                    .padding(.top, 16)
                            }

                            // Save buttons
                            HStack(spacing: 10) {
                                PillButton(label: "Save quietly") { saveReflection() }
                                Spacer()
                                PillButton(label: isSendingToMentor ? "Sending…" : "Send to Mentor", primary: true) { sendToMentor() }
                            }
                            .disabled(isSendingToMentor)
                            .padding(.horizontal, 22)
                            .padding(.top, 18)
                            .fadeSlideIn(delay: 0.5)

                            if noReplyNote {
                                mentorNoteRow(
                                    "Your letter is saved, but M. can't reply until you add an Anthropic API key in Settings → AI Configuration.",
                                    t: t
                                )
                            }

                            if replyFailedNote {
                                mentorNoteRow(
                                    "Your letter is saved, but M. couldn't reply right now — try again in a moment.",
                                    t: t
                                )
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .background(t.bg)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { reflectionFocused = false }
                        }
                    }
                } else if selectedTab == 1 {
                    WeeklyReviewView()
                } else if selectedTab == 2 {
                    MonthlyReviewView()
                } else if selectedTab == 3 {
                    QuarterlyReviewView()
                }
            }
            .background(t.bg)
            .navigationTitle("Reflect")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showClosingRitual) {
                ClosingRitualSheet()
                    .environment(tm)
            }
            .onAppear {
                if let r = todayReflection {
                    // Pre-populate from saved freeformText if present
                    let parts = r.freeformText.components(separatedBy: "\n\n")
                    q1Text = parts.indices.contains(0) ? parts[0] : ""
                    q2Text = parts.indices.contains(1) ? parts[1] : ""
                    q3Text = parts.indices.contains(2) ? parts[2] : ""
                }
            }
        }
    }

    /// Resolves today's reflection for photo attachment, creating + inserting it if it
    /// doesn't exist yet (so a photo can be attached before "Save quietly" is tapped).
    /// Idempotent: returns the same record on repeat calls within the day.
    private func resolveReflection() -> Reflection {
        if let existing = todayReflection { return existing }
        let r = Reflection()
        modelContext.insert(r)
        try? modelContext.save()
        return r
    }

    private func saveReflection() {
        let combined = [q1Text, q2Text, q3Text]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\n\n")

        if let existing = todayReflection {
            existing.freeformText = combined
        } else {
            let reflection = Reflection()
            reflection.freeformText = combined
            modelContext.insert(reflection)
        }
        try? modelContext.save()
        Task {
            await SyncService.syncReflectionToCloud(mood: "", blockers: [], text: combined)
        }
    }

    /// Saves the reflection, then sends it to the mentor as a `user` letter and
    /// appends M.'s reply — mirroring MentorView.sendReply so "Send to Mentor"
    /// actually starts a two-way exchange instead of silently saving.
    private func sendToMentor() {
        guard !isSendingToMentor else { return }
        saveReflection()

        let combined = [q1Text, q2Text, q3Text]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        guard !combined.isEmpty else { return }

        reflectionFocused = false
        let userLetter = MentorFeedback(role: "user", content: combined, trigger: "reflection")
        modelContext.insert(userLetter)
        try? modelContext.save()

        let goals = profile?.goals ?? []
        let snap = todaySnapshot
        let actions = (todayPlan?.actions ?? [])

        isSendingToMentor = true
        // Clear any prior transient notes for this fresh attempt.
        noReplyNote = false
        replyFailedNote = false
        Haptics.light()
        Task {
            defer { isSendingToMentor = false }
            // Only attempt an AI reply when AI is reachable; the user's letter still
            // stands on its own otherwise — surface a small note so the send doesn't
            // appear to silently fail.
            guard AIConfig.isConfigured || SupabaseService.shared.isAuthenticated else {
                showNoReplyNote()
                return
            }
            do {
                let replyContent = try await AIService.generateMentorReply(
                    userMessage: combined,
                    goals: goals,
                    snapshot: snap,
                    todaysActions: actions
                )
                let cleaned = replyContent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    showReplyFailedNote()
                    return
                }
                let mentorLetter = MentorFeedback(role: "mentor", content: cleaned, trigger: "reflection")
                modelContext.insert(mentorLetter)
                try? modelContext.save()
                Haptics.success()
            } catch {
                ErrorLogger.log(error, context: "ReflectView.sendToMentor")
                showReplyFailedNote()
            }
        }
    }

    /// Small italic info row shown below the Save buttons when M. can't reply.
    /// Mirrors MentorView's transient note styling (info.circle + muted serif).
    @ViewBuilder
    private func mentorNoteRow(_ text: String, t: ResolvedTheme) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(t.muted)
            Text(text)
                .font(t.body(13))
                .italic()
                .foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .fadeSlideIn(delay: 0)
    }

    /// Surface the "AI unreachable" note (no key / not signed in), then auto-dismiss.
    @MainActor private func showNoReplyNote() {
        withAnimation { noReplyNote = true }
        Task {
            try? await Task.sleep(for: .seconds(6))
            withAnimation { noReplyNote = false }
        }
    }

    /// Surface the "reply failed" note (network/edge/decode/empty), then auto-dismiss.
    @MainActor private func showReplyFailedNote() {
        withAnimation { replyFailedNote = true }
        Task {
            try? await Task.sleep(for: .seconds(6))
            withAnimation { replyFailedNote = false }
        }
    }
}

private struct ReflectionQuestion: View {
    @Environment(ThemeManager.self) private var tm
    let number: Int
    let question: String
    let hint: String
    @Binding var text: String
    /// PHOTO-OF-NOTES — resolves the reflection an attached photo binds to (created lazily).
    let reflection: () -> Reflection
    /// The current reflection (if any) whose photo thumbnails to show under this field.
    let photoReflection: Reflection?
    /// Shared focus state so the parent's keyboard "Done" toolbar can dismiss any field.
    var focused: FocusState<Bool>.Binding

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(String(format: "%02d", number))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(text.isEmpty ? t.accent : t.faint)
                    .frame(width: 18)

                Text(question)
                    .font(t.heading(17))
                    .foregroundStyle(t.ink)

                Spacer(minLength: 8)

                // PHOTO-OF-NOTES — attach a photo of notes; on-device OCR offers its text.
                ReflectionPhotoButton(text: $text, reflection: reflection)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
                // VOICE DICTATION — on-device mic streams speech into this field.
                DictationMicButton(text: $text)
                    .accessibilityIdentifier("reflect.voiceMic")
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] }
            }

            if !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
                    .padding(.leading, 28)
                    .padding(.top, 4)
            }

            TextField("tap to write…", text: $text, axis: .vertical)
                .font(t.body(14))
                .italic()
                .lineSpacing(3)
                .foregroundStyle(text.isEmpty ? t.faint : t.ink2)
                .padding(.leading, 28)
                .padding(.top, 10)
                .lineLimit(2...6)
                .focused(focused)

            // PHOTO-OF-NOTES — thumbnails of photos attached to this reflection.
            ReflectionPhotoStrip(reflection: photoReflection)
                .padding(.leading, 28)
                .padding(.top, 8)

            t.hair.frame(height: 0.5)
                .padding(.leading, 28)
                .padding(.top, 8)
        }
    }
}
