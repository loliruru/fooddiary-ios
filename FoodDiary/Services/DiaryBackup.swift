import Foundation

struct DiaryBackup: Codable, Sendable {
    static let currentVersion = 1

    enum FormatError: Error, Equatable {
        case unsupportedVersion
        case invalidData
        case missingPhoto
    }

    let formatVersion: Int
    let exportedAt: Date
    let appVersion: String
    let timeZone: String
    let intakes: [Intake]
    let symptoms: [BodyRecord]
    let exposureLinks: [Exposure]
    let savedPlaces: [Place]
    let savedFoods: [Food]
    let mealCombos: [Combo]
    let avoidanceStatuses: [Status]

    struct Intake: Codable, Sendable {
        let id: UUID
        let eventTime: Date
        let intakeType: String
        let mealType: String?
        let displayName: String
        let merchantName: String?
        let brandName: String?
        let amountText: String?
        let note: String?
        let tags: [String]
        let photoJPEG: Data?
        let createdAt: Date
        let updatedAt: Date
        let ingredients: [Ingredient]
    }

    struct Ingredient: Codable, Sendable {
        let id: UUID
        let name: String
        let purchasePlaceName: String?
        let amountText: String?
        let note: String?
    }

    struct BodyRecord: Codable, Sendable {
        let id: UUID
        let symptomTime: Date
        let recordedAt: Date
        let symptoms: [String]
        let diarrheaCount: Int
        let feeling: String?
        let severity: String?
        let duration: String?
        let note: String?
        let linkedMealID: UUID?
    }

    struct Exposure: Codable, Sendable {
        let id: UUID
        let symptomID: UUID
        let intakeID: UUID
        let judgment: String
        let note: String?
        let updatedAt: Date
    }

    struct Place: Codable, Sendable {
        let id: UUID
        let name: String
        let category: String?
        let note: String?
        let photoJPEG: Data?
        let createdAt: Date
        let lastUsedAt: Date?
    }

    struct Food: Codable, Sendable {
        let id: UUID
        let name: String
        let category: String?
        let createdAt: Date
        let lastUsedAt: Date?
    }

    struct Combo: Codable, Sendable {
        let id: UUID
        let name: String
        let ingredients: [ComboIngredient]
        let createdAt: Date
        let updatedAt: Date
    }

    struct Status: Codable, Sendable {
        let id: UUID
        let kind: String
        let displayName: String
        let choice: String
        let updatedAt: Date
    }

    func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    static func readJSON(_ data: Data) throws -> DiaryBackup {
        struct Header: Decodable { let formatVersion: Int }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        guard try decoder.decode(Header.self, from: data).formatVersion == currentVersion else {
            throw FormatError.unsupportedVersion
        }
        let backup = try decoder.decode(DiaryBackup.self, from: data)
        try backup.validate()
        return backup
    }

    static func readJSON(from url: URL) throws -> DiaryBackup {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        var error: NSError?
        var contents: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { source in
            contents = Result { try Data(contentsOf: source) }
        }
        if let error { throw error }
        guard let contents else { throw FormatError.invalidData }
        return try readJSON(contents.get())
    }

    var recordCount: Int { intakes.count + symptoms.count }

    var templateCount: Int { savedPlaces.count + savedFoods.count + mealCombos.count }

    func validate() throws {
        guard formatVersion == Self.currentVersion else { throw FormatError.unsupportedVersion }
        let intakeIDs = Set(intakes.map(\.id))
        let mealIDs = Set(intakes.filter { $0.intakeType == IntakeType.meal.rawValue }.map(\.id))
        let symptomIDs = Set(symptoms.map(\.id))
        let ingredientIDs = intakes.flatMap { $0.ingredients.map(\.id) }
        guard Self.validDates(exportedAt),
              intakeIDs.count == intakes.count, symptomIDs.count == symptoms.count, intakeIDs.isDisjoint(with: symptomIDs),
              Self.isUnique(ingredientIDs), Self.isUnique(exposureLinks.map(\.id)),
              Self.isUnique(savedPlaces.map(\.id)), Self.isUnique(savedFoods.map(\.id)),
              Self.isUnique(mealCombos.map(\.id)), Self.isUnique(avoidanceStatuses.map(\.id)),
              Self.isUnique(savedPlaces.map { DiaryName.normalized($0.name) }),
              Self.isUnique(savedFoods.map { DiaryName.normalized($0.name) }),
              Self.isUnique(avoidanceStatuses.map { "\($0.kind):\(DiaryName.normalized($0.displayName))" })
        else { throw FormatError.invalidData }

        var exposuresBySymptom: [UUID: Set<UUID>] = [:]
        for link in exposureLinks {
            guard symptomIDs.contains(link.symptomID), intakeIDs.contains(link.intakeID),
                  ExposureJudgment(rawValue: link.judgment) != nil, Self.validDates(link.updatedAt),
                  exposuresBySymptom[link.symptomID, default: []].insert(link.intakeID).inserted
            else { throw FormatError.invalidData }
        }

        for intake in intakes {
            let mealType = intake.mealType.flatMap(MealType.init(rawValue:))
            guard DiaryName.text(intake.displayName) != nil, Self.validDates(intake.eventTime, intake.createdAt, intake.updatedAt),
                  let type = IntakeType(rawValue: intake.intakeType),
                  type == .meal ? mealType != nil : intake.mealType == nil,
                  mealType == .homemade || intake.ingredients.isEmpty,
                  intake.ingredients.allSatisfy({ DiaryName.text($0.name) != nil })
            else { throw FormatError.invalidData }
        }
        for symptom in symptoms {
            guard symptom.linkedMealID.map(mealIDs.contains) ?? true, Self.validDates(symptom.symptomTime, symptom.recordedAt),
                  symptom.symptoms.allSatisfy({ Symptom(rawValue: $0) != nil }),
                  Self.isUnique(symptom.symptoms), symptom.diarrheaCount >= 0,
                  symptom.diarrheaCount == 0 || symptom.symptoms.contains(Symptom.diarrhea.rawValue),
                  symptom.feeling.map({ BodyFeeling(rawValue: $0) != nil }) ?? true,
                  symptom.severity.map({ SymptomSeverity(rawValue: $0) != nil }) ?? true,
                  symptom.duration.map({ SymptomDuration(rawValue: $0) != nil }) ?? true
            else { throw FormatError.invalidData }
        }
        guard savedPlaces.allSatisfy({ DiaryName.text($0.name) != nil && Self.validDates($0.createdAt, $0.lastUsedAt) }),
              savedFoods.allSatisfy({ DiaryName.text($0.name) != nil && Self.validDates($0.createdAt, $0.lastUsedAt) }),
              mealCombos.allSatisfy({ combo in
                  DiaryName.text(combo.name) != nil && Self.validDates(combo.createdAt, combo.updatedAt)
                      && combo.ingredients.allSatisfy { DiaryName.text($0.name) != nil }
              }),
              avoidanceStatuses.allSatisfy({ status in
                  DiaryName.text(status.displayName) != nil && AvoidanceKind(rawValue: status.kind) != nil
                      && AvoidanceChoice(rawValue: status.choice) != nil && Self.validDates(status.updatedAt)
              }),
              intakes.compactMap(\.photoJPEG).allSatisfy(DiaryPhotos.isBackupJPEG),
              savedPlaces.compactMap(\.photoJPEG).allSatisfy(DiaryPhotos.isBackupJPEG)
        else { throw FormatError.invalidData }
    }

    private static func isUnique<T: Hashable>(_ values: [T]) -> Bool {
        Set(values).count == values.count
    }

    private static func validDates(_ dates: Date?...) -> Bool {
        let supported = Date.distantPast...Date.distantFuture
        return dates.compactMap { $0 }.allSatisfy(supported.contains)
    }
}
