import SwiftUI
import SwiftData

#if os(iOS)
/// Voice conversation with M. — a sheet that cycles through:
///   1. Listening (dictation via `DictationService`)
///   2. Thinking (AI generates reply via `AIService.generateMentorReply`)
///   3. Speaking (TTS playback via `MentorVoiceService`)
///
/// The conversation is displayed as a scrolling thread of text bubbles (user on
/// the right, mentor on the left) with a pulsing mic indicator at the bottom.
struct MentorConversationView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]

    private var profile: UserProfile? { profiles.first }
    private var snapshot: IntegrationSnapshot? { snapshots.first }
    private var todaysActions: [PlannedAction] {
        let cal = Calendar.current
        guard let plan = plans.first(where: { cal.isDate($0.date, inSameDayAs: .now) }) else { return [] }
        return plan.actions ?? []
    }

    @State private var dictation = DictationService()
    @State private var voiceService = MentorVoiceService()
    @State private var turns: [ConversationTurn] = []
    @State private var phase: ConversationPhase = .idle

    /// Tracks the latest transcript chunk so we can detect deltas.
    @State private var lastCommittedTranscript = ""

    enum ConversationPhase: Equatable {
        case idle
        case listening
        case thinking
        case speaking
        case error(String)
    }

    struct ConversationTurn: Identifiable {
        let id = UUID()
        let role: String   // "user" or "mentor"
        let text: String
    }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Conversation thread
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 14) {
                                // Opening prompt when thread is empty
                                if turns.isEmpty && phase == .idle {
                                    emptyState(t)
                                }

                                ForEach(turns) { turn in
                                    turnBubble(turn, t: t)
                                }

                                // Live transcript while listening
                                if phase == .listening && !dictation.transcript.isEmpty {
                                    liveTranscriptBubble(t)
                                }

                                // Status indicator
                                if phase == .thinking {
                                    thinkingIndicator(t)
                                        .id("bottom")
                                }

                                if phase == .speaking {
                                    speakingIndicator(t)
                                        .id("bottom")
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 16)
                        }
                        .onChange(of: turns.count) {
                            withAnimation {
                                proxy.scrollTo(turns.last?.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: phase) {
                            withAnimation {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }

                    // Bottom controls
                    controlBar(t)
                }
            }
            .navigationTitle("Talk to M.")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { cleanup(); dismiss() }
                        .foregroundStyle(t.ink)
                }
            }
            .onChange(of: dictation.transcript) { _, newValue in
                // Track live transcript — we don't commit here, only on stop.
            }
            .onChange(of: voiceService.state) { _, newState in
                // When TTS finishes speaking, return to idle.
                if newState == .idle && phase == .speaking {
                    phase = .idle
                }
            }
            .onDisappear { cleanup() }
        }
    }

    // MARK: - Empty state

    @ViewBuilder
    private func emptyState(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 36))
                .foregroundStyle(t.accent.opacity(0.6))

            Text("Tap the mic to start a conversation with M.")
                .font(.system(size: 15, design: .serif))
                .italic()
                .foregroundStyle(t.muted)
                .multilineTextAlignment(.center)

            Text("Your voice is transcribed on-device and never leaves your phone.")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(t.faint)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
        .padding(.horizontal, 20)
    }

    // MARK: - Bubbles

    @ViewBuilder
    private func turnBubble(_ turn: ConversationTurn, t: ResolvedTheme) -> some View {
        if turn.role == "user" {
            HStack {
                Spacer(minLength: 60)
                Text(turn.text)
                    .font(t.body(14))
                    .lineSpacing(3)
                    .foregroundStyle(t.ink)
                    .padding(14)
                    .background(t.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        } else {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(turn.text)
                        .font(t.body(15))
                        .italic()
                        .lineSpacing(4)
                        .foregroundStyle(t.ink)

                    Text("— M.")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(t.muted)
                }
                .padding(14)
                .background(t.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .leading) {
                    t.accent.frame(width: 2)
                        .clipShape(RoundedRectangle(cornerRadius: 1))
                        .padding(.vertical, 1)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14).stroke(t.hair, lineWidth: 0.5)
                )
                Spacer(minLength: 40)
            }
        }
    }

    @ViewBuilder
    private func liveTranscriptBubble(_ t: ResolvedTheme) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(dictation.transcript)
                .font(t.body(14))
                .lineSpacing(3)
                .foregroundStyle(t.ink.opacity(0.6))
                .padding(14)
                .background(t.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(t.accent.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                )
        }
    }

    @ViewBuilder
    private func thinkingIndicator(_ t: ResolvedTheme) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(t.accent)
            Text("M. is thinking...")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func speakingIndicator(_ t: ResolvedTheme) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(t.accent)
                .symbolEffect(.variableColor.iterative, isActive: true)
            Text("M. is speaking...")
                .font(.system(size: 13, design: .serif))
                .italic()
                .foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Control bar

    @ViewBuilder
    private func controlBar(_ t: ResolvedTheme) -> some View {
        VStack(spacing: 0) {
            t.hair.frame(height: 0.5)

            HStack(spacing: 20) {
                Spacer()

                // Mic button
                Button {
                    Task { await handleMicTap() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(phase == .listening ? t.accent : t.accent.opacity(0.12))
                            .frame(width: 56, height: 56)
                            .scaleEffect(phase == .listening ? 1.08 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: phase == .listening)

                        if dictation.status == .preparing {
                            ProgressView()
                                .controlSize(.regular)
                                .tint(t.accent)
                        } else {
                            Image(systemName: micSymbol)
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(phase == .listening ? t.bg : t.accent)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(phase == .thinking || phase == .speaking || dictation.status == .preparing)
                .accessibilityLabel(phase == .listening ? "Stop listening" : "Start listening")

                Spacer()
            }
            .padding(.vertical, 16)
            .background(t.bg)
        }
    }

    private var micSymbol: String {
        switch phase {
        case .listening: return "mic.fill"
        case .thinking, .speaking: return "ellipsis"
        default:
            switch dictation.status {
            case .denied, .unavailable: return "mic.slash"
            default: return "mic"
            }
        }
    }

    // MARK: - Interaction

    private func handleMicTap() async {
        if phase == .listening {
            // Stop listening and process
            dictation.stop()
            let spoken = dictation.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !spoken.isEmpty else {
                phase = .idle
                return
            }
            turns.append(ConversationTurn(role: "user", text: spoken))
            Haptics.light()
            await generateAndSpeak(userText: spoken)
        } else if phase == .idle {
            // Start listening
            phase = .listening
            Haptics.light()
            await dictation.start()
            // If dictation failed to start, revert.
            if dictation.status != .recording && dictation.status != .preparing {
                phase = .idle
            }
        }
    }

    private func generateAndSpeak(userText: String) async {
        phase = .thinking
        let goals = profile?.goals ?? []
        let snap = snapshot
        let actions = todaysActions

        guard AIConfig.isConfigured || SupabaseService.shared.isAuthenticated else {
            let fallback = "I'd like to reply, but I need an API key configured in Settings to think clearly. Your words are saved."
            turns.append(ConversationTurn(role: "mentor", text: fallback))
            phase = .idle
            return
        }

        do {
            let replyContent = try await AIService.generateMentorReply(
                userMessage: userText,
                goals: goals,
                snapshot: snap,
                todaysActions: actions
            )
            let cleaned = replyContent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                turns.append(ConversationTurn(role: "mentor", text: "I heard you, but couldn't gather my thoughts. Try again in a moment."))
                phase = .idle
                return
            }

            turns.append(ConversationTurn(role: "mentor", text: cleaned))

            // Persist the exchange as MentorFeedback entries
            let userFeedback = MentorFeedback(role: "user", content: userText, trigger: "voice_conversation")
            let mentorFeedback = MentorFeedback(role: "mentor", content: cleaned, trigger: "voice_conversation")
            modelContext.insert(userFeedback)
            modelContext.insert(mentorFeedback)
            try? modelContext.save()

            // Speak the reply aloud
            phase = .speaking
            voiceService.speak(cleaned)
        } catch {
            ErrorLogger.log(error, context: "MentorConversationView.generateAndSpeak")
            turns.append(ConversationTurn(role: "mentor", text: "Something went wrong. Try again in a moment."))
            phase = .idle
        }
    }

    private func cleanup() {
        dictation.stop()
        voiceService.stop()
    }
}
#endif
