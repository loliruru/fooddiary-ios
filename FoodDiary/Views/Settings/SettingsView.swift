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

            NavigationLink {
                DiaryDataView()
            } label: {
                Label("data.title", systemImage: "externaldrive")
            }
            .buttonStyle(DiaryButtonStyle(kind: .secondary))

            DiaryCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("settings.privacy", systemImage: "lock.shield")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Text("settings.privacy.message")
                    Text("settings.privacy.sharing")
                }
                .font(.subheadline)
            }

            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
               let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
                DiaryCard {
                    LabeledContent {
                        Text("settings.versionValue \(version) \(build)")
                            .monospacedDigit()
                    } label: {
                        Label("settings.version", systemImage: "info.circle")
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
