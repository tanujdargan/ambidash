import SwiftUI

// MARK: - Palette Definitions

enum ThemePalette: String, CaseIterable, Codable, Identifiable {
    case warm, cool, forest, rose

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .warm: "Warm"
        case .cool: "Cool"
        case .forest: "Forest"
        case .rose: "Rose"
        }
    }

    var colors: (bg: UInt, ink: UInt, accent: UInt) {
        switch self {
        case .warm:   (0xF1EDE3, 0x1A1712, 0xB47A3A)
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

    var serif: String {
        switch self {
        case .editorial: "InstrumentSerif-Regular"
        case .modern: "Newsreader-Regular"
        case .technical: "Newsreader-Regular"
        }
    }

    var sans: String {
        switch self {
        case .editorial: ".AppleSystemUIFont"
        case .modern: ".AppleSystemUIFont"
        case .technical: ".AppleSystemUIFont"
        }
    }

    var mono: String {
        "Menlo"
    }

    var serifWeight: Font.Weight {
        switch self {
        case .editorial: .regular
        case .modern: .regular
        case .technical: .medium
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
    let isDark: Bool
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
    var typography: ThemeTypography {
        didSet { UserDefaults.standard.set(typography.rawValue, forKey: "theme_typography") }
    }
    var density: ThemeDensity {
        didSet { UserDefaults.standard.set(density.rawValue, forKey: "theme_density") }
    }

    init() {
        self.palette = ThemePalette(rawValue: UserDefaults.standard.string(forKey: "theme_palette") ?? "") ?? .warm
        self.isDark = UserDefaults.standard.object(forKey: "theme_dark") as? Bool ?? true
        self.typography = ThemeTypography(rawValue: UserDefaults.standard.string(forKey: "theme_typography") ?? "") ?? .technical
        self.density = ThemeDensity(rawValue: UserDefaults.standard.string(forKey: "theme_density") ?? "") ?? .detailed
    }

    var resolved: ResolvedTheme {
        let (bgHex, inkHex, accentHex) = palette.colors
        if isDark {
            return ResolvedTheme(
                bg: Color(hex: inkHex).shiftBrightness(by: -0.02),
                surface: Color(hex: inkHex).shiftBrightness(by: 0.03),
                sunken: Color(hex: inkHex).shiftBrightness(by: -0.02),
                ink: Color(hex: bgHex),
                ink2: Color(hex: bgHex).opacity(0.78),
                muted: Color(hex: 0x8E8779),
                faint: Color(hex: 0x5A5447),
                hair: Color(hex: bgHex).opacity(0.10),
                rule: Color(hex: bgHex).opacity(0.18),
                accent: Color(hex: accentHex).shiftBrightness(by: 0.08),
                accentSoft: Color(hex: accentHex).opacity(0.18),
                danger: Color(hex: 0xD27860),
                ok: Color(hex: 0x9DAE7A),
                isDark: true
            )
        } else {
            return ResolvedTheme(
                bg: Color(hex: bgHex),
                surface: Color(hex: bgHex).shiftBrightness(by: 0.04),
                sunken: Color(hex: bgHex).shiftBrightness(by: -0.04),
                ink: Color(hex: inkHex),
                ink2: Color(hex: inkHex).opacity(0.78),
                muted: Color(hex: 0x7A7468),
                faint: Color(hex: 0xA8A294),
                hair: Color(hex: inkHex).opacity(0.10),
                rule: Color(hex: inkHex).opacity(0.16),
                accent: Color(hex: accentHex),
                accentSoft: Color(hex: accentHex).opacity(0.14),
                danger: Color(hex: 0xB0533A),
                ok: Color(hex: 0x6A7C4A),
                isDark: false
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
        case .body: Color(hex: 0x6A7C4A)
        case .mind: Color(hex: 0x8B7EC8)
        case .focus: Color(hex: 0x5C7F8B)
        case .social: Color(hex: 0xA55E5B)
        case .growth: Color(hex: 0xB47A3A)
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
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(min(1, max(0, b + CGFloat(amount)))), opacity: Double(a))
    }
}
