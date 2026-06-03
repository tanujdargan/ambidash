// ambidash/Views/Settings/AppLimitsView.swift
import SwiftUI
#if os(iOS)
import FamilyControls
#endif

/// "App limits" — pick distracting apps and block them with Screen Time.
///
/// This screen is real, but the blocking itself only runs on a physical iPhone
/// (Family Controls is device-only). On the Simulator the picker and shield are
/// inert, so we show an honest note instead of pretending it works.
struct AppLimitsView: View {
    @Environment(ThemeManager.self) private var tm
    @State private var controller = AppLimitController.shared
    @State private var showPicker = false

    var body: some View {
        let t = tm.resolved
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(t)
                t.hair.frame(height: 0.5)
                content(t)
            }
            .padding(22)
        }
        .background(t.bg)
        .navigationTitle("App Limits")
        .accessibilityIdentifier("applimits.screen")
        #if os(iOS)
        .familyActivityPicker(isPresented: $showPicker, selection: $controller.selection)
        #endif
    }

    // MARK: - Header

    @ViewBuilder
    private func header(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 28))
                .foregroundStyle(t.accent)
            Text("Block the apps that pull you away")
                .font(t.heading(20))
                .foregroundStyle(t.ink)
            Text("Pick the apps you lose time to, then turn on a shield. When it's on, opening them shows a block screen instead.")
                .font(t.body(14))
                .foregroundStyle(t.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Content (state machine)

    @ViewBuilder
    private func content(_ t: ResolvedTheme) -> some View {
        switch controller.authState {
        case .unavailable:
            unavailableNote(t)
        case .denied:
            deniedNote(t)
        case .notDetermined:
            authorizeCTA(t)
        case .approved:
            approvedControls(t)
        }
    }

    @ViewBuilder
    private func authorizeCTA(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("First, let Ambidash manage Screen Time. iOS will ask you to allow it.")
                .font(t.body(14))
                .foregroundStyle(t.muted)
            Button {
                Haptics.light()
                Task { await controller.requestAuthorization() }
            } label: {
                Text("Turn on app blocking")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(t.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(t.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("applimits.authorize")
        }
    }

    @ViewBuilder
    private func approvedControls(_ t: ResolvedTheme) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pick apps
            Button {
                Haptics.light()
                showPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "apps.iphone")
                        .foregroundStyle(t.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Choose apps to block")
                            .font(t.body(15))
                            .foregroundStyle(t.ink)
                        Text(controller.blockedCount == 0
                             ? "None picked yet"
                             : "\(controller.blockedCount) picked")
                            .font(.caption)
                            .foregroundStyle(t.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(t.faint)
                }
                .padding(14)
                .background(t.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("applimits.pickApps")

            // Block on/off
            if controller.blockedCount > 0 {
                Button {
                    Haptics.success()
                    if controller.isShielding {
                        controller.stopBlocking()
                    } else {
                        controller.startBlocking()
                    }
                } label: {
                    Text(controller.isShielding ? "Stop blocking" : "Start blocking")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(controller.isShielding ? t.danger : t.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(controller.isShielding ? t.danger.opacity(0.12) : t.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("applimits.toggleBlock")
            }

            if controller.isShielding {
                HStack(spacing: 8) {
                    Image(systemName: "shield.fill").foregroundStyle(t.ok)
                    Text("Shield is on — picked apps are blocked.")
                        .font(t.body(13))
                        .foregroundStyle(t.ink)
                }
                .accessibilityIdentifier("applimits.shieldOn")
            }
        }
    }

    @ViewBuilder
    private func deniedNote(_ t: ResolvedTheme) -> some View {
        noteCard(t, icon: "xmark.shield", tint: t.danger,
                 text: "Screen Time access is off. Turn it on in iOS Settings → Screen Time to block apps here.")
            .accessibilityIdentifier("applimits.denied")
    }

    @ViewBuilder
    private func unavailableNote(_ t: ResolvedTheme) -> some View {
        noteCard(t, icon: "iphone", tint: t.muted,
                 text: "App blocking only runs on your iPhone — the Simulator and Mac can't shield apps. Try this on your phone.")
            .accessibilityIdentifier("applimits.unavailable")
    }

    @ViewBuilder
    private func noteCard(_ t: ResolvedTheme, icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text)
                .font(t.body(14))
                .foregroundStyle(t.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
