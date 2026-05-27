import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @AppStorage("theme_setup_complete") private var themeSetupComplete = false
    @State private var showIdentity = false

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    Spacer()

                    // Instrument mark
                    ZStack {
                        Circle().stroke(t.ink.opacity(0.15), lineWidth: 0.6).frame(width: 52, height: 52)
                        Circle().stroke(t.ink.opacity(0.15), lineWidth: 0.6).frame(width: 36, height: 36)
                        Circle().stroke(t.ink.opacity(0.15), lineWidth: 0.6).frame(width: 20, height: 20)
                        Circle().fill(t.accent).frame(width: 5, height: 5)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                    .fadeSlideIn(delay: 0.1)

                    Text("AMBIDASH · V0.1")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(t.muted)
                        .padding(.horizontal, 28)
                        .fadeSlideIn(delay: 0.2)

                    Text("A quiet instrument for an ambitious life.")
                        .font(.system(size: 38, weight: .regular, design: .serif))
                        .tracking(-0.6)
                        .lineSpacing(2)
                        .foregroundStyle(t.ink)
                        .padding(.horizontal, 28)
                        .padding(.top, 16)
                        .fadeSlideIn(delay: 0.3)

                    Text("Not a coach, not a tracker. A mentor who watches, asks better questions, and remembers what you said you cared about — when you forget.")
                        .font(.system(size: 15))
                        .lineSpacing(4)
                        .foregroundStyle(t.ink2)
                        .padding(.horizontal, 28)
                        .padding(.top, 18)
                        .fadeSlideIn(delay: 0.4)

                    Spacer()
                    Spacer()

                    VStack(spacing: 10) {
                        PrimaryButton(label: "Begin") {
                            showIdentity = true
                        }

                        GhostButton(label: "I've been here before") {
                            onboardingComplete = true
                        }

                        Text("~ 8 minutes to set up · everything stays on this device")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(t.faint)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 22)
                    .fadeSlideIn(delay: 0.5)
                }
            }
            .navigationDestination(isPresented: $showIdentity) {
                IdentityView()
            }
        }
        .preferredColorScheme(tm.isDark ? .dark : .light)
    }
}
