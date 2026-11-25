import Foundation
import SwiftData

extension DiaryStore {
    func backup(
        includingPhotos: Bool = true, now: Date = .now,
        timeZone: TimeZone = .current
    ) throws -> DiaryBackup {
        let records = try StoredDiary(context: context)

        func photo(_ path: String?) throws -> Data? {
            guard includingPhotos, let path else { return nil }
            guard let data = photos.data(for: path), DiaryPhotos.isBackupJPEG(data) else {
                throw DiaryBackup.FormatError.missingPhoto
            }
            return data
        }

        return try DiaryBackup(
            formatVersion: DiaryBackup.currentVersion, exportedAt: now,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            timeZone: timeZone.identifier,
            intakes: records.intakes.map { event in
                DiaryBackup.Intake(
                    id: event.id, eventTime: event.eventTime, intakeType: event.intakeTypeRaw,
                    mealType: event.mealTypeRaw, displayName: event.displayName, merchantName: event.merchantName,
                    brandName: event.brandName, amountText: event.amountText, note: event.note, tags: event.tags,
                    photoJPEG: try photo(event.photoPath), createdAt: event.createdAt, updatedAt: event.updatedAt,
                    ingredients: event.orderedIngredients.map {
                        DiaryBackup.Ingredient(
                            id: $0.id, name: $0.name, purchasePlaceName: $0.purchasePlaceName,
                            amountText: $0.amountText, note: $0.note
                        )
                    }
                )
            },
            symptoms: records.symptoms.map {
                DiaryBackup.BodyRecord(
                    id: $0.id, symptomTime: $0.symptomTime, recordedAt: $0.recordedAt,
                    symptoms: $0.symptomCodes, diarrheaCount: $0.diarrheaCount, feeling: $0.feelingCode,
                    severity: $0.severityCode, duration: $0.durationCode, note: $0.note,
                    linkedMealID: $0.linkedMeal?.id
                )
            },
            exposureLinks: records.links.map { link in
                guard let symptom = link.symptomEvent, let intake = link.intakeEvent else {
                    throw DiaryBackup.FormatError.invalidData
                }
                return DiaryBackup.Exposure(
                    id: link.id, symptomID: symptom.id, intakeID: intake.id,
                    judgment: link.judgmentCode, note: link.note, updatedAt: link.updatedAt
                )
            },
            savedPlaces: records.places.map {
                DiaryBackup.Place(
                    id: $0.id, name: $0.name, category: $0.category, note: $0.note,
                    photoJPEG: try photo($0.photoPath), createdAt: $0.createdAt, lastUsedAt: $0.lastUsedAt
                )
            },
            savedFoods: records.foods.map {
                DiaryBackup.Food(
                    id: $0.id, name: $0.name, category: $0.category,
                    createdAt: $0.createdAt, lastUsedAt: $0.lastUsedAt
                )
            },
            mealCombos: records.combos.map {
                DiaryBackup.Combo(
                    id: $0.id, name: $0.name, ingredients: try JSONDecoder().decode([ComboIngredient].self, from: $0.ingredientsData),
                    createdAt: $0.createdAt, updatedAt: $0.updatedAt
                )
            },
            avoidanceStatuses: records.statuses.map {
                DiaryBackup.Status(
                    id: $0.id, kind: $0.kindCode, displayName: $0.displayName,
                    choice: $0.choiceCode, updatedAt: $0.updatedAt
                )
            }
        )
    }

    func restore(_ backup: DiaryBackup) throws {
        try backup.validate()
        let records = try StoredDiary(context: context)
        try importBackup(backup, replacing: records)
        try? cleanUpPhotos()
    }

    func clearAll() throws {
        let records = try StoredDiary(context: context)
        try commit {
            for link in records.links { context.delete(link) }
            for symptom in records.symptoms { context.delete(symptom) }
            for ingredient in records.ingredients { context.delete(ingredient) }
            for intake in records.intakes { context.delete(intake) }
            for place in records.places { context.delete(place) }
            for food in records.foods { context.delete(food) }
            for combo in records.combos { context.delete(combo) }
            for status in records.statuses { context.delete(status) }
        }
        photos.removeUnreferenced(keeping: [])
    }

    private func importBackup(_ backup: DiaryBackup, replacing records: StoredDiary) throws {
        var previousIntakes = BackupIndex(records.intakes, by: \.id)
        var previousIngredients = BackupIndex(records.ingredients, by: \.id)
        var previousSymptoms = BackupIndex(records.symptoms, by: \.id)
        var previousLinks = BackupIndex(records.links, by: \.id)
        var previousPlaces = BackupIndex(records.places, by: \.id)
        var previousFoods = BackupIndex(records.foods, by: \.id)
        var previousCombos = BackupIndex(records.combos, by: \.id)
        var previousStatuses = BackupIndex(records.statuses, by: \.targetKey)
        let statusKeys = Dictionary(uniqueKeysWithValues: records.statuses.map { ($0.id, $0.targetKey) })
        var intakes: [UUID: IntakeEvent] = [:]
        var symptoms: [UUID: SymptomEvent] = [:]
        var newPhotos: [String] = []

        func importPhoto(_ data: Data?) throws -> String? {
            guard let data else { return nil }
            let path = try photos.prepare(.replace(data), previous: nil)
            if let path { newPhotos.append(path) }
            return path
        }

        do {
            try commit {
                for item in backup.intakes {
                    let event = previousIntakes.take(item.id, in: context) {
                        let event = IntakeEvent(
                            intakeType: .meal, eventTime: item.eventTime, displayName: item.displayName, now: item.createdAt
                        )
                        event.id = item.id
                        return event
                    }
                    event.eventTime = item.eventTime
                    event.intakeTypeRaw = item.intakeType
                    event.mealTypeRaw = item.mealType
                    event.displayName = item.displayName
                    event.merchantName = item.merchantName
                    event.brandName = item.brandName
                    event.amountText = item.amountText
                    event.note = item.note
                    event.tags = item.tags
                    event.photoPath = try importPhoto(item.photoJPEG)
                    event.createdAt = item.createdAt
                    event.updatedAt = item.updatedAt
                    event.ingredients = item.ingredients.enumerated().map { position, row in
                        let ingredient = previousIngredients.take(row.id, in: context) {
                            IngredientItem(id: row.id, name: row.name, position: position)
                        }
                        ingredient.name = row.name
                        ingredient.purchasePlaceName = row.purchasePlaceName
                        ingredient.amountText = row.amountText
                        ingredient.note = row.note
                        ingredient.position = position
                        return ingredient
                    }
                    intakes[item.id] = event
                }

                for item in backup.symptoms {
                    let event = previousSymptoms.take(item.id, in: context) {
                        let event = SymptomEvent(symptomTime: item.symptomTime, recordedAt: item.recordedAt)
                        event.id = item.id
                        return event
                    }
                    event.symptomTime = item.symptomTime
                    event.recordedAt = item.recordedAt
                    event.symptomCodes = item.symptoms
                    event.diarrheaCount = item.diarrheaCount
                    event.feelingCode = item.feeling
                    event.severityCode = item.severity
                    event.durationCode = item.duration
                    event.note = item.note
                    event.linkedMeal = item.linkedMealID.flatMap { intakes[$0] }
                    symptoms[item.id] = event
                }

                for item in backup.exposureLinks {
                    guard let symptom = symptoms[item.symptomID], let intake = intakes[item.intakeID] else {
                        throw DiaryBackup.FormatError.invalidData
                    }
                    let link = previousLinks.take(item.id, in: context) {
                        let link = SymptomExposureLink(symptom: symptom, intake: intake, judgment: .unreviewed, now: item.updatedAt)
                        link.id = item.id
                        return link
                    }
                    link.symptomEvent = symptom
                    link.intakeEvent = intake
                    link.judgmentCode = item.judgment
                    link.note = item.note
                    link.updatedAt = item.updatedAt
                }

                for item in backup.savedPlaces {
                    let place = previousPlaces.take(item.id, in: context) {
                        let place = SavedPlace(name: item.name, now: item.createdAt)
                        place.id = item.id
                        return place
                    }
                    place.name = item.name
                    place.category = item.category
                    place.note = item.note
                    place.photoPath = try importPhoto(item.photoJPEG)
                    place.createdAt = item.createdAt
                    place.lastUsedAt = item.lastUsedAt
                }
                for item in backup.savedFoods {
                    let food = previousFoods.take(item.id, in: context) {
                        let food = SavedFood(name: item.name, now: item.createdAt)
                        food.id = item.id
                        return food
                    }
                    food.name = item.name
                    food.category = item.category
                    food.createdAt = item.createdAt
                    food.lastUsedAt = item.lastUsedAt
                }
                for item in backup.mealCombos {
                    let ingredients = try JSONEncoder().encode(item.ingredients)
                    let combo = previousCombos.take(item.id, in: context) {
                        let combo = MealCombo(name: item.name, ingredientsData: ingredients, now: item.createdAt)
                        combo.id = item.id
                        return combo
                    }
                    combo.name = item.name
                    combo.ingredientsData = ingredients
                    combo.createdAt = item.createdAt
                    combo.updatedAt = item.updatedAt
                }
                for item in backup.avoidanceStatuses {
                    guard let kind = AvoidanceKind(rawValue: item.kind), let choice = AvoidanceChoice(rawValue: item.choice) else {
                        throw DiaryBackup.FormatError.invalidData
                    }
                    let target = AvoidanceTarget(kind: kind, name: item.displayName)
                    guard statusKeys[item.id].map({ $0 == target.id }) ?? true else {
                        throw DiaryBackup.FormatError.invalidData
                    }
                    let status = previousStatuses.take(target.id, in: context) {
                        AvoidanceStatus(target: target, choice: choice, now: item.updatedAt)
                    }
                    status.id = item.id
                    status.kindCode = item.kind
                    status.displayName = item.displayName
                    status.choiceCode = item.choice
                    status.updatedAt = item.updatedAt
                }

                previousLinks.deleteRemaining(in: context)
                previousSymptoms.deleteRemaining(in: context)
                previousIngredients.deleteRemaining(in: context)
                previousIntakes.deleteRemaining(in: context)
                previousPlaces.deleteRemaining(in: context)
                previousFoods.deleteRemaining(in: context)
                previousCombos.deleteRemaining(in: context)
                previousStatuses.deleteRemaining(in: context)
            }
        } catch {
            for path in newPhotos { photos.remove(path) }
            throw error
        }
    }
}

private struct StoredDiary {
    let intakes: [IntakeEvent]
    let ingredients: [IngredientItem]
    let symptoms: [SymptomEvent]
    let links: [SymptomExposureLink]
    let places: [SavedPlace]
    let foods: [SavedFood]
    let combos: [MealCombo]
    let statuses: [AvoidanceStatus]

    init(context: ModelContext) throws {
        intakes = try context.fetch(FetchDescriptor(sortBy: [SortDescriptor(\IntakeEvent.eventTime)]))
        ingredients = try context.fetch(FetchDescriptor<IngredientItem>())
        symptoms = try context.fetch(FetchDescriptor(sortBy: [SortDescriptor(\SymptomEvent.symptomTime)]))
        links = try context.fetch(FetchDescriptor(sortBy: [SortDescriptor(\SymptomExposureLink.updatedAt)]))
        places = try context.fetch(FetchDescriptor(sortBy: [SortDescriptor(\SavedPlace.createdAt)]))
        foods = try context.fetch(FetchDescriptor(sortBy: [SortDescriptor(\SavedFood.createdAt)]))
        combos = try context.fetch(FetchDescriptor(sortBy: [SortDescriptor(\MealCombo.createdAt)]))
        statuses = try context.fetch(FetchDescriptor(sortBy: [SortDescriptor(\AvoidanceStatus.targetKey)]))
    }
}

private struct BackupIndex<Model: PersistentModel, Key: Hashable> {
    private var remaining: [Key: Model]

    init(_ models: [Model], by key: KeyPath<Model, Key>) {
        remaining = Dictionary(uniqueKeysWithValues: models.map { ($0[keyPath: key], $0) })
    }

    mutating func take(_ key: Key, in context: ModelContext, create: () -> Model) -> Model {
        if let model = remaining.removeValue(forKey: key) { return model }
        let model = create()
        context.insert(model)
        return model
    }

    func deleteRemaining(in context: ModelContext) {
        for model in remaining.values { context.delete(model) }
    }
}
