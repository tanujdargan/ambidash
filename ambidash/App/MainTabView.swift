import SwiftUI

struct MainTabView: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            MainTabView18()
        } else {
            MainTabView17()
        }
    }
}

@available(iOS 18.0, *)
private struct MainTabView18: View {
    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "circle.grid.3x3") {
                DashboardView()
            }
            Tab("Today", systemImage: "play.fill") {
                TodayView()
            }
            Tab("Goals", systemImage: "target") {
                GoalListView()
            }
            Tab("Reflect", systemImage: "pencil.line") {
                ReflectView()
            }
        }
    }
}

private struct MainTabView17: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "circle.grid.3x3")
                }
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "play.fill")
                }
            GoalListView()
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
            ReflectView()
                .tabItem {
                    Label("Reflect", systemImage: "pencil.line")
                }
        }
    }
}
