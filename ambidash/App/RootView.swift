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
                    .task {
                        // Self-dismiss whenever the splash actually appears (the
                        // old onAppear timer was gated on themeSetupComplete at
                        // launch, so it never fired for a fresh user → stuck splash).
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        withAnimation(.easeOut(duration: 0.4)) { showLaunch = false }
                    }
            }
        }
        .onAppear {
            supabase.restoreSession()
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
