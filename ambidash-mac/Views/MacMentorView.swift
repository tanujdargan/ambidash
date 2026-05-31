import SwiftUI
import SwiftData

/// Desktop Mentor: read the running mentor correspondence and write a new
/// message to get an AI reply. Both the user's note and the mentor's reply are
/// persisted as `MentorFeedback` rows in the shared, CloudKit-synced store.
struct MacMentorView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var context

    @Query(sort: \MentorFeedback.createdAt, order: .reverse) private var letters: [MentorFeedback]
    @Query(filter: #Predicate<Goal> { $0.isActive }) private var goals: [Goal]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]

    @State private var message = ""
    @State private var isSending = false
    @State private var errorText: String?

    /// Today's planned actions, if a plan exists for today.
    private var todaysActions: [PlannedAction] {
        let plan = plans.first { Calendar.current.isDateInToday($0.date) }
        return plan?.actions ?? []
    }

    /// The live today → this-week → %-closer breakdown, mirroring iOS' forward card.
    private var forwardSummary: String {
        MentorPromptBuilder.forwardSummaryText(goals: goals, todaysActions: todaysActions)
    }

    var body: some View {
        let theme = tm.resolved
        MacScreen("Mentor", subtitle: "Your AI mentor, grounded in your goals") {
            EmptyView()
        } content: {
            if !forwardSummary.isEmpty {
                forwardCard(theme)
            }

            MacCard("Write to your mentor") {
                TextEditor(text: $message)
                    .font(theme.body(14))
                    .frame(minHeight: 90)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(theme.hair, lineWidth: 1)
                    )
                if let errorText {
                    Text(errorText)
                        .font(theme.body(12))
                        .foregroundStyle(theme.danger)
                }
                HStack {
                    if !AIConfig.isConfigured {
                        Text("Set your API key in Settings to get replies.")
                            .font(theme.body(12))
                            .foregroundStyle(theme.muted)
                    }
                    Spacer()
                    if isSending { ProgressView().controlSize(.small) }
                    Button("Send") { send() }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSending || !AIConfig.isConfigured ||
                                  message.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            MacCard("Letters") {
                if letters.isEmpty {
                    Text("No mentor letters yet.")
                        .font(theme.body(14))
                        .foregroundStyle(theme.muted)
                } else {
                    ForEach(letters) { letter in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(letter.role.capitalized) · \(letter.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(letter.role == "mentor" ? theme.accent : theme.muted)
                            Text(letter.content)
                                .font(theme.body(14))
                                .foregroundStyle(theme.ink)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if letter.id != letters.last?.id {
                            Divider().overlay(theme.hair)
                        }
                    }
                }
            }
        }
    }

    /// A structured forward card: TODAY → THIS WEEK → PROGRESS. Rendered above
    /// the letter thread so the user always sees where today fits.
    @ViewBuilder
    private func forwardCard(_ theme: ResolvedTheme) -> some View {
        let lines = forwardSummary
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        MacCard("Where You Stand") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    let isHeader = line == line.uppercased() && line.hasSuffix(":")
                        || line.hasPrefix("TODAY") || line.hasPrefix("THIS WEEK")
                        || line.hasPrefix("PROGRESS") || line.hasPrefix("USER'S")
                    if isHeader {
                        Text(line)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(theme.accent)
                            .padding(.top, 2)
                    } else {
                        Text(line)
                            .font(theme.body(13))
                            .foregroundStyle(theme.ink)
                    }
                }
            }
        }
    }

    private func send() {
        let text = message.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        errorText = nil
        isSending = true

        // Persist the user's note immediately.
        let userLetter = MentorFeedback(role: "user", content: text, trigger: "mac_chat")
        context.insert(userLetter)
        try? context.save()
        message = ""

        let snapshot = snapshots.first
        let activeGoals = goals
        let actions = todaysActions
        Task {
            defer { isSending = false }
            do {
                let reply = try await AIService.generateMentorReply(
                    userMessage: text,
                    goals: activeGoals,
                    snapshot: snapshot,
                    todaysActions: actions
                )
                let mentorLetter = MentorFeedback(role: "mentor", content: reply, trigger: "mac_chat")
                context.insert(mentorLetter)
                try? context.save()
            } catch {
                errorText = "Couldn't reach the mentor: \(error.localizedDescription)"
            }
        }
    }
}
