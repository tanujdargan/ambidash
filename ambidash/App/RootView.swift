import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
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

            if showLaunch && themeSetupComplete && !UITestSupport.isActive {
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
            // TEST-ONLY: seed a deterministic profile + sample goal so the seeded
            // MainTabView branch has data. Gated inside seedIfNeeded; inert normally.
            UITestSupport.seedIfNeeded(modelContext)
            // v4: record today's actual wake time on first open (idempotent per day).
            WakeTracker.recordIfNeeded(modelContext)
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
