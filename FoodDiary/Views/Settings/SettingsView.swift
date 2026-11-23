import SwiftUI

struct SettingsView: View {
    var body: some View {
        DiaryPage {
            DiaryPageTitle(title: "tabs.settings")

            DiaryCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("favorites.title")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach([SavedKind.place, .food]) { kind in
                        NavigationLink {
                            SavedNamesView(kind: kind)
                        } label: {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                        .buttonStyle(DiaryButtonStyle(kind: .secondary))
                    }
                }
            }

            NavigationLink {
                MealCombosView()
            } label: {
                Label("combo.title", systemImage: "square.on.square")
            }
            .buttonStyle(DiaryButtonStyle(kind: .secondary))

            DiaryCard {
                DiaryEmptyState(
                    title: "settings.privacy",
                    message: "settings.privacy.message",
                    symbol: "lock.shield"
                )
            }

            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                DiaryCard {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Label("settings.version", systemImage: "info.circle")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(version)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(DiaryTheme.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
