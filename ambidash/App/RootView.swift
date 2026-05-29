import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("theme_setup_complete") private var themeSetupComplete = false
    @State private var showLaunch = true
    @State private var supabase = SupabaseService.shared
    @Binding var deepLinkTab: Int?

    var body: some View {
        ZStack {
            if !supabase.isAuthenticated {
                AuthView()
            } else if !themeSetupComplete {
                ThemeSetupView()
            } else if onboardingComplete {
                MainTabView(selectedTab: deepLinkTab)
            } else {
                WelcomeView()
            }

            if showLaunch && themeSetupComplete && supabase.isAuthenticated {
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
        .onChange(of: supabase.isAuthenticated) { _, isAuth in
            // On sign-in, pull the user's data down from Supabase (CloudKit syncs separately).
            if isAuth {
                Task { await SyncService.fullSync(context: modelContext, profile: profiles.first) }
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
