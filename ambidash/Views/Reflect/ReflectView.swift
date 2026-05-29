import SwiftUI
import SwiftData

struct ReflectView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyPlan.date, order: .reverse) private var plans: [DailyPlan]
    @Query(sort: \Reflection.date, order: .reverse) private var reflections: [Reflection]
    @Query(sort: \IntegrationSnapshot.date, order: .reverse) private var snapshots: [IntegrationSnapshot]

    @State private var selectedTab = 0
    @State private var q1Text = ""
    @State private var q2Text = ""
    @State private var q3Text = ""

    private var todayPlan: DailyPlan? {
        plans.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }
    }

    private var todayReflection: Reflection? {
        reflections.first { Calendar.current.isDate($0.date, inSameDayAs: .now) }
    }

    private var todaySnapshot: IntegrationSnapshot? {
        snapshots.first
    }

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
                                .font(.system(size: 28, weight: .regular, design: .serif))
                                .tracking(-0.3)
                                .lineSpacing(2)
                                .foregroundStyle(t.ink)
                                .padding(.horizontal, 22)
                                .padding(.top, 14)
                                .fadeSlideIn(delay: 0.1)

                            // Day summary (compact)
                            if let plan = todayPlan {
                                let doneCount = plan.actions.filter { $0.statusRaw == "done" }.count
                                let total = plan.actions.count
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
                            VStack(spacing: 22) {
                                ReflectionQuestion(number: 1,
                                    question: "What did you actually do today?",
                                    hint: "Not what was on the list. What you did.",
                                    text: $q1Text)
                                    .fadeSlideIn(delay: 0.2)
                                ReflectionQuestion(number: 2,
                                    question: "Where did the time you can't account for go?",
                                    hint: "Approximate is fine.",
                                    text: $q2Text)
                                    .fadeSlideIn(delay: 0.3)
                                ReflectionQuestion(number: 3,
                                    question: "What is one thing tomorrow's you will need from tonight's you?",
                                    hint: "",
                                    text: $q3Text)
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
                                PillButton(label: "Send to Mentor", primary: true) { saveReflection() }
                            }
                            .padding(.horizontal, 22)
                            .padding(.top, 18)
                            .fadeSlideIn(delay: 0.5)
                        }
                        .padding(.bottom, 24)
                    }
                    .background(t.bg)
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
}

private struct ReflectionQuestion: View {
    @Environment(ThemeManager.self) private var tm
    let number: Int
    let question: String
    let hint: String
    @Binding var text: String

    var body: some View {
        let t = tm.resolved
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(String(format: "%02d", number))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(text.isEmpty ? t.accent : t.faint)
                    .frame(width: 18)

                Text(question)
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .foregroundStyle(t.ink)
            }

            if !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
                    .padding(.leading, 28)
                    .padding(.top, 4)
            }

            TextField("tap to write…", text: $text, axis: .vertical)
                .font(.system(size: 14, design: .serif))
                .italic()
                .lineSpacing(3)
                .foregroundStyle(text.isEmpty ? t.faint : t.ink2)
                .padding(.leading, 28)
                .padding(.top, 10)
                .lineLimit(2...6)

            t.hair.frame(height: 0.5)
                .padding(.leading, 28)
                .padding(.top, 8)
        }
    }
}
