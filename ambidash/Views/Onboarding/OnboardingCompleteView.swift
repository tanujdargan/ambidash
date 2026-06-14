import SwiftUI
import SwiftData

struct OnboardingCompleteView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var tm
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }
    private var goalCount: Int { profile?.goals?.count ?? 0 }

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(t.ok)

                    Text("You're all set")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(t.ink)

                    Text("Profile built with \(goalCount) goals. Your dashboard is ready.")
                        .font(.subheadline)
                        .foregroundStyle(t.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                AccentButton(label: "Open Dashboard") {
                    Haptics.success()
                    profile?.onboardingComplete = true
                    try? modelContext.save()
                    ActivationCounters.record(.onboardingCompleted)   // on-device funnel start
                    onboardingComplete = true
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .navigationBarBackButtonHidden()
    }
}
