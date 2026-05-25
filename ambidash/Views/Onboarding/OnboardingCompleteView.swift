import SwiftUI
import SwiftData

struct OnboardingCompleteView: View {
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }
    private var goalCount: Int { profile?.goals.count ?? 0 }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("You're all set")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Profile built with \(goalCount) goals. Your dashboard is ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                profile?.onboardingComplete = true
            } label: {
                Text("Open Dashboard")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .navigationBarBackButtonHidden()
    }
}
