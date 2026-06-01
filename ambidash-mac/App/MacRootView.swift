import SwiftUI

extension Notification.Name {
    /// Posted by the Cmd-K "New Capture" command so the root window can present the
    /// capture sheet from anywhere in the app.
    static let macNewCapture = Notification.Name("ambidash.mac.newCapture")
}

/// The mac-native shell: a `NavigationSplitView` with a permanent sidebar
/// (Dashboard / Today / Goals / Reflect / Mentor / Settings) and a detail pane.
/// This replaces the iOS bottom `TabView` — bottom tabs are not a macOS idiom.
struct MacRootView: View {
    @Environment(ThemeManager.self) private var tm
    @State private var showCapture = false

    enum Section: String, CaseIterable, Identifiable, Hashable {
        case dashboard, today, goals, reflect, mentor, settings
        var id: String { rawValue }

        var title: String {
            switch self {
            case .dashboard: "Dashboard"
            case .today: "Today"
            case .goals: "Goals"
            case .reflect: "Reflect"
            case .mentor: "Mentor"
            case .settings: "Settings"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: "circle.grid.3x3.fill"
            case .today: "clock.fill"
            case .goals: "flag.fill"
            case .reflect: "square.and.pencil"
            case .mentor: "envelope.fill"
            case .settings: "gearshape.fill"
            }
        }
    }

    @State private var selection: Section? = .dashboard

    var body: some View {
        let theme = tm.resolved
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.icon)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .listStyle(.sidebar)
        } detail: {
            detail(for: selection ?? .dashboard)
                .background(theme.bg)
        }
        // Cmd-K "New Capture" → present the universal capture sheet from anywhere.
        .sheet(isPresented: $showCapture) {
            MacCaptureSheet()
                .environment(tm)
        }
        .onReceive(NotificationCenter.default.publisher(for: .macNewCapture)) { _ in
            showCapture = true
        }
    }

    @ViewBuilder
    private func detail(for section: Section) -> some View {
        switch section {
        case .dashboard: MacDashboardView()
        case .today: MacTodayView()
        case .goals: MacGoalsView()
        case .reflect: MacReflectView()
        case .mentor: MacMentorView()
        case .settings: MacSettingsView()
        }
    }
}
