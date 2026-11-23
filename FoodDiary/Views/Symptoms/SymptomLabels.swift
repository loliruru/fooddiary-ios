import SwiftUI

extension Symptom {
    var title: LocalizedStringResource {
        switch self {
        case .abdominalPain: "symptom.abdominalPain"
        case .diarrhea: "symptom.diarrhea"
        case .nausea: "symptom.nausea"
        case .vomiting: "symptom.vomiting"
        case .bloating: "symptom.bloating"
        case .reflux: "symptom.reflux"
        case .other: "symptom.other"
        }
    }
}

extension BodyFeeling {
    var title: LocalizedStringKey {
        switch self {
        case .good: "feeling.good"
        case .neutral: "feeling.neutral"
        case .bad: "feeling.bad"
        }
    }

    var emoji: String {
        switch self {
        case .good: "😄"
        case .neutral: "😐"
        case .bad: "😣"
        }
    }
}

extension SymptomSeverity {
    var title: LocalizedStringKey {
        switch self {
        case .mild: "symptom.mild"
        case .moderate: "symptom.moderate"
        case .severe: "symptom.severe"
        }
    }
}

extension SymptomDuration {
    var title: LocalizedStringKey {
        switch self {
        case .underHour: "symptom.underHour"
        case .oneToThree: "symptom.oneToThree"
        case .threeToSix: "symptom.threeToSix"
        case .sixToTwentyFour: "symptom.sixToTwentyFour"
        case .overDay: "symptom.overDay"
        case .unknown: "symptom.unknownDuration"
        }
    }
}
