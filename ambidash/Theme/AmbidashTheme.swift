import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - Palette Definitions

enum ThemePalette: String, CaseIterable, Codable, Identifiable {
    case yellow, cool, forest, rose

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .yellow: "Yellow"
        case .cool: "Cool"
        case .forest: "Forest"
        case .rose: "Rose"
        }
    }

    var colors: (bg: UInt, ink: UInt, accent: UInt) {
        switch self {
        case .yellow: (0xF1EDE3, 0x1A1712, 0xB47A3A)
        case .cool:   (0xECEEEF, 0x11161B, 0x5C7F8B)
        case .forest: (0xEDEEE5, 0x13180F, 0x6B7A4A)
        case .rose:   (0xF2EBE7, 0x1C1614, 0xA55E5B)
        }
    }
}

enum ThemeTypography: String, CaseIterable, Codable, Identifiable {
    case editorial, modern, technical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .editorial: "Editorial"
        case .modern: "Modern"
        case .technical: "Technical"
        }
    }

    var serifDesign: Font.Design { .serif }
    var sansDesign: Font.Design { .default }
    var monoDesign: Font.Design { .monospaced }

    /// Design used for display/heading text. Editorial keeps a literary serif;
    /// modern switches to a clean sans; technical uses monospaced for a precise,
    /// instrument-panel feel. This is the most visible lever when toggling.
    var headingDesign: Font.Design {
        switch self {
        case .editorial: .serif
        case .modern: .default
        case .technical: .monospaced
        }
    }

    /// Design used for running body prose, mirroring the heading family so the
    /// whole screen shifts coherently.
    var bodyDesign: Font.Design {
        switch self {
        case .editorial: .serif
        case .modern: .default
        case .technical: .monospaced
        }
    }

    /// Per-option size nudge applied to heading text so the three options read
    /// at visibly different scales (editorial largest, technical tightest).
    var headingSizeDelta: CGFloat {
        switch self {
        case .editorial: 0
        case .modern: -1
        case .technical: -3
        }
    }

    var serifWeight: Font.Weight {
        switch self {
        case .editorial: .regular
        case .modern: .regular
        case .technical: .medium
        }
    }

    var headingWeight: Font.Weight {
        switch self {
        case .editorial: .regular
        case .modern: .medium
        case .technical: .semibold
        }
    }

    var bodySize: CGFloat {
        switch self {
        case .editorial: 15
        case .modern: 14
        case .technical: 13
        }
    }

    var monoSize: CGFloat {
        switch self {
        case .editorial: 11
        case .modern: 11
        case .technical: 10
        }
    }
}

enum ThemeDensity: String, CaseIterable, Codable, Identifiable {
    case calm, detailed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calm: "Calm"
        case .detailed: "Detailed"
        }
    }
}

// MARK: - Density Spacing Scale

/// A small set of spacing tokens derived from `ThemeDensity`. Views read these
/// (via `tm.resolved.space`) instead of hardcoding VStack/section spacing, so
/// toggling Calm <-> Detailed visibly re-flows the most-used screens.
struct DensitySpacing {
    /// Gap between major sections in a scroll (e.g. the Dashboard VStack).
    let section: CGFloat
    /// Gap between grouped items inside a section.
    let component: CGFloat
    /// Tight inner gap (label -> value, header -> subtitle).
    let tight: CGFloat

    static func forDensity(_ density: ThemeDensity) -> DensitySpacing {
        switch density {
        case .calm:
            return DensitySpacing(section: 28, component: 20, tight: 8)
        case .detailed:
            return DensitySpacing(section: 16, component: 12, tight: 5)
        }
    }
}

// MARK: - Resolved Theme

struct ResolvedTheme {
    let bg: Color
    let surface: Color
    let sunken: Color
    let ink: Color
    let ink2: Color
    let muted: Color
    let faint: Color
    let hair: Color
    let rule: Color
    let accent: Color
    let accentSoft: Color
    let danger: Color
    let ok: Color
    /// Non-punitive state token (design principle #1). The single shared treatment
    /// for PAST / MISSED / DEFERRED / behind-pace items: a soft, muted taupe-grey
    /// that reads as "faded / rolled forward", never as failure. Use this anywhere
    /// a surface would otherwise reach for `danger` to mark a user *miss* (skipped,
    /// slipping, behind pace, at-risk). `danger` stays reserved for genuine errors
    /// and truly destructive actions only.
    let deferred: Color
    let isDark: Bool
    /// Density-derived spacing scale (calm = roomier, detailed = tighter).
    let space: DensitySpacing
    /// The active typography option, so views can pull font design/weight/size.
    let typography: ThemeTypography

    /// Heading font (serif-family display text) sized + weighted per typography.
    /// `size` is the editorial baseline; modern/technical scale it down slightly.
    /// The base point size is run through Dynamic Type metrics so headings respond
    /// to the user's text-size setting (no-op on platforms without UIFontMetrics).
    func heading(_ size: CGFloat) -> Font {
        let base = size + typography.headingSizeDelta
        return .system(size: Self.scaledSize(base, relativeTo: .title2), weight: typography.headingWeight, design: typography.headingDesign)
    }

    /// Body font (running prose) using the typography's body design + size scale.
    /// Pass the editorial baseline `size`; modern/technical shift it via bodySize.
    /// The base point size is run through Dynamic Type metrics so body text responds
    /// to the user's text-size setting (no-op on platforms without UIFontMetrics).
    func body(_ baseline: CGFloat = 15) -> Font {
        let base = baseline + (typography.bodySize - 15)
        return .system(size: Self.scaledSize(base, relativeTo: .body), weight: .regular, design: typography.bodyDesign)
    }

    /// Scales a fixed point size by the current Dynamic Type setting so fonts built
    /// from a raw `size:` still honor the user's accessibility text-size preference.
    /// On platforms without `UIFontMetrics` this returns the base size unchanged.
    private static func scaledSize(_ base: CGFloat, relativeTo textStyle: Font.TextStyle) -> CGFloat {
        #if os(iOS)
        let uiStyle: UIFont.TextStyle
        switch textStyle {
        case .title2: uiStyle = .title2
        default: uiStyle = .body
        }
        return UIFontMetrics(forTextStyle: uiStyle).scaledValue(for: base)
        #else
        return base
        #endif
    }
}

// MARK: - Theme Environment

@Observable
final class ThemeManager {
    var palette: ThemePalette {
        didSet { UserDefaults.standard.set(palette.rawValue, forKey: "theme_palette") }
    }
    var isDark: Bool {
        didSet { UserDefaults.standard.set(isDark, forKey: "theme_dark") }
    }
    /// Pure-black ("OLED") variant of dark mode. Only affects rendering when isDark.
    var oled: Bool {
        didSet { UserDefaults.standard.set(oled, forKey: "theme_oled") }
    }
    var typography: ThemeTypography {
        didSet { UserDefaults.standard.set(typography.rawValue, forKey: "theme_typography") }
    }
    var density: ThemeDensity {
        didSet { UserDefaults.standard.set(density.rawValue, forKey: "theme_density") }
    }

    init() {
        self.palette = ThemePalette(rawValue: UserDefaults.standard.string(forKey: "theme_palette") ?? "") ?? .yellow
        self.isDark = UserDefaults.standard.object(forKey: "theme_dark") as? Bool ?? true
        self.oled = UserDefaults.standard.object(forKey: "theme_oled") as? Bool ?? false
        self.typography = ThemeTypography(rawValue: UserDefaults.standard.string(forKey: "theme_typography") ?? "") ?? .technical
        self.density = ThemeDensity(rawValue: UserDefaults.standard.string(forKey: "theme_density") ?? "") ?? .detailed
    }

    var resolved: ResolvedTheme {
        let (bgHex, inkHex, accentHex) = palette.colors
        let space = DensitySpacing.forDensity(density)
        let typo = typography
        if isDark {
            // OLED forces true-black backgrounds while keeping the palette's accent + ink.
            return ResolvedTheme(
                bg: oled ? Color(hex: 0x000000) : Color(hex: inkHex).shiftBrightness(by: -0.02),
                surface: oled ? Color(hex: 0x0E0E0E) : Color(hex: inkHex).shiftBrightness(by: 0.03),
                sunken: oled ? Color(hex: 0x000000) : Color(hex: inkHex).shiftBrightness(by: -0.02),
                ink: Color(hex: bgHex),
                ink2: Color(hex: bgHex).opacity(0.78),
                muted: Color(hex: 0x8E8779),
                faint: Color(hex: 0x5A5447),
                hair: Color(hex: bgHex).opacity(oled ? 0.14 : 0.10),
                rule: Color(hex: bgHex).opacity(oled ? 0.20 : 0.18),
                accent: Color(hex: accentHex).shiftBrightness(by: 0.08),
                accentSoft: Color(hex: accentHex).opacity(0.18),
                danger: Color(hex: 0xD27860),
                ok: Color(hex: 0x9DAE7A),
                deferred: Color(hex: 0x7A6E7C),
                isDark: true,
                space: space,
                typography: typo
            )
        } else {
            return ResolvedTheme(
                bg: Color(hex: bgHex),
                surface: Color(hex: bgHex).shiftBrightness(by: 0.06),
                sunken: Color(hex: bgHex).shiftBrightness(by: -0.05),
                ink: Color(hex: inkHex),
                ink2: Color(hex: inkHex).opacity(0.78),
                muted: Color(hex: 0x655E52),
                faint: Color(hex: 0x8A7E72),
                hair: Color(hex: inkHex).opacity(0.12),
                rule: Color(hex: inkHex).opacity(0.20),
                accent: Color(hex: accentHex),
                accentSoft: Color(hex: accentHex).opacity(0.18),
                danger: Color(hex: 0xB0533A),
                ok: Color(hex: 0x6A7C4A),
                deferred: Color(hex: 0x9E96A0),
                isDark: false,
                space: space,
                typography: typo
            )
        }
    }
}

// ThemeManager is passed via .environment() using @Observable pattern.
// Access in views with: @Environment(ThemeManager.self) private var tm

// MARK: - Convenience

enum AmbidashTheme {
    static func dimensionColor(for dimension: LifeDimension) -> Color {
        switch dimension {
        case .body: Color(hex: 0x1D9E75)
        case .mind: Color(hex: 0x8B7EC8)
        case .craft: Color(hex: 0x378ADD)
        case .people: Color(hex: 0xA55E5B)
        case .wealth: Color(hex: 0xEF9F27)
        case .adventure: Color(hex: 0x7F77DD)
        }
    }
}

// MARK: - Color Extensions

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }

    func shiftBrightness(by amount: Double) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if os(iOS)
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #else
        NSColor(self).usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #endif
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(min(1, max(0, b + CGFloat(amount)))), opacity: Double(a))
    }
}
