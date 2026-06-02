import SwiftUI
import SwiftData

struct MentorView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MentorFeedback.createdAt, order: .reverse) private var letters: [MentorFeedback]
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]
    // MENTOR REFOCUS — today's plan, so the mentor can speak to what the user is
    // actually doing today and surface the forward today → week → %-closer card.
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]

    private var profile: UserProfile? { profiles.first }
    private var snapshot: IntegrationSnapshot? { snapshots.first }

    /// Today's planned actions, if a plan exists for today.
    private var todaysActions: [PlannedAction] {
        let cal = Calendar.current
        guard let plan = plans.first(where: { cal.isDate($0.date, inSameDayAs: .now) }) else { return [] }
        return plan.actions ?? []
    }

    /// MENTOR REFOCUS — the live today → this-week → %-closer breakdown, computed
    /// from the goal + milestone state each render so it stays fresh as the user
    /// makes progress (NOT persisted as a letter).
    private var forwardSummary: String {
        let goals = profile?.goals ?? []
        return MentorPromptBuilder.forwardSummaryText(goals: goals, todaysActions: todaysActions)
    }

    @State private var replyText = ""
    @State private var isWriting = false
    /// #8 — true while the mentor's reply is being generated, so the composer can
    /// show a thinking state and disable double-sends.
    @State private var isSendingReply = false
    /// #8 — shown briefly after a reply is saved but no mentor response can be
    /// generated (no API key + not signed in), so the send doesn't fail silently.
    @State private var noReplyNote = false
    /// Shown briefly when a reply WAS attempted (authenticated or BYOK) but the
    /// generation failed (edge function/network/decode error, or an empty reply),
    /// so an authenticated user isn't left staring at an answer that never arrives.
    @State private var replyFailedNote = false
    /// Focus for the reply composer, so the keyboard toolbar's Done can resign it
    /// and entering the composer can auto-focus the field.
    @FocusState private var composerFocused: Bool

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MENTOR · M.")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(t.muted)

                        Text("\(letters.count) letters this week.")
                            .font(t.heading(28))
                            .tracking(-0.3)
                            .foregroundStyle(t.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 6)
                    .padding(.bottom, 14)
                    .fadeSlideIn(delay: 0)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // v4 mentor-system scaffold: opt-in + become-a-mentor progression.
                            if let profile {
                                MentorProgramCard(profile: profile)
                                    .fadeSlideIn(delay: 0.05)
                            }

                            // MENTOR REFOCUS — forward breakdown above the thread.
                            if !forwardSummary.isEmpty {
                                forwardCard(t)
                                    .fadeSlideIn(delay: 0.1)
                            }

                            if letters.isEmpty {
                                firstLetter(t)
                                    .fadeSlideIn(delay: 0.15)
                            } else {
                                ForEach(letters) { letter in
                                    if letter.role == "mentor" {
                                        mentorLetter(letter, t: t)
                                    } else {
                                        userReply(letter, t: t)
                                    }
                                }
                            }

                            // Write prompt
                            if !isWriting {
                                writePrompt(t)
                                    .fadeSlideIn(delay: 0.3)
                                    .buttonStyle(.scalePress)
                            } else {
                                replyComposer(t)
                            }

                            if noReplyNote {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(t.muted)
                                    Text("Your letter is saved, but M. can't reply until you add an Anthropic API key in Settings → AI Configuration.")
                                        .font(.system(size: 13, design: .serif))
                                        .italic()
                                        .foregroundStyle(t.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                                .fadeSlideIn(delay: 0)
                            }

                            if replyFailedNote {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(t.muted)
                                    Text("Your letter is saved, but M. couldn't reply right now — try again in a moment.")
                                        .font(.system(size: 13, design: .serif))
                                        .italic()
                                        .foregroundStyle(t.muted)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                                .fadeSlideIn(delay: 0)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 24)
                    }
                    // Let the user swipe down on the scroll to dismiss the
                    // keyboard, so the Send button is never trapped behind it.
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationTitle("Mentor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Always-reachable keyboard affordances: Done to dismiss, Send to
                // post the reply without hunting for the on-screen button.
                if composerFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Button("Done") { composerFocused = false }
                        Spacer()
                        Button("Send") { sendReply() }
                            .fontWeight(.semibold)
                            .disabled(isSendingReply || replyText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    /// MENTOR REFOCUS — a structured forward card: TODAY → THIS WEEK → PROGRESS.
    /// Rendered live from goal + milestone state (not persisted), positioned above
    /// the letter thread so the user always sees where today fits before reading M.
    @ViewBuilder
    private func forwardCard(_ t: ResolvedTheme) -> some View {
        // Group the shared summary text into its labeled sections.
        let lines = forwardSummary.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        VStack(alignment: .leading, spacing: 10) {
            Text("WHERE TODAY FITS")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(t.accent)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.hasSuffix(":") || line.uppercased() == line {
                    Text(line.replacingOccurrences(of: ":", with: ""))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(t.muted)
                        .padding(.top, 2)
                } else {
                    Text(line.hasPrefix("- ") ? String(line.dropFirst(2)) : line)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundStyle(t.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .leading) {
            t.accent.frame(width: 2).clipShape(RoundedRectangle(cornerRadius: 1)).padding(.vertical, 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func firstLetter(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FIRST LETTER")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(t.muted)
                .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 14) {
                Text("We've only just met, so I'll keep this short.")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .italic()
                    .lineSpacing(4)
                    .foregroundStyle(t.ink)

                Text("I am not going to make you a list. I am going to ask you one question every morning, and a different one most evenings. I will tell you when you are drifting, and I will be quieter on the days you are doing well.")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .italic()
                    .lineSpacing(4)
                    .foregroundStyle(t.ink)

                Text("The shape of this work is patience.")
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .italic()
                    .lineSpacing(4)
                    .foregroundStyle(t.ink)

                Text("— M.")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(t.muted)
                    .padding(.top, 4)
            }
            .padding(18)
            .background(t.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .leading) {
                t.accent.frame(width: 2).clipShape(RoundedRectangle(cornerRadius: 1)).padding(.vertical, 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func mentorLetter(_ letter: MentorFeedback, t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(letter.createdAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()).uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(t.muted)

            VStack(alignment: .leading, spacing: 10) {
                Text(letter.content)
                    // Use the theme body font so the Typography lever genuinely
                    // changes running prose (serif / default / monospaced), not
                    // just headings.
                    .font(t.body(16))
                    .italic()
                    .lineSpacing(4)
                    .foregroundStyle(t.ink)

                Text("— M.")
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(t.muted)
            }
            .padding(16)
            .background(t.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .leading) {
                t.accent.frame(width: 2).clipShape(RoundedRectangle(cornerRadius: 1)).padding(.vertical, 1)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5)
            )
        }
    }

    @ViewBuilder
    private func userReply(_ letter: MentorFeedback, t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR REPLY · " + letter.createdAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()).uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(t.muted)

            VStack(alignment: .leading, spacing: 8) {
                Text(letter.content)
                    .font(t.body(14))
                    .lineSpacing(3)
                    .foregroundStyle(t.ink2)

                Text("YOU")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(t.faint)
            }
            .padding(14)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5)
            )
            .padding(.leading, 32)
        }
    }

    @ViewBuilder
    private func writePrompt(_ t: ResolvedTheme) -> some View {
        Button {
            isWriting = true
            composerFocused = true
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(t.accent)
                    .frame(width: 6, height: 6)
                Text("Write back when you're ready — there's no clock on a letter.")
                    .font(.system(size: 14, design: .serif))
                    .italic()
                    .foregroundStyle(t.ink2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                    .foregroundStyle(t.rule)
            )
        }
    }

    @ViewBuilder
    private func replyComposer(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Write your reply...", text: $replyText, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(t.ink)
                .lineLimit(4...8)
                .focused($composerFocused)
                .padding(14)
                .background(t.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: 0.5)
                )

            HStack(spacing: 10) {
                PillButton(label: "Cancel") {
                    composerFocused = false
                    isWriting = false
                    replyText = ""
                }
                .disabled(isSendingReply)
                Spacer()
                PillButton(label: isSendingReply ? "M. is reading…" : "Send to Mentor", primary: true) {
                    sendReply()
                }
                .disabled(isSendingReply || replyText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    /// #8 — two-way mentor exchange. Persists the user's letter, then calls the AI
    /// to generate M.'s reply and appends it as a `mentor` MentorFeedback so the
    /// thread reads as a real back-and-forth. The user's letter is saved
    /// immediately so it isn't lost if the AI call fails; on failure the composer
    /// simply closes without a reply.
    private func sendReply() {
        let trimmed = replyText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isSendingReply else { return }

        // Dismiss the keyboard immediately so the thread (and the "M. is reading…"
        // state) is visible while the reply generates.
        composerFocused = false

        let userLetter = MentorFeedback(role: "user", content: trimmed, trigger: "manual_reply")
        modelContext.insert(userLetter)
        try? modelContext.save()

        replyText = ""
        isSendingReply = true
        // Clear any prior transient notes for this fresh attempt.
        noReplyNote = false
        replyFailedNote = false
        Haptics.light()

        let goals = profile?.goals ?? []
        let snap = snapshot
        // MENTOR REFOCUS — capture today's actions so the reply can speak to what
        // the user is actually doing today.
        let actions = todaysActions

        Task {
            defer {
                isSendingReply = false
                isWriting = false
            }
            // Only attempt an AI reply when AI is reachable; otherwise the user's
            // letter still stands on its own — surface a small note so the send
            // doesn't appear to silently fail.
            guard AIConfig.isConfigured || SupabaseService.shared.isAuthenticated else {
                withAnimation { noReplyNote = true }
                Task {
                    try? await Task.sleep(for: .seconds(6))
                    withAnimation { noReplyNote = false }
                }
                return
            }
            do {
                let replyContent = try await AIService.generateMentorReply(
                    userMessage: trimmed,
                    goals: goals,
                    snapshot: snap,
                    todaysActions: actions
                )
                let cleaned = replyContent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else {
                    showReplyFailedNote()
                    return
                }
                let mentorLetter = MentorFeedback(role: "mentor", content: cleaned, trigger: "manual_reply")
                modelContext.insert(mentorLetter)
                try? modelContext.save()
                Haptics.success()
            } catch {
                ErrorLogger.log(error, context: "MentorView.sendReply")
                showReplyFailedNote()
            }
        }
    }

    /// Surface a transient note when an attempted reply failed (edge function/
    /// network/decode error, or an empty reply), then auto-dismiss it.
    @MainActor private func showReplyFailedNote() {
        withAnimation { replyFailedNote = true }
        Task {
            try? await Task.sleep(for: .seconds(6))
            withAnimation { replyFailedNote = false }
        }
    }
}
