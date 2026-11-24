import SwiftData
import SwiftUI

struct ExposureCandidates: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Query private var intakes: [IntakeEvent]
    @State private var showError = false

    let symptom: SymptomEvent

    init(symptom: SymptomEvent) {
        self.symptom = symptom
        _intakes = Query(
            filter: ExposureReview.predicate(before: symptom.symptomTime),
            sort: \IntakeEvent.eventTime, order: .reverse
        )
    }

    var body: some View {
        let judgments = Dictionary(
            symptom.exposureLinks.compactMap { link in link.intakeEvent.map { ($0.id, link.judgment) } },
            uniquingKeysWith: { current, _ in current }
        )
        LazyVStack(alignment: .leading, spacing: 12) {
            Text("exposure.title")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("exposure.window \(ExposureReview.windowHours)")
                .font(.subheadline)
                .foregroundStyle(DiaryTheme.secondaryText)
            if intakes.isEmpty {
                DiaryCard {
                    Text("exposure.empty")
                        .font(.subheadline)
                        .foregroundStyle(DiaryTheme.secondaryText)
                }
            }
            ForEach(intakes) { intake in
                candidate(intake, judgment: judgments[intake.id] ?? .unreviewed)
            }
        }
        .alert("common.saveError", isPresented: $showError) {
            Button("common.done", role: .cancel) {}
        }
    }

    private func candidate(_ intake: IntakeEvent, judgment: ExposureJudgment) -> some View {
        let hours = ExposureReview.hoursBefore(symptom.symptomTime, intakeTime: intake.eventTime)
            .formatted(.number.precision(.fractionLength(0...1)).locale(locale))
        return DiaryCard {
            VStack(alignment: .leading, spacing: 10) {
                NavigationLink {
                    IntakeDetail(event: intake, onRecordAdded: {})
                } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(intake.displayName).font(.headline)
                            Text(intake.kindTitle).foregroundStyle(DiaryTheme.accent)
                            if let merchant = intake.merchantName {
                                Text(merchant)
                            }
                            if let brand = intake.brandName {
                                Text(brand)
                            }
                            Text(intake.eventTime, format: .dateTime.year().month().day().hour().minute())
                                .foregroundStyle(DiaryTheme.secondaryText)
                            Text("exposure.elapsed \(hours)")
                                .foregroundStyle(DiaryTheme.secondaryText)
                        }
                        .font(.subheadline)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(DiaryTheme.secondaryText)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(DiaryTheme.text)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("exposure.intake")

                ForEach(intake.orderedIngredients) { ingredient in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(ingredient.name).fontWeight(.medium)
                        if let source = ingredient.purchasePlaceName {
                            Text("exposure.ingredientSource \(source)")
                                .foregroundStyle(DiaryTheme.secondaryText)
                        }
                        if let amount = ingredient.amountText {
                            Text(amount).foregroundStyle(DiaryTheme.secondaryText)
                        }
                        if let note = ingredient.note {
                            Text(note).foregroundStyle(DiaryTheme.secondaryText)
                        }
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                }

                Divider()
                Menu {
                    ForEach(ExposureJudgment.allCases) { option in
                        Button {
                            save(option, for: intake)
                        } label: {
                            if option == judgment {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    Label(judgment.title, systemImage: "chevron.up.chevron.down")
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 44, alignment: .leading)
                }
                .accessibilityHint(Text("exposure.judgment"))
                .accessibilityIdentifier("exposure.judgment")
            }
        }
    }

    private func save(_ judgment: ExposureJudgment, for intake: IntakeEvent) {
        do {
            try DiaryStore(context: context).saveExposureJudgment(judgment, symptom: symptom, intake: intake)
        } catch {
            showError = true
        }
    }
}

private extension ExposureJudgment {
    var title: LocalizedStringKey {
        switch self {
        case .unreviewed: "exposure.unreviewed"
        case .suspected: "exposure.suspected"
        case .notRelated: "exposure.notRelated"
        case .unsure: "exposure.unsure"
        }
    }
}
