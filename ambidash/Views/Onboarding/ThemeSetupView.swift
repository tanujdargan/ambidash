import SwiftUI

struct ThemeSetupView: View {
    @Environment(ThemeManager.self) private var tm
    @State private var showOnboarding = false

    var body: some View {
        let t = tm.resolved
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("AMBIDASH · V0.1")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .tracking(1.6)
                                .foregroundStyle(t.muted)

                            Text("Make it yours.")
                                .font(.system(size: 32, weight: .regular, design: .serif))
                                .tracking(-0.3)
                                .foregroundStyle(t.ink)
                        }
                        .padding(.top, 20)

                        // Palette
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "Palette")

                            HStack(spacing: 10) {
                                ForEach(ThemePalette.allCases) { palette in
                                    let (bg, ink, accent) = palette.colors
                                    let isSelected = tm.palette == palette

                                    Button {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            tm.palette = palette
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            HStack(spacing: 0) {
                                                Color(hex: bg).frame(width: 20, height: 28)
                                                Color(hex: ink).frame(width: 20, height: 28)
                                                Color(hex: accent).frame(width: 20, height: 28)
                                            }
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(isSelected ? t.ink : t.hair, lineWidth: isSelected ? 1.5 : 0.5)
                                            )

                                            Text(palette.displayName)
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(isSelected ? t.ink : t.muted)
                                        }
                                    }
                                }
                            }
                        }

                        // Mode
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "Mode")

                            HStack(spacing: 10) {
                                ModeButton(label: "Dark", isSelected: tm.isDark) {
                                    withAnimation(.easeOut(duration: 0.2)) { tm.isDark = true }
                                }
                                ModeButton(label: "Light", isSelected: !tm.isDark) {
                                    withAnimation(.easeOut(duration: 0.2)) { tm.isDark = false }
                                }
                            }
                        }

                        // Typography
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "Typography")

                            VStack(spacing: 8) {
                                ForEach(ThemeTypography.allCases) { typo in
                                    let isSelected = tm.typography == typo

                                    Button {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            tm.typography = typo
                                        }
                                    } label: {
                                        HStack {
                                            Text(typo.displayName)
                                                .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                                                .foregroundStyle(t.ink)

                                            Spacer()

                                            Text("Aa")
                                                .font(.system(size: 16, design: typo == .technical ? .monospaced : .serif))
                                                .foregroundStyle(t.muted)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(isSelected ? t.ink.opacity(0.08) : .clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(isSelected ? t.ink : t.hair, lineWidth: isSelected ? 1 : 0.5)
                                        )
                                    }
                                }
                            }
                        }

                        // Density
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(title: "Density")

                            HStack(spacing: 10) {
                                ForEach(ThemeDensity.allCases) { d in
                                    let isSelected = tm.density == d

                                    Button {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            tm.density = d
                                        }
                                    } label: {
                                        Text(d.displayName)
                                            .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                                            .foregroundStyle(isSelected ? t.bg : t.ink)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(isSelected ? t.ink : .clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(isSelected ? .clear : t.hair, lineWidth: 0.5)
                                            )
                                    }
                                }
                            }
                        }

                        // Preview
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(title: "Preview")

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Good morning.")
                                    .font(.system(size: 28, weight: .regular, design: .serif))
                                    .foregroundStyle(t.ink)

                                Text("42")
                                    .font(.system(size: 40, design: .monospaced))
                                    .monospacedDigit()
                                    .foregroundStyle(t.accent)
                                + Text(" /100")
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundStyle(t.faint)

                                Text("Body · Mind · Craft · Social · Capital")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .tracking(1)
                                    .foregroundStyle(t.muted)
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(t.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(t.hair, lineWidth: 0.5)
                            )
                        }

                        // Continue
                        PrimaryButton(label: "Continue") {
                            UserDefaults.standard.set(true, forKey: "theme_setup_complete")
                            showOnboarding = true
                        }
                        .padding(.top, 8)

                        Text("You can change all of this later in Settings.")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(t.faint)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 32)
                }
            }
            .navigationDestination(isPresented: $showOnboarding) {
                WelcomeView()
            }
        }
        .preferredColorScheme(tm.isDark ? .dark : .light)
    }
}

private struct ModeButton: View {
    @Environment(ThemeManager.self) private var tm
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let t = tm.resolved
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? t.bg : t.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? t.ink : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? .clear : t.hair, lineWidth: 0.5)
                )
        }
    }
}
