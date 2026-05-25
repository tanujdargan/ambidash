import SwiftUI
import SwiftData

struct RootView: View {
    @Query private var profiles: [UserProfile]

    private var hasCompletedOnboarding: Bool {
        profiles.first?.onboardingComplete ?? false
    }

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            WelcomeView()
        }
    }
}
