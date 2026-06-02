import SwiftUI
import SwiftData

struct AssessmentFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]

    @State private var currentIndex = 0
    @State private var answers: [String: Set<String>] = [:]
    @State private var showGoalDeclaration = false

    private let questions = CoreAssessmentQuestions.all

    private var profile: UserProfile? { profiles.first }

    private var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }

    private var canAdvance: Bool {
        guard currentIndex < questions.count else { return false }
        let q = questions[currentIndex]
        let selected = answers[q.id] ?? []
        if q.multiSelect {
            return selected.count >= 1
        }
        return !selected.isEmpty
    }

    var body: some View {
        let t = tm.resolved
        VStack(spacing: 0) {
            // Step indicator
            VStack(alignment: .leading, spacing: 6) {
                Text("STEP 03 / 06 · ATTENTION")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(t.muted)

                // Segmented progress bar
                HStack(spacing: 3) {
                    ForEach(0..<questions.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(i <= currentIndex ? t.ink : t.hair)
                            .frame(height: 2)
                    }
                }

                Text("Q \(currentIndex + 1) OF \(questions.count)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(t.faint)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)

            ScrollView {
                if currentIndex < questions.count {
                    VStack(alignment: .leading, spacing: 18) {
                        AssessmentQuestionView(
                            question: questions[currentIndex],
                            selectedIds: binding(for: questions[currentIndex].id)
                        )

                        // Mentor aside (appears on certain questions)
                        if currentIndex == 0 || currentIndex == questions.count / 2 {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ASIDE")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .tracking(1.6)
                                    .foregroundStyle(t.muted)
                                Text("There are no right answers. Honest ones become a better mirror.")
                                    .font(.system(size: 14, design: .serif))
                                    .italic()
                                    .lineSpacing(2)
                                    .foregroundStyle(t.ink2)
                            }
                            .padding(14)
                            .background(.clear)
                            .overlay(alignment: .leading) {
                                t.accent.frame(width: 2)
                                    .clipShape(RoundedRectangle(cornerRadius: 1))
                            }
                            .padding(.horizontal, 22)
                        }
                    }
                    .id(currentIndex)
                    .padding(.top, 24)
                }
            }

            HStack(spacing: 10) {
                if currentIndex > 0 {
                    PillButton(label: "Back") {
                        withAnimation { currentIndex -= 1 }
                    }
                }
                Spacer()
                PillButton(label: "Skip") {
                    if currentIndex < questions.count - 1 {
                        withAnimation { currentIndex += 1 }
                    } else {
                        // On the LAST question Skip must finalize the flow the same
                        // way Next does — otherwise it's a dead button and Next is
                        // disabled when unanswered, stranding the user. saveAssessment
                        // tolerates missing answers via its defaults.
                        saveAssessment()
                        showGoalDeclaration = true
                    }
                }
                PillButton(label: currentIndex == questions.count - 1 ? "Next" : "Continue", primary: true) {
                    if currentIndex < questions.count - 1 {
                        withAnimation { currentIndex += 1 }
                    } else {
                        saveAssessment()
                        showGoalDeclaration = true
                    }
                }
                .disabled(!canAdvance)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .background(t.bg)
        .navigationTitle("About You")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showGoalDeclaration) {
            GoalDeclarationView()
        }
    }

    private func binding(for questionId: String) -> Binding<Set<String>> {
        Binding(
            get: { answers[questionId] ?? [] },
            set: { answers[questionId] = $0 }
        )
    }

    private func saveAssessment() {
        guard let profile else { return }
        let assessment = CoreAssessment()
        assessment.cognitiveStyle = answers["focus_style"]?.first ?? ""
        assessment.peakEnergyTime = answers["peak_energy"]?.first ?? ""
        assessment.overwhelmResponse = answers["overwhelm_response"]?.first ?? ""

        let adhdFocus = adhdScore(answers["adhd_focus"]?.first)
        let adhdRestless = adhdScore(answers["adhd_restless"]?.first)
        assessment.adhdScore = adhdFocus + adhdRestless

        assessment.anxietyScore = anxietyScore(answers["anxiety_level"]?.first)
        assessment.sleepQualitySelfRating = sleepScore(answers["sleep_quality"]?.first)
        assessment.topValues = Array(answers["top_values"] ?? [])
        assessment.biggestBlocker = answers["biggest_blocker"]?.first ?? ""
        assessment.accountabilityPreference = answers["accountability"]?.first ?? ""

        profile.coreAssessment = assessment
    }

    private func adhdScore(_ value: String?) -> Int {
        switch value {
        case "never": 0
        case "rarely": 1
        case "sometimes": 2
        case "often": 3
        case "very_often": 4
        default: 0
        }
    }

    private func anxietyScore(_ value: String?) -> Int {
        switch value {
        case "not_at_all": 0
        case "several_days": 1
        case "more_than_half": 2
        case "nearly_every_day": 3
        default: 0
        }
    }

    private func sleepScore(_ value: String?) -> Int {
        switch value {
        case "great": 4
        case "ok": 3
        case "poor": 2
        case "terrible": 1
        default: 0
        }
    }
}
