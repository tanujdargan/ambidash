import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var age = ""
    @State private var showAssessment = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(age) != nil && Int(age)! >= 13
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Text("ambidash")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                    Text("Your life, one dashboard.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    TextField("What's your name?", text: $name)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 48)

                    TextField("Age", text: $age)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding(.horizontal, 48)

                    Text("~5 minutes to set up")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Button {
                    let profile = UserProfile(
                        name: name.trimmingCharacters(in: .whitespaces),
                        age: Int(age) ?? 0
                    )
                    modelContext.insert(profile)
                    showAssessment = true
                } label: {
                    Text("Let's go")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
            .navigationDestination(isPresented: $showAssessment) {
                AssessmentFlowView()
            }
        }
    }
}
