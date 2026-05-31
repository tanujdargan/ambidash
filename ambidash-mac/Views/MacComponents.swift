import SwiftUI

/// Small mac-native building blocks shared across the desktop views. These keep
/// the UI consistent with the iOS theme system (ResolvedTheme) without pulling
/// in any iOS-only SwiftUI modifiers.

/// A titled card surface used to group content on the desktop.
struct MacCard<Content: View>: View {
    @Environment(ThemeManager.self) private var tm
    let title: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        let theme = tm.resolved
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.muted)
                    .tracking(1)
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.hair, lineWidth: 1)
        )
    }
}

/// A standard mac screen scaffold: a large heading, optional trailing accessory,
/// and a scrollable content body on the themed background.
struct MacScreen<Accessory: View, Content: View>: View {
    @Environment(ThemeManager.self) private var tm
    let title: String
    let subtitle: String?
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        let theme = tm.resolved
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(theme.heading(30))
                            .foregroundStyle(theme.ink)
                        if let subtitle {
                            Text(subtitle)
                                .font(theme.body(14))
                                .foregroundStyle(theme.muted)
                        }
                    }
                    Spacer()
                    accessory
                }
                content
            }
            .padding(28)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.bg)
    }
}

/// A compact score readout (big number + caption) used on the dashboard.
struct MacScoreBadge: View {
    @Environment(ThemeManager.self) private var tm
    let value: Int
    let caption: String
    var tint: Color?

    var body: some View {
        let theme = tm.resolved
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(tint ?? theme.accent)
            Text(caption.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.muted)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.sunken)
        )
    }
}
