import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @Environment(ThemeManager.self) private var tm
    @State private var supabase = SupabaseService.shared

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Brand
                ZStack {
                    Circle().stroke(t.ink.opacity(0.12), lineWidth: 0.6).frame(width: 52, height: 52)
                    Circle().stroke(t.ink.opacity(0.12), lineWidth: 0.6).frame(width: 36, height: 36)
                    Circle().stroke(t.ink.opacity(0.12), lineWidth: 0.6).frame(width: 20, height: 20)
                    Circle().fill(t.accent).frame(width: 5, height: 5)
                }
                .padding(.bottom, 28)
                .fadeSlideIn(delay: 0.1)

                Text("AMBIDASH")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(t.muted)
                    .fadeSlideIn(delay: 0.2)

                Text("A quiet instrument for an ambitious life.")
                    .font(.system(size: 32, weight: .regular, design: .serif))
                    .tracking(-0.6)
                    .lineSpacing(2)
                    .foregroundStyle(t.ink)
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .fadeSlideIn(delay: 0.3)

                Spacer()
                Spacer()

                // Sign in with Apple
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(tm.isDark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 28)
                .fadeSlideIn(delay: 0.4)

                Text("Your data stays on your device.\nSign in syncs across devices.")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(t.faint)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                    .fadeSlideIn(delay: 0.5)
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    let success = await supabase.signInWithApple(credential: credential)
                    if !success {
                        ErrorLogger.warning("Apple sign-in failed")
                    }
                }
            }
        case .failure(let error):
            ErrorLogger.log(error, context: "Apple Sign In")
        }
    }
}
