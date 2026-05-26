// ambidash/Views/Goals/DomainAssessmentSheet.swift
import SwiftUI
import SwiftData

struct DomainAssessmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let goal: Goal
    let questions: [AssessmentQuestion]

    @State private var currentIndex = 0
    @State private var answers: [String: Set<String>] = [:]

    private var canAdvance: Bool {
        guard currentIndex < questions.count else { return false }
        let selected = answers[questions[currentIndex].id] ?? []
        return !selected.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if currentIndex < questions.count {
                    ProgressView(value: Double(currentIndex) / Double(questions.count))
                        .padding(.horizontal)
                        .padding(.top, 8)

                    ScrollView {
                        AssessmentQuestionView(
                            question: questions[currentIndex],
                            selectedIds: Binding(
                                get: { answers[questions[currentIndex].id] ?? [] },
                                set: { answers[questions[currentIndex].id] = $0 }
                            )
                        )
                        .id(currentIndex)
                        .padding(.top, 24)
                    }

                    HStack {
                        if currentIndex > 0 {
                            Button("Back") {
                                withAnimation { currentIndex -= 1 }
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        Button(currentIndex == questions.count - 1 ? "Done" : "Next") {
                            if currentIndex < questions.count - 1 {
                                withAnimation { currentIndex += 1 }
                            } else {
                                saveAndDismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAdvance)
                    }
                    .padding()
                }
            }
            .navigationTitle("\(goal.domain.displayName) Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
            }
        }
    }

    private func saveAndDismiss() {
        let assessment = DomainAssessment(domain: goal.domain)
        for (key, values) in answers {
            assessment.answers[key] = values.first ?? ""
        }
        goal.domainAssessment = assessment
        try? modelContext.save()
        dismiss()
    }
}
