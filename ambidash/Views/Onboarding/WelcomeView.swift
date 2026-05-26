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
            ZStack {
                AmbidashTheme.bgDeep.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 12) {
                        Text("ambidash")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(AmbidashTheme.textPrimary)
                        Text("Your life, one dashboard.")
                            .font(.title3)
                            .foregroundStyle(AmbidashTheme.textSecondary)
                    }

                    VStack(spacing: 16) {
                        TextField("What's your name?", text: $name)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AmbidashTheme.textPrimary)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            .background(AmbidashTheme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium))
                            .padding(.horizontal, 32)

                        TextField("Age", text: $age)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .foregroundStyle(AmbidashTheme.textPrimary)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                            .background(AmbidashTheme.bgElevated)
                            .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium))
                            .padding(.horizontal, 32)

                        Text("~5 minutes to set up")
                            .font(.caption)
                            .foregroundStyle(AmbidashTheme.textTertiary)
                    }

                    Spacer()

                    AccentButton("Let's go", icon: "arrow.right") {
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
