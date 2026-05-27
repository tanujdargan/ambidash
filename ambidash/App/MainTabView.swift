import SwiftUI

struct MainTabView: View {
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

            // Custom tab bar
            HStack(spacing: 0) {
                TabBarButton(icon: "circle.grid.3x3", label: "Vitals", isSelected: selectedTab == 0, theme: t) { selectedTab = 0 }
                TabBarButton(icon: "clock", label: "Today", isSelected: selectedTab == 1, theme: t) { selectedTab = 1 }
                TabBarButton(icon: "flag", label: "Goals", isSelected: selectedTab == 2, theme: t) { selectedTab = 2 }
                TabBarButton(icon: "square.and.pencil", label: "Reflect", isSelected: selectedTab == 3, theme: t) { selectedTab = 3 }
                TabBarButton(icon: "envelope", label: "Mentor", isSelected: selectedTab == 4, theme: t) { selectedTab = 4 }
            }
            .padding(.top, 10)
            .padding(.bottom, 2)
            .background(
                t.bg
                    .overlay(alignment: .top) {
                        t.hair.frame(height: 0.5)
                    }
            )
        }
        .preferredColorScheme(tm.isDark ? .dark : .light)
        .onAppear {
            if let tab = initialTab { selectedTab = tab }
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
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? theme.ink : theme.faint)

                Text(label.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(isSelected ? theme.ink : theme.faint)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
