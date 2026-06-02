import SwiftUI
import SwiftData

struct MorningBriefView: View {
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    private var profile: UserProfile? { profiles.first }
    private var snapshot: IntegrationSnapshot? { snapshots.first }

    @State private var selectedAnswer: String?

    /// #8 — the chosen "which are you postponing today?" answer, persisted so
    /// TodayView's plan generator can fold it in as explicit intent (deprioritize
    /// the postponed goal). Stores a goal title, "neither", or "" when unanswered.
    @AppStorage("morningBrief.postponingIntent") private var postponingIntent: String = ""

    /// Optional dismiss handler so the host can close the brief and route to Today.
    var onOpenToday: (() -> Void)? = nil

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Time stamp
                Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased() + " · " + Date.now.formatted(.dateTime.hour().minute()))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(t.muted)
                    .padding(.horizontal, 22)
                    .padding(.top, 12)

                // Greeting
                Text("Good morning.\nOne question first.")
                    .font(t.heading(32))
                    .tracking(-0.3)
                    .lineSpacing(2)
                    .foregroundStyle(t.ink)
                    .padding(.horizontal, 22)
                    .padding(.top, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Mentor question card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Of the things you said mattered most this week — which one are you postponing today?")
                                .font(t.heading(19))
                                .italic()
                                .lineSpacing(4)
                                .foregroundStyle(t.ink)

                            if let goals = profile?.goals?.filter(\.isActive).prefix(3) {
                                VStack(spacing: 6) {
                                    ForEach(Array(goals), id: \.id) { goal in
                                        let isSelected = selectedAnswer == goal.title
                                        Button {
                                            selectedAnswer = goal.title
                                            postponingIntent = goal.title
                                        } label: {
                                            Text(goal.title)
                                                .font(.system(size: 14))
                                                .foregroundStyle(isSelected ? t.bg : t.ink)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(isSelected ? t.ink : .clear)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(isSelected ? .clear : t.hair, lineWidth: 0.5)
                                                )
                                        }
                                    }

                                    Button {
                                        selectedAnswer = "neither"
                                        postponingIntent = "neither"
                                    } label: {
                                        Text("Neither — explain why")
                                            .font(.system(size: 14))
                                            .foregroundStyle(t.ink2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(t.hair, lineWidth: 0.5)
                                            )
                                    }
                                }
                            }
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

                        // Overnight data
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: "Last night, gently")

                            if let snap = snapshot {
                                DataRowView(label: "Sleep", value: String(format: "%.0fh %02dm", snap.sleepHours.rounded(.down), Int((snap.sleepHours - snap.sleepHours.rounded(.down)) * 60)))
                                DataRowView(label: "Steps yesterday", value: "\(snap.steps)")
                            } else {
                                DataRowView(label: "Sleep", value: "—")
                                DataRowView(label: "Resting HR", value: "—")
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 22)
                }

                // Bottom
                HStack {
                    Spacer()
                    PillButton(label: "Open today", primary: true) {
                        // #8 — commit the postpone intent (in case nothing was
                        // tapped this session, leave any prior value intact) and
                        // hand control back to the host to route into Today.
                        if let answer = selectedAnswer {
                            postponingIntent = answer
                        }
                        Haptics.light()
                        onOpenToday?()
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
        }
    }
}
