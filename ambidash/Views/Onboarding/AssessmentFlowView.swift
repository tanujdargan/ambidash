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
            ProgressView(value: progress)
                .tint(t.accent)
                .padding(.horizontal)
                .padding(.top, 8)

            Text("\(currentIndex + 1) of \(questions.count)")
                .font(.caption)
                .foregroundStyle(t.muted)
                .padding(.top, 4)

            ScrollView {
                if currentIndex < questions.count {
                    AssessmentQuestionView(
                        question: questions[currentIndex],
                        selectedIds: binding(for: questions[currentIndex].id)
                    )
                    .id(currentIndex)
                    .padding(.top, 24)
                }
            }

            HStack(spacing: 16) {
                if currentIndex > 0 {
                    GhostButton(label: "Back") {
                        withAnimation { currentIndex -= 1 }
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer()

                AccentButton(label: currentIndex == questions.count - 1 ? "Next" : "Continue") {
                    if currentIndex < questions.count - 1 {
                        withAnimation { currentIndex += 1 }
                    } else {
                        saveAssessment()
                        showGoalDeclaration = true
                    }
                }
                .disabled(!canAdvance)
                .frame(maxWidth: .infinity)
            }
            .padding()
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
