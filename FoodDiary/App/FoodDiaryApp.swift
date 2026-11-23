import SwiftData
import SwiftUI

@main
struct FoodDiaryApp: App {
    @State private var container: ModelContainer?
    @State private var openingFailed = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    DiaryTabs()
                        .modelContainer(container)
                } else if openingFailed {
                    ContentUnavailableView {
                        Label("storage.error", systemImage: "externaldrive.badge.exclamationmark")
                    } actions: {
                        Button("common.retry", action: openStorage)
                    }
                } else {
                    ProgressView("storage.loading")
                        .task { openStorage() }
                }
            }
            .environment(\.locale, Locale(identifier: "zh-Hans"))
        }
    }

    private func openStorage() {
        do {
            container = try DiaryStore.openLocal()
            openingFailed = false
        } catch {
            openingFailed = true
        }
    }
}
