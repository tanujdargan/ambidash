import SwiftUI
import SwiftData

/// v4 mentor invite (scaffold). Generate a shareable code + QR to send to a mentor
/// or mentee, and paste someone else's code to connect. The link is stored LOCALLY
/// per device — real cross-device sync needs a backend/domain (future); for now the
/// generate → share → paste-to-connect flow works end-to-end on-device.
struct MentorInviteSheet: View {
    @Environment(ThemeManager.self) private var tm
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var profile: UserProfile

    @State private var enteredCode = ""

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    yourCodeSection(t)
                    t.hair.frame(height: 0.5)
                    connectSection(t)
                }
                .padding(22)
            }
            .background(t.bg)
            .navigationTitle("Invite & Connect")
            .navigationBarTitleDisplayModeInlineIfAvailable()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: ensureCode)
        .accessibilityIdentifier("mentor.inviteSheet")
    }

    // MARK: - Your code

    @ViewBuilder
    private func yourCodeSection(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Your invite code")
            Text("Send this to a mentor or mentee — they enter it to connect with you.")
                .font(t.body(13))
                .foregroundStyle(t.muted)

            Text(profile.mentorInviteCode)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(t.ink)
                .textSelection(.enabled)
                .accessibilityIdentifier("mentor.inviteCode")

            if let qr = QRCode.image(from: profile.mentorInviteCode) {
                qr.resizable()
                    .frame(width: 150, height: 150)
                    .padding(12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            ShareLink(item: "Connect with me on Ambidash — my code is \(profile.mentorInviteCode)") {
                Label("Share code", systemImage: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(t.accent)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(t.accentSoft)
                    .clipShape(Capsule())
            }
            .accessibilityIdentifier("mentor.shareCode")
        }
    }

    // MARK: - Connect

    @ViewBuilder
    private func connectSection(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: "Have someone's code?")

            if profile.connectedPeerCode.isEmpty {
                HStack(spacing: 10) {
                    TextField("Paste their code", text: $enteredCode)
                        .font(.system(size: 15, design: .monospaced))
                        .textFieldStyle(.plain)
                        .submitLabel(.go)
                        .onSubmit { connect() }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(t.sunken)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("mentor.connectField")
                    Button("Connect") { connect() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(enteredCode.isEmpty ? t.faint : t.bg)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(enteredCode.isEmpty ? t.sunken : t.accent)
                        .clipShape(Capsule())
                        .disabled(enteredCode.isEmpty)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(t.ok)
                    Text("Connected to \(profile.connectedPeerCode)")
                        .font(t.body(14)).foregroundStyle(t.ink)
                    Spacer()
                    Button("Disconnect") {
                        profile.connectedPeerCode = ""
                        try? modelContext.save()
                    }
                    .font(.system(size: 12)).foregroundStyle(t.muted)
                }
                .padding(.vertical, 4)
                .accessibilityIdentifier("mentor.connectedState")
            }
        }
    }

    private func ensureCode() {
        guard profile.mentorInviteCode.isEmpty else { return }
        profile.mentorInviteCode = "AMBI-" + UUID().uuidString.prefix(6).uppercased()
        try? modelContext.save()
    }

    private func connect() {
        let code = enteredCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        Haptics.success()
        profile.connectedPeerCode = code
        try? modelContext.save()
    }
}

private extension View {
    /// Inline nav title on iOS; no-op on macOS (which lacks the modifier).
    @ViewBuilder func navigationBarTitleDisplayModeInlineIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
