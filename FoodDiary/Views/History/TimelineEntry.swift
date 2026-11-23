import SwiftUI

enum RecordAction: CaseIterable, Identifiable {
    case meal, snack, symptom

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .meal: IntakeType.meal.addTitle
        case .snack: IntakeType.snack.addTitle
        case .symptom: "home.action.symptom"
        }
    }

    var symbol: String {
        switch self {
        case .meal: "plus.circle.fill"
        case .snack: IntakeType.snack.symbol
        case .symptom: "heart.text.square"
        }
    }

    @ViewBuilder
    func editor(onSave: @escaping () -> Void) -> some View {
        switch self {
        case .meal: IntakeEditor(type: .meal, onSave: onSave)
        case .snack: IntakeEditor(type: .snack, onSave: onSave)
        case .symptom: SymptomEditor(onSave: onSave)
        }
    }
}

enum TimelineEntry: Identifiable {
    case intake(IntakeEvent)
    case symptom(SymptomEvent)

    var id: UUID {
        switch self {
        case .intake(let event): event.id
        case .symptom(let event): event.id
        }
    }

    var time: Date {
        switch self {
        case .intake(let event): event.eventTime
        case .symptom(let event): event.symptomTime
        }
    }

    static func ordered(intakes: [IntakeEvent], symptoms: [SymptomEvent]) -> [Self] {
        (intakes.map(Self.intake) + symptoms.map(Self.symptom)).sorted { $0.time > $1.time }
    }

    @ViewBuilder
    func row(onRecordAdded: @escaping () -> Void, showFeelingPrompt: Bool = false) -> some View {
        switch self {
        case .intake(let event):
            IntakeRow(event: event, showFeelingPrompt: showFeelingPrompt, onRecordAdded: onRecordAdded)
        case .symptom(let event):
            SymptomRow(event: event)
        }
    }
}
