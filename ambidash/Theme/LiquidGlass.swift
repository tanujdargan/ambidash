import SwiftUI

// Liquid Glass design layer — frosted-glass surfaces + soft gradient backdrops, built on
// iOS 26's native `.glassEffect()` (with a `.ultraThinMaterial` fallback) and driven entirely
// by the existing ThemeManager palette, so every glass surface + gradient stays correct in
// BOTH light and dark mode and text keeps using the theme's adaptive ink/muted colors.

// MARK: - Theme-derived glass tokens (computed — no changes to ResolvedTheme's initializer)

extension ResolvedTheme {
    /// A soft, palette-driven gradient backdrop: the base bg washed with a hint of accent.
    /// Subtle enough that `ink`/`muted` text stays legible over it in both modes.
    var bgGradient: LinearGradient {
        LinearGradient(
            colors: isDark
                ? [bg, accent.opacity(0.26), surface, accent.opacity(0.14), bg]
                : [bg, accent.opacity(0.16), bg, accent.opacity(0.10), bg],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Tint used inside tinted glass for prominence.
    var glassTint: Color { accent.opacity(isDark ? 0.18 : 0.12) }

    /// The bright top-edge highlight that sells the "glass" — white in dark mode, a soft
    /// luminous white in light mode.
    var glassStroke: Color { Color.white.opacity(isDark ? 0.12 : 0.55) }

    /// A faint fill placed UNDER the glass so content stays readable over busy gradients.
    var glassUnderlay: Color { surface.opacity(isDark ? 0.30 : 0.5) }
}

// MARK: - Gradient + glass background

/// The app's gradient backdrop with soft, blurred accent "light blobs" for depth — the
/// liquid, gradient-rich canvas glass surfaces float on. Light/dark aware.
struct GlassBackground: View {
    @Environment(ThemeManager.self) private var tm

    var body: some View {
        let t = tm.resolved
        ZStack {
            t.bgGradient
            Circle()
                .fill(t.accent.opacity(t.isDark ? 0.34 : 0.20))
                .frame(width: 440)
                .blur(radius: 120)
                .offset(x: -150, y: -300)
            Circle()
                .fill(t.accent.opacity(t.isDark ? 0.22 : 0.13))
                .frame(width: 380)
                .blur(radius: 130)
                .offset(x: 180, y: 380)
            Circle()
                .fill(t.ok.opacity(t.isDark ? 0.12 : 0.08))
                .frame(width: 300)
                .blur(radius: 140)
                .offset(x: 140, y: -120)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass card / chip modifiers

extension View {
    /// Frosted Liquid-Glass card surface (rounded, continuous corners) with a top highlight.
    /// `tinted` adds an accent wash for prominent cards. Apply AFTER padding (glass reads the
    /// final frame).
    func glassCard(cornerRadius: CGFloat = 18, tinted: Bool = false) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius, tinted: tinted, interactive: false))
    }

    /// A glass chip/pill (capsule-ish small surface), e.g. for tags, counts, controls.
    func glassChip(cornerRadius: CGFloat = 22) -> some View {
        modifier(GlassSurfaceModifier(cornerRadius: cornerRadius, tinted: false, interactive: true))
    }
}

struct GlassSurfaceModifier: ViewModifier {
    @Environment(ThemeManager.self) private var tm
    let cornerRadius: CGFloat
    let tinted: Bool
    let interactive: Bool

    func body(content: Content) -> some View {
        let t = tm.resolved
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if #available(iOS 26, macOS 26, *) {
                content
                    .background(t.glassUnderlay, in: shape)
                    .glassEffect(glass(t), in: shape)
                    .overlay(shape.strokeBorder(t.glassStroke, lineWidth: 0.7))
            } else {
                content
                    .background(t.glassUnderlay, in: shape)
                    .background(.ultraThinMaterial, in: shape)
                    .overlay(shape.strokeBorder(t.glassStroke, lineWidth: 0.7))
            }
        }
    }

    @available(iOS 26, macOS 26, *)
    private func glass(_ t: ResolvedTheme) -> Glass {
        var g: Glass = tinted ? .regular.tint(t.glassTint) : .regular
        if interactive { g = g.interactive() }
        return g
    }
}

// MARK: - Glass button style (prominent CTA in the glass language)

struct GlassProminentButtonStyle: ButtonStyle {
    @Environment(ThemeManager.self) private var tm
    func makeBody(configuration: Configuration) -> some View {
        let t = tm.resolved
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(t.isDark ? t.ink : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
                if #available(iOS 26, macOS 26, *) {
                    shape.fill(t.accent.opacity(0.001))
                        .glassEffect(.regular.tint(t.accent.opacity(0.9)).interactive(), in: shape)
                } else {
                    shape.fill(t.accent)
                }
            }
            .overlay(shape.strokeBorder(t.glassStroke, lineWidth: 0.7))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassProminentButtonStyle {
    /// Prominent accent CTA rendered in Liquid Glass.
    static var glassCTA: GlassProminentButtonStyle { .init() }
}
