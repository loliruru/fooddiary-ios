import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("home.empty.title", systemImage: "fork.knife")
                .navigationTitle("app.title")
        }
    }
}
