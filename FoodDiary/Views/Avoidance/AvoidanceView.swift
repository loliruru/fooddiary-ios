import SwiftUI

struct AvoidanceView: View {
    var body: some View {
        DiaryPage {
            DiaryPageTitle(title: "tabs.avoidance")

            DiaryCard {
                DiaryEmptyState(
                    title: "avoidance.empty.title",
                    message: "avoidance.empty.message",
                    symbol: "eye",
                    ink: DiaryTheme.observation,
                    fill: DiaryTheme.observationSurface
                )
            }

            DiaryCard {
                VStack(alignment: .leading, spacing: 12) {
                    category("avoidance.repeated", symbol: "repeat")
                    Divider()
                    category("avoidance.single", symbol: "clock")
                    Divider()
                    category("avoidance.manual", symbol: "bookmark")
                }
            }
        }
    }

    private func category(_ title: LocalizedStringKey, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("common.none")
                .font(.subheadline)
                .foregroundStyle(DiaryTheme.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}
