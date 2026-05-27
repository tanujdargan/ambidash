import SwiftUI

struct EmptyStateView: View {
    @Environment(ThemeManager.self) private var tm
    let icon: String
    let title: String
    let subtitle: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        let t = tm.resolved
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle().stroke(t.hair, lineWidth: 0.5).frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(t.muted)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .regular, design: .serif))
                    .foregroundStyle(t.ink)

                Text(subtitle)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(t.faint)
                    .multilineTextAlignment(.center)
            }

            if let action, let label = actionLabel {
                PillButton(label: label, primary: true, action: action)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}
