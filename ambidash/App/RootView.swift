import SwiftUI

struct RootView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        if onboardingComplete {
            MainTabView()
        } else {
            WelcomeView()
        }
    }
}
