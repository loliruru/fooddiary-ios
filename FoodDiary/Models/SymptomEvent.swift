import Foundation
import SwiftData

enum Symptom: String, CaseIterable, Identifiable {
    case abdominalPain, diarrhea, nausea, vomiting, bloating, reflux, other

    var id: Self { self }
}

enum BodyFeeling: String, CaseIterable, Identifiable {
    case good, neutral, bad

    var id: Self { self }
}

enum SymptomSeverity: String, CaseIterable, Identifiable {
    case mild, moderate, severe

    var id: Self { self }
}

enum SymptomDuration: String, CaseIterable, Identifiable {
    case underHour, oneToThree, threeToSix, sixToTwentyFour, overDay, unknown

    var id: Self { self }
}

@Model
final class SymptomEvent {
    @Attribute(.unique) var id: UUID
    var symptomTime: Date
    var recordedAt: Date
    var symptomCodes: [String] = []
    var diarrheaCount: Int = 0
    var feelingCode: String?
    var severityCode: String?
    var durationCode: String?
    var note: String?
    var linkedMeal: IntakeEvent?

    var symptoms: [Symptom] { symptomCodes.compactMap(Symptom.init(rawValue:)) }
    var feeling: BodyFeeling? { feelingCode.flatMap(BodyFeeling.init(rawValue:)) }
    var severity: SymptomSeverity? { severityCode.flatMap(SymptomSeverity.init(rawValue:)) }
    var duration: SymptomDuration? { durationCode.flatMap(SymptomDuration.init(rawValue:)) }

    init(symptomTime: Date, recordedAt: Date) {
        id = UUID()
        self.symptomTime = symptomTime
        self.recordedAt = recordedAt
    }
}

struct SymptomDraft {
    var symptomTime: Date
    var symptoms: Set<Symptom> = []
    var diarrheaCount = 0
    var feeling: BodyFeeling?
    var severity: SymptomSeverity?
    var duration: SymptomDuration?
    var note = ""
    var linkedMeal: IntakeEvent?

    init(now: Date = .now) {
        symptomTime = now
    }

    init(event: SymptomEvent) {
        symptomTime = event.symptomTime
        symptoms = Set(event.symptoms)
        diarrheaCount = event.diarrheaCount
        feeling = event.feeling
        severity = event.severity
        duration = event.duration
        note = event.note ?? ""
        linkedMeal = event.linkedMeal
    }
}
