import SwiftUI

struct DiaryPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .frame(maxWidth: 520, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .background(DiaryTheme.canvas.ignoresSafeArea())
        .foregroundStyle(DiaryTheme.text)
    }
}

struct DiaryPageTitle: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(DiaryTheme.pageTitle)
            .accessibilityAddTraits(.isHeader)
    }
}

struct DiaryCard<Content: View>: View {
    var fill: Color = DiaryTheme.surface
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(fill, in: RoundedRectangle(cornerRadius: DiaryTheme.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: DiaryTheme.cornerRadius)
                    .strokeBorder(DiaryTheme.border)
                    .allowsHitTesting(false)
            }
    }
}

struct DiaryEmptyState: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let symbol: String
    var ink = DiaryTheme.accent
    var fill = DiaryTheme.accentSurface

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(ink)
                .padding(12)
                .background(fill, in: RoundedRectangle(cornerRadius: 15))
                .accessibilityHidden(true)

            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(DiaryTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DiaryButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(kind == .primary ? DiaryTheme.onAccent : DiaryTheme.accent)
            .background(
                kind == .primary ? DiaryTheme.accent : DiaryTheme.accentSurface,
                in: RoundedRectangle(cornerRadius: 16)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.84 : 1) : 0.52)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
