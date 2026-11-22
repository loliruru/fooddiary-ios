import SwiftUI

struct HistoryView: View {
    let onGoHome: () -> Void

    var body: some View {
        DiaryPage {
            DiaryPageTitle(title: "tabs.history")

            DiaryCard {
                VStack(alignment: .leading, spacing: 18) {
                    DiaryEmptyState(
                        title: "history.empty.title",
                        message: "history.empty.message",
                        symbol: "calendar"
                    )

                    Button(action: onGoHome) {
                        Label("history.goHome", systemImage: "house")
                    }
                    .buttonStyle(DiaryButtonStyle(kind: .secondary))
                }
            }
        }
    }
}
