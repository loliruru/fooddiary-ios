import Foundation
import SwiftData

enum ExposureJudgment: String, CaseIterable, Identifiable {
    case unreviewed, suspected, notRelated, unsure

    var id: Self { self }
}

@Model
final class SymptomExposureLink {
    @Attribute(.unique) var id: UUID
    var symptomEvent: SymptomEvent?
    var intakeEvent: IntakeEvent?
    var judgmentCode: String
    var note: String?
    var updatedAt: Date

    var judgment: ExposureJudgment { ExposureJudgment(rawValue: judgmentCode) ?? .unreviewed }

    init(symptom: SymptomEvent, intake: IntakeEvent, judgment: ExposureJudgment, now: Date) {
        id = UUID()
        symptomEvent = symptom
        intakeEvent = intake
        judgmentCode = judgment.rawValue
        updatedAt = now
    }
}
