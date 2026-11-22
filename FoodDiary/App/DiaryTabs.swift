import SwiftUI

struct DiaryTabs: View {
    private enum Tab {
        case home
        case history
        case avoidance
        case settings
    }

    @State private var selection: Tab = .home

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("tabs.home", systemImage: "house") }
            .tag(Tab.home)

            NavigationStack {
                HistoryView { selection = .home }
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("tabs.history", systemImage: "list.bullet.rectangle") }
            .tag(Tab.history)

            NavigationStack {
                AvoidanceView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("tabs.avoidance", systemImage: "eye") }
            .tag(Tab.avoidance)

            NavigationStack {
                SettingsView()
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("tabs.settings", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .tint(DiaryTheme.accent)
    }
}
