import SwiftUI
import SwiftData

struct MentorView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MentorFeedback.createdAt, order: .reverse) private var letters: [MentorFeedback]
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    private var profile: UserProfile? { profiles.first }
    private var snapshot: IntegrationSnapshot? { snapshots.first }

    @State private var replyText = ""
    @State private var isWriting = false
    /// #8 — true while the mentor's reply is being generated, so the composer can
    /// show a thinking state and disable double-sends.
    @State private var isSendingReply = false

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
                            .font(.system(size: 28, weight: .regular, design: .serif))
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
                                    .scaleOnPress()
                            } else {
                                replyComposer(t)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Mentor")
            .navigationBarTitleDisplayMode(.inline)
        }
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
                    .font(.system(size: 16, weight: .regular, design: .serif))
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
                    .font(.system(size: 14))
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
        Button { isWriting = true } label: {
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
                .padding(14)
                .background(t.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(t.hair, lineWidth: 0.5)
                )

            HStack(spacing: 10) {
                PillButton(label: "Cancel") {
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

        let userLetter = MentorFeedback(role: "user", content: trimmed, trigger: "manual_reply")
        modelContext.insert(userLetter)
        try? modelContext.save()

        replyText = ""
        isSendingReply = true
        Haptics.light()

        let goals = (profile?.goals ?? nil) ?? []
        let snap = snapshot

        Task {
            defer {
                isSendingReply = false
                isWriting = false
            }
            // Only attempt an AI reply when AI is reachable; otherwise the user's
            // letter still stands on its own.
            guard AIConfig.isConfigured || SupabaseService.shared.isAuthenticated else { return }
            do {
                let replyContent = try await AIService.generateMentorReply(
                    userMessage: trimmed,
                    goals: goals,
                    snapshot: snap
                )
                let cleaned = replyContent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { return }
                let mentorLetter = MentorFeedback(role: "mentor", content: cleaned, trigger: "manual_reply")
                modelContext.insert(mentorLetter)
                try? modelContext.save()
                Haptics.success()
            } catch {
                ErrorLogger.log(error, context: "MentorView.sendReply")
            }
        }
    }
}
