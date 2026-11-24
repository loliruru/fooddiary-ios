import SwiftData
import SwiftUI

struct AvoidanceView: View {
    @Query private var intakes: [IntakeEvent]
    @Query private var symptoms: [SymptomEvent]
    @Query private var links: [SymptomExposureLink]
    @Query private var statuses: [AvoidanceStatus]
    @State private var selected = AvoidanceCategory.food

    var body: some View {
        let summaries = AvoidanceStatistics.summarize(
            intakes: intakes, symptoms: symptoms, links: links, statuses: statuses
        ).filter { selected.includes($0.target.kind) }
        DiaryPage {
            DiaryPageTitle(title: "tabs.avoidance")
            Picker("avoidance.category", selection: $selected) {
                ForEach(AvoidanceCategory.allCases) { category in
                    Text(category.title).tag(category)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .accessibilityIdentifier("avoidance.category")

            if summaries.isEmpty {
                DiaryCard {
                    DiaryEmptyState(
                        title: "avoidance.empty.title",
                        message: "avoidance.empty.message",
                        symbol: "eye",
                        ink: DiaryTheme.observation,
                        fill: DiaryTheme.observationSurface
                    )
                }
            } else {
                section("avoidance.repeated", symbol: "repeat", summaries.filter { $0.evidenceCount >= 2 })
                section("avoidance.single", symbol: "clock", summaries.filter { $0.evidenceCount == 1 })
                section("avoidance.suspectedOnly", symbol: "eye", summaries.filter {
                    $0.evidenceCount == 0 && $0.suspectedCount > 0
                })
                section("avoidance.manual", symbol: "bookmark", summaries.filter { $0.choice != nil })
                let other = summaries.filter { $0.evidenceCount == 0 && $0.suspectedCount == 0 && $0.choice == nil }
                if !other.isEmpty {
                    DisclosureGroup {
                        VStack(spacing: 10) {
                            summaryLinks(other)
                        }
                        .padding(.top, 8)
                    } label: {
                        Label("avoidance.other", systemImage: "list.bullet")
                            .font(.headline)
                            .frame(minHeight: 44, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, symbol: String, _ summaries: [AvoidanceSummary]) -> some View {
        if !summaries.isEmpty {
            LazyVStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: symbol)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                summaryLinks(summaries)
            }
        }
    }

    private func summaryLinks(_ summaries: [AvoidanceSummary]) -> some View {
        ForEach(summaries) { summary in
            NavigationLink {
                AvoidanceDetail(target: summary.target)
            } label: {
                DiaryCard {
                    HStack(alignment: .top, spacing: 10) {
                        AvoidanceSummaryText(summary: summary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(DiaryTheme.secondaryText)
                            .accessibilityHidden(true)
                    }
                }
                .foregroundStyle(DiaryTheme.text)
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("avoidance.summary")
        }
    }
}

private enum AvoidanceCategory: CaseIterable, Identifiable {
    case food, ingredient, place

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .food: "avoidance.food"
        case .ingredient: "avoidance.ingredient"
        case .place: "avoidance.placesAndBrands"
        }
    }

    func includes(_ kind: AvoidanceKind) -> Bool {
        switch self {
        case .food: kind == .food
        case .ingredient: kind == .ingredient
        case .place: kind == .place || kind == .brand
        }
    }
}
