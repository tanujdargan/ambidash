import SwiftUI
import SwiftData

struct OnboardingCompleteView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }
    private var goalCount: Int { profile?.goals.count ?? 0 }

    var body: some View {
        ZStack {
            AmbidashTheme.bgBase.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(AmbidashTheme.statusGood)

                    Text("You're all set")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(AmbidashTheme.textPrimary)

                    Text("Profile built with \(goalCount) goals. Your dashboard is ready.")
                        .font(.subheadline)
                        .foregroundStyle(AmbidashTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                AccentButton("Open Dashboard", icon: "arrow.right") {
                    profile?.onboardingComplete = true
                    try? modelContext.save()
                    onboardingComplete = true
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .navigationBarBackButtonHidden()
    }
}
