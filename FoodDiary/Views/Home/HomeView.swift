import SwiftUI

struct HomeView: View {
    private enum QuickAction: String, Identifiable {
        case meal
        case snack
        case symptom

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .meal: "home.action.meal"
            case .snack: "home.action.snack"
            case .symptom: "home.action.symptom"
            }
        }

        var symbol: String {
            switch self {
            case .meal: "plus.circle.fill"
            case .snack: "takeoutbag.and.cup.and.straw"
            case .symptom: "heart.text.square"
            }
        }

        var description: LocalizedStringKey {
            switch self {
            case .meal: "home.preview.meal"
            case .snack: "home.preview.snack"
            case .symptom: "home.preview.symptom"
            }
        }
    }

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selectedAction: QuickAction?

    var body: some View {
        DiaryPage {
            VStack(alignment: .leading, spacing: 7) {
                Label("app.title", systemImage: "leaf.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DiaryTheme.accent)

                DiaryPageTitle(title: "home.greeting")

                Text(Date.now, format: .dateTime.month().day().weekday(.wide).locale(.init(identifier: "zh-Hans")))
                    .font(.subheadline)
                    .foregroundStyle(DiaryTheme.secondaryText)
            }

            todayCard

            VStack(spacing: 10) {
                actionButton(for: .meal, kind: .primary)

                let secondaryLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 10))
                    : AnyLayout(HStackLayout(spacing: 10))
                secondaryLayout {
                    actionButton(for: .snack, kind: .secondary)
                    actionButton(for: .symptom, kind: .secondary)
                }
            }
        }
        .sheet(item: $selectedAction) { action in
            NavigationStack {
                DiaryPage {
                    DiaryCard {
                        DiaryEmptyState(
                            title: "home.preview.title",
                            message: action.description,
                            symbol: action.symbol
                        )
                    }
                }
                .navigationTitle(action.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.done") {
                            selectedAction = nil
                        }
                    }
                }
            }
            .tint(DiaryTheme.accent)
        }
    }

    private var todayCard: some View {
        DiaryCard(fill: DiaryTheme.accentSurface) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("home.today")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(0, format: .number)
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                        Text("home.intake.unit")
                            .font(.subheadline)
                    }
                    .foregroundStyle(DiaryTheme.accent)
                    .accessibilityElement(children: .combine)

                    Text("home.empty.title")
                        .font(.subheadline)
                        .foregroundStyle(DiaryTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !typeSize.isAccessibilitySize {
                    ZStack {
                        Circle().fill(DiaryTheme.canvas)
                        Circle().strokeBorder(DiaryTheme.accent.opacity(0.24)).padding(7)
                        Image(systemName: "fork.knife")
                            .font(.system(size: 30, weight: .medium))
                            .foregroundStyle(DiaryTheme.accent)
                    }
                    .frame(width: 84, height: 84)
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private func actionButton(for action: QuickAction, kind: DiaryButtonStyle.Kind) -> some View {
        Button {
            selectedAction = action
        } label: {
            Label(action.title, systemImage: action.symbol)
        }
        .buttonStyle(DiaryButtonStyle(kind: kind))
        .accessibilityHint("home.preview.hint")
    }
}
