import SwiftUI

struct MainTabView: View {
    /// Height reserved (via a bottom safe-area inset) for the custom tab bar that
    /// overlays content. Icon (~20) + label (~12) + 12 top + 6 bottom + 6 vertical
    /// button padding lands near 56; this is the inset that keeps screen content
    /// scrollable above the bar. Excludes the device's own bottom safe area, which
    /// the inset machinery already accounts for.
    static let tabBarReservedHeight: CGFloat = 56

    @Environment(ThemeManager.self) private var tm
    @State private var selectedTab = 0
    var initialTab: Int? = nil

    init(selectedTab: Int? = nil) {
        self.initialTab = selectedTab
    }

    var body: some View {
        let t = tm.resolved
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case 0: DashboardView()
                case 1: TodayView()
                case 2: GoalListView()
                case 3: ReflectView()
                case 4: MentorView()
                default: DashboardView()
                }
            }
            // Reserve space for the custom tab bar that overlays the content
            // below. Without this, each screen's ScrollView extends under the bar
            // and its last rows are unreachable. A safe-area inset cascades into
            // every child ScrollView automatically and adapts to device insets,
            // so no per-screen bottom padding is required.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: MainTabView.tabBarReservedHeight)
            }

            // Custom tab bar
            HStack(spacing: 0) {
                TabBarButton(icon: "circle.grid.3x3", label: "Vitals", isSelected: selectedTab == 0, theme: t) { selectedTab = 0 }
                TabBarButton(icon: "clock", label: "Today", isSelected: selectedTab == 1, theme: t) { selectedTab = 1 }
                TabBarButton(icon: "flag", label: "Goals", isSelected: selectedTab == 2, theme: t) { selectedTab = 2 }
                TabBarButton(icon: "square.and.pencil", label: "Reflect", isSelected: selectedTab == 3, theme: t) { selectedTab = 3 }
                TabBarButton(icon: "envelope", label: "Mentor", isSelected: selectedTab == 4, theme: t) { selectedTab = 4 }
            }
            .padding(.top, 12)
            .padding(.bottom, 6)
            .background(
                t.bg
                    .overlay(alignment: .top) {
                        t.hair.frame(height: 0.5)
                    }
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .preferredColorScheme(tm.isDark ? .dark : .light)
        .onAppear {
            if let tab = initialTab { selectedTab = tab }
        }
        // A warm-launch deep link / notification tap updates `initialTab` while
        // this view is already mounted; onAppear won't re-fire, so apply the new
        // target here too. Runs before RootView resets deepLinkTab (0.1s delay).
        .onChange(of: initialTab) { _, newTab in
            if let newTab { selectedTab = newTab }
        }
    }
}

private struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let theme: ResolvedTheme
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? theme.ink : theme.faint)

                Text(label.uppercased())
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(isSelected ? theme.ink : theme.faint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
