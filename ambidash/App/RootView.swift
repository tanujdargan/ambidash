import SwiftUI

struct RootView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("theme_setup_complete") private var themeSetupComplete = false

    var body: some View {
        if !themeSetupComplete {
            ThemeSetupView()
        } else if onboardingComplete {
            MainTabView()
        } else {
            WelcomeView()
        }
    }
}
