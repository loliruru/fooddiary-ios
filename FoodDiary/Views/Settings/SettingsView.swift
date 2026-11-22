import SwiftUI

struct SettingsView: View {
    var body: some View {
        DiaryPage {
            DiaryPageTitle(title: "tabs.settings")

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
