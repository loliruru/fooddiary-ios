import SwiftUI

struct DiaryTabs: View {
    private enum Tab {
        case home
        case history
        case avoidance
        case settings
    }

    @State private var selection: Tab = .home
    @State private var lastSaved: UUID?

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView(showSaved: lastSaved != nil, onRecordAdded: recordAdded)
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("tabs.home", systemImage: "house") }
            .tag(Tab.home)

            NavigationStack {
                HistoryView(onRecordAdded: recordAdded)
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
        .task(id: lastSaved) {
            guard lastSaved != nil else { return }
            do {
                try await Task.sleep(for: .seconds(3))
                lastSaved = nil
            } catch {}
        }
    }

    private func recordAdded() {
        selection = .home
        lastSaved = UUID()
        UIAccessibility.post(notification: .announcement, argument: String(localized: "home.saved"))
    }
}
