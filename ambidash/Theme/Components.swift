import SwiftUI

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AmbidashTheme.spacingMD)
            .background(AmbidashTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AmbidashTheme.radiusLarge)
                    .stroke(AmbidashTheme.border, lineWidth: 0.5)
            )
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AmbidashTheme.textTertiary)
            .tracking(1.2)
            .textCase(.uppercase)
    }
}

struct AccentButton: View {
    let title: String
    let icon: String?
    let isLoading: Bool
    let action: () -> Void

    init(_ title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AmbidashTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium))
        }
        .disabled(isLoading)
    }
}

struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AmbidashTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AmbidashTheme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: AmbidashTheme.radiusMedium)
                        .stroke(AmbidashTheme.border, lineWidth: 0.5)
                )
        }
    }
}

struct StatusDot: View {
    let status: GoalStatus

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var statusColor: Color {
        switch status {
        case .onTrack: AmbidashTheme.statusGood
        case .needsAttention: AmbidashTheme.statusWarn
        case .slipping: AmbidashTheme.statusBad
        case .paused: AmbidashTheme.textTertiary
        }
    }
}
