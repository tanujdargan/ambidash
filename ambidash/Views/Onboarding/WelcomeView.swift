import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @State private var name = ""
    @State private var age = ""
    @State private var showAssessment = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(age) != nil && Int(age)! >= 13
    }

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 12) {
                        Text("ambidash")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(t.ink)
                        Text("Your life, one dashboard.")
                            .font(.title3)
                            .foregroundStyle(t.muted)
                    }

                    VStack(spacing: 16) {
                        TextField("What's your name?", text: $name)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(t.ink)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            .background(t.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 32)

                        TextField("Age", text: $age)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .foregroundStyle(t.ink)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            .background(t.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 32)

                        Text("~5 minutes to set up")
                            .font(.caption)
                            .foregroundStyle(t.faint)
                    }

                    Spacer()

                    AccentButton(label: "Let's go") {
                        let profile = UserProfile(
                            name: name.trimmingCharacters(in: .whitespaces),
                            age: Int(age) ?? 0
                        )
                        modelContext.insert(profile)
                        showAssessment = true
                    }
                    .disabled(!isValid)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)
                }
            }
            .navigationDestination(isPresented: $showAssessment) {
                AssessmentFlowView()
            }
        }
    }
}
