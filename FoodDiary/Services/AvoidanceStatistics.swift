import Foundation

struct AvoidanceIntake: Identifiable {
    let event: IntakeEvent
    let suspectedBy: [SymptomEvent]
    let evidence: [SymptomEvent]

    var id: UUID { event.id }

    var relevantSymptoms: [SymptomEvent] {
        var seen = Set<UUID>()
        return (evidence + suspectedBy).filter { seen.insert($0.id).inserted }
            .sorted { $0.symptomTime > $1.symptomTime }
    }
}

struct AvoidanceSummary: Identifiable {
    static let smallSampleLimit = 5

    let target: AvoidanceTarget
    var intakes: [AvoidanceIntake] = []
    var choice: AvoidanceChoice?

    var id: String { target.id }
    var suspectedCount: Int { intakes.reduce(0) { $0 + $1.suspectedBy.count } }
    var evidenceCount: Int { intakes.filter { !$0.evidence.isEmpty }.count }
    var latestEvidence: Date? { intakes.lazy.flatMap(\.evidence).map(\.symptomTime).max() }
    var symptoms: [Symptom] {
        let observed = Set(intakes.flatMap(\.evidence).flatMap(\.symptoms))
        return Symptom.allCases.filter { observed.contains($0) }
    }
}

enum AvoidanceStatistics {
    static func summarize(
        intakes: [IntakeEvent], symptoms: [SymptomEvent],
        links: [SymptomExposureLink], statuses: [AvoidanceStatus]
    ) -> [AvoidanceSummary] {
        var suspected: [UUID: [UUID: SymptomEvent]] = [:]
        var evidence: [UUID: [UUID: SymptomEvent]] = [:]
        var declined: [UUID: Set<UUID>] = [:]

        for link in links {
            guard let intake = link.intakeEvent, let symptom = link.symptomEvent,
                  ExposureReview.contains(intake.eventTime, before: symptom.symptomTime) else { continue }
            switch link.judgment {
            case .suspected:
                suspected[intake.id, default: [:]][symptom.id] = symptom
                if hasDiscomfortEvidence(symptom) {
                    evidence[intake.id, default: [:]][symptom.id] = symptom
                }
            case .notRelated, .unsure:
                declined[intake.id, default: []].insert(symptom.id)
            case .unreviewed:
                break
            }
        }

        for symptom in symptoms where hasDiscomfortEvidence(symptom) {
            if let meal = symptom.linkedMeal, declined[meal.id]?.contains(symptom.id) != true {
                evidence[meal.id, default: [:]][symptom.id] = symptom
            }
        }

        var summaries: [String: AvoidanceSummary] = [:]
        for intake in intakes.sorted(by: { $0.eventTime > $1.eventTime }) {
            let record = AvoidanceIntake(
                event: intake,
                suspectedBy: suspected[intake.id].map { Array($0.values) } ?? [],
                evidence: evidence[intake.id].map { Array($0.values) } ?? []
            )
            for target in targets(for: intake) {
                summaries[target.id, default: AvoidanceSummary(target: target)].intakes.append(record)
            }
        }
        for status in statuses {
            let target = status.target
            summaries[target.id, default: AvoidanceSummary(target: target)].choice = status.choice
        }

        return summaries.values.sorted {
            let comparison = $0.target.name.localizedStandardCompare($1.target.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }

    private static func hasDiscomfortEvidence(_ symptom: SymptomEvent) -> Bool {
        symptom.feeling == .bad && !symptom.symptoms.isEmpty
    }

    private static func targets(for intake: IntakeEvent) -> [AvoidanceTarget] {
        let groups: [(AvoidanceKind, [String])] = [
            (.food, [intake.displayName]),
            (.ingredient, intake.orderedIngredients.map(\.name)),
            (.place, [intake.merchantName].compactMap { $0 } + intake.orderedIngredients.compactMap(\.purchasePlaceName)),
            (.brand, [intake.brandName].compactMap { $0 })
        ]
        return groups.flatMap { kind, names in
            DiaryName.distinct(names).map { AvoidanceTarget(kind: kind, name: $0) }
        }
    }
}
