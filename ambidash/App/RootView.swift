import SwiftUI

struct RootView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("theme_setup_complete") private var themeSetupComplete = false
    @State private var showLaunch = true

    var body: some View {
        ZStack {
            if !themeSetupComplete {
                ThemeSetupView()
            } else if onboardingComplete {
                MainTabView()
            } else {
                WelcomeView()
            }

            if showLaunch && themeSetupComplete {
                LaunchScreen()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            if themeSetupComplete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showLaunch = false
                    }
                }
            }
        }
    }
}
