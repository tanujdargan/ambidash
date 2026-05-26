import SwiftUI

enum AmbidashTheme {

    // MARK: - Background Layers

    static let bgDeep = Color("bgDeep")
    static let bgBase = Color("bgBase")
    static let bgElevated = Color("bgElevated")
    static let bgCard = Color("bgCard")

    // MARK: - Text

    static let textPrimary = Color("textPrimary")
    static let textSecondary = Color("textSecondary")
    static let textTertiary = Color("textTertiary")

    // MARK: - Accent

    static let accent = Color("accent")
    static let accentGlow = Color("accentGlow")
    static let accentMuted = Color("accentMuted")

    // MARK: - Status

    static let statusGood = Color("statusGood")
    static let statusWarn = Color("statusWarn")
    static let statusBad = Color("statusBad")

    // MARK: - Border

    static let border = Color("border")
    static let borderSubtle = Color("borderSubtle")

    // MARK: - Dimensions

    static let bodyFitness = Color(hex: 0x34D399)
    static let mindCognitive = Color(hex: 0xA78BFA)
    static let focusScreen = Color(hex: 0x60A5FA)
    static let socialComm = Color(hex: 0xF472B6)
    static let growthCareer = Color(hex: 0xFBBF24)

    // MARK: - Radii

    static let radiusSmall: CGFloat = 8
    static let radiusMedium: CGFloat = 12
    static let radiusLarge: CGFloat = 16
    static let radiusXL: CGFloat = 20

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32

    static func dimensionColor(for dimension: LifeDimension) -> Color {
        switch dimension {
        case .body: bodyFitness
        case .mind: mindCognitive
        case .focus: focusScreen
        case .social: socialComm
        case .growth: growthCareer
        }
    }
}

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
}
