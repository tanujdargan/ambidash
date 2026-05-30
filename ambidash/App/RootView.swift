import SwiftUI

struct RootView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("theme_setup_complete") private var themeSetupComplete = false
    @State private var showLaunch = true
    @State private var supabase = SupabaseService.shared
    @Binding var deepLinkTab: Int?

    var body: some View {
        ZStack {
            if !themeSetupComplete {
                ThemeSetupView()
            } else if onboardingComplete {
                MainTabView(selectedTab: deepLinkTab)
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
            supabase.restoreSession()
            if themeSetupComplete {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showLaunch = false
                    }
                }
            }
        }
        .onChange(of: deepLinkTab) { _, newTab in
            if newTab != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    deepLinkTab = nil
                }
            }
        }
    }
}
