import Foundation

struct TimelineFilter: Equatable {
    enum Kind: CaseIterable, Identifiable {
        case all, meals, takeout, dineIn, homemade, snacks, symptoms

        var id: Self { self }

        func includes(_ entry: TimelineEntry) -> Bool {
            switch (self, entry) {
            case (.all, _), (.symptoms, .symptom): true
            case (.meals, .intake(let event)): event.intakeType == .meal
            case (.snacks, .intake(let event)): event.intakeType == .snack
            case (.takeout, .intake(let event)): event.mealType == .takeout
            case (.dineIn, .intake(let event)): event.mealType == .dineIn
            case (.homemade, .intake(let event)): event.mealType == .homemade
            default: false
            }
        }
    }

    enum Feeling: CaseIterable, Identifiable {
        case all, unknown, good, neutral, bad

        var id: Self { self }

        func includes(_ feeling: BodyFeeling?) -> Bool {
            switch self {
            case .all: true
            case .unknown: feeling == nil
            case .good: feeling == .good
            case .neutral: feeling == .neutral
            case .bad: feeling == .bad
            }
        }
    }

    var kind: Kind = .all
    var feeling: Feeling = .all
    var symptom: Symptom?
    var days: ClosedRange<Date>?

    func apply(
        to entries: [TimelineEntry], searching search: String, calendar: Calendar = .autoupdatingCurrent
    ) -> [TimelineEntry] {
        let query = DiaryName.normalized(search)
        let dayRange = days.map { calendar.startOfDay(for: $0.lowerBound)...calendar.startOfDay(for: $0.upperBound) }
        return entries.filter { entry in
            if let dayRange, !dayRange.contains(calendar.startOfDay(for: entry.time)) { return false }
            guard kind.includes(entry), feeling.includes(entry.recordedFeeling) else { return false }
            if let symptom, !entry.recordedSymptoms.contains(symptom) { return false }
            return query.isEmpty || entry.searchableNames.contains { DiaryName.normalized($0).contains(query) }
        }
    }
}

private extension TimelineEntry {
    var recordedFeeling: BodyFeeling? {
        switch self {
        case .intake(let event): event.latestFeeling
        case .symptom(let event): event.feeling
        }
    }

    var recordedSymptoms: [Symptom] {
        switch self {
        case .intake(let event): event.linkedSymptoms.flatMap(\.symptoms)
        case .symptom(let event): event.symptoms
        }
    }

    var searchableNames: [String] {
        switch self {
        case .intake(let event):
            [event.displayName] + [event.merchantName, event.brandName].compactMap { $0 }
                + event.ingredients.map(\.name) + event.ingredients.compactMap(\.purchasePlaceName)
        case .symptom(let event):
            [event.linkedMeal?.displayName, event.linkedMeal?.merchantName].compactMap { $0 }
        }
    }
}
