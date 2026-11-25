import Foundation
import SwiftData

@MainActor
struct DiaryStore {
    enum InputError: Error {
        case invalidName
        case duplicateFavorite
        case outsideExposureWindow
    }

    let context: ModelContext
    var photos = DiaryPhotos.local

    static func makeContainer(at storeURL: URL) throws -> ModelContainer {
        let schema = Schema([
            IntakeEvent.self, IngredientItem.self, SavedPlace.self, SavedFood.self,
            SymptomEvent.self, MealCombo.self, SymptomExposureLink.self, AvoidanceStatus.self
        ])
        let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [config])
    }

    static func openLocal() throws -> ModelContainer {
        var directory = DiaryPhotos.dataDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let container = try makeContainer(at: directory.appending(path: "Diary.store"))
        try? DiaryStore(context: container.mainContext).cleanUpPhotos()
        return container
    }

    @discardableResult
    func saveIntake(_ draft: IntakeDraft, editing existing: IntakeEvent? = nil, now: Date = .now) throws -> IntakeEvent {
        guard draft.canSave, let name = DiaryName.text(draft.displayName) else { throw InputError.invalidName }
        let event = existing ?? IntakeEvent(intakeType: draft.intakeType, eventTime: draft.eventTime, displayName: name, now: now)

        try commitPhoto(draft.photo, previous: event.photoPath) { path in
            if existing == nil { context.insert(event) }
            event.eventTime = draft.eventTime
            event.displayName = name
            event.mealTypeRaw = draft.intakeType == .meal ? draft.mealType.rawValue : nil
            event.merchantName = draft.isHomemade ? nil : DiaryName.text(draft.merchantName)
            event.brandName = draft.intakeType == .snack ? DiaryName.text(draft.brandName) : nil
            event.amountText = draft.intakeType == .snack ? DiaryName.text(draft.amountText) : nil
            event.note = DiaryName.text(draft.note)
            event.tags = DiaryName.distinct(draft.tags)
            event.photoPath = path
            event.updatedAt = now
            updateIngredients(of: event, from: draft.isHomemade ? draft.ingredients : [])
            try markFavoritesUsed(in: event, now: now)
        }
        return event
    }

    func deleteIntake(_ event: IntakeEvent) throws {
        try commitPhoto(.remove, previous: event.photoPath) { _ in
            context.delete(event)
        }
    }

    @discardableResult
    func saveSymptom(
        _ draft: SymptomDraft, editing existing: SymptomEvent? = nil, now: Date = .now
    ) throws -> SymptomEvent {
        let event = existing ?? SymptomEvent(symptomTime: draft.symptomTime, recordedAt: now)
        try commit {
            if existing == nil { context.insert(event) }
            event.symptomTime = draft.symptomTime
            event.symptomCodes = Symptom.allCases.filter { draft.symptoms.contains($0) }.map(\.rawValue)
            event.diarrheaCount = draft.symptoms.contains(.diarrhea) ? max(0, draft.diarrheaCount) : 0
            event.feelingCode = draft.feeling?.rawValue
            event.severityCode = draft.severity?.rawValue
            event.durationCode = draft.duration?.rawValue
            event.note = DiaryName.text(draft.note)
            event.linkedMeal = draft.linkedMeal
        }
        return event
    }

    func deleteSymptom(_ event: SymptomEvent) throws {
        try commit { context.delete(event) }
    }

    func saveExposureJudgment(
        _ judgment: ExposureJudgment, symptom: SymptomEvent, intake: IntakeEvent, now: Date = .now
    ) throws {
        guard ExposureReview.contains(intake.eventTime, before: symptom.symptomTime) else {
            throw InputError.outsideExposureWindow
        }
        let existing = symptom.exposureLinks.first { $0.intakeEvent?.id == intake.id }
        try commit {
            if let existing {
                existing.judgmentCode = judgment.rawValue
                existing.updatedAt = now
            } else if judgment != .unreviewed {
                context.insert(SymptomExposureLink(symptom: symptom, intake: intake, judgment: judgment, now: now))
            }
        }
    }

    func saveAvoidanceChoice(
        _ choice: AvoidanceChoice?, for target: AvoidanceTarget, now: Date = .now
    ) throws {
        let key = target.id
        let request = FetchDescriptor<AvoidanceStatus>(predicate: #Predicate { $0.targetKey == key })
        let existing = try context.fetch(request).first
        try commit {
            if let existing, let choice {
                existing.choiceCode = choice.rawValue
                existing.displayName = target.name
                existing.updatedAt = now
            } else if let existing {
                context.delete(existing)
            } else if let choice {
                context.insert(AvoidanceStatus(target: target, choice: choice, now: now))
            }
        }
    }

    @discardableResult
    func saveCombo(
        name: String, ingredients: [IngredientDraft], editing existing: MealCombo? = nil, now: Date = .now
    ) throws -> MealCombo {
        guard let name = DiaryName.text(name), ingredients.allSatisfy(\.isValid) else {
            throw InputError.invalidName
        }
        let data = try JSONEncoder().encode(ingredients.compactMap(ComboIngredient.init(draft:)))
        let combo = existing ?? MealCombo(name: name, ingredientsData: data, now: now)
        try commit {
            if existing == nil { context.insert(combo) }
            combo.name = name
            combo.ingredientsData = data
            combo.updatedAt = now
        }
        return combo
    }

    func deleteCombo(_ combo: MealCombo) throws {
        try commit { context.delete(combo) }
    }

    func saveFavorite(
        _ kind: SavedKind, name: String, category: String = "", note: String = "",
        photo: PhotoChange = .keep, editing existing: SavedName? = nil, now: Date = .now
    ) throws {
        guard let name = DiaryName.text(name) else { throw InputError.invalidName }
        let key = DiaryName.normalized(name)
        let category = DiaryName.text(category)

        switch kind {
        case .food:
            let foods = try context.fetch(FetchDescriptor<SavedFood>())
            guard !foods.contains(where: { $0.id != existing?.id && DiaryName.normalized($0.name) == key }) else {
                throw InputError.duplicateFavorite
            }
            try commit {
                if case .food(let food)? = existing {
                    food.name = name
                    food.category = category
                } else {
                    let food = SavedFood(name: name, now: now)
                    food.category = category
                    context.insert(food)
                }
            }
        case .place:
            let places = try context.fetch(FetchDescriptor<SavedPlace>())
            guard !places.contains(where: { $0.id != existing?.id && DiaryName.normalized($0.name) == key }) else {
                throw InputError.duplicateFavorite
            }
            try commitPhoto(photo, previous: existing?.photoPath) { path in
                let place: SavedPlace
                if case .place(let savedPlace)? = existing {
                    place = savedPlace
                } else {
                    place = SavedPlace(name: name, now: now)
                    context.insert(place)
                }
                place.name = name
                place.category = category
                place.note = DiaryName.text(note)
                place.photoPath = path
            }
        }
    }

    func deleteFavorite(_ entry: SavedName) throws {
        try commitPhoto(.remove, previous: entry.photoPath) { _ in
            switch entry {
            case .food(let food): context.delete(food)
            case .place(let place): context.delete(place)
            }
        }
    }

    func cleanUpPhotos() throws {
        let events = try context.fetch(FetchDescriptor<IntakeEvent>())
        let places = try context.fetch(FetchDescriptor<SavedPlace>())
        photos.removeUnreferenced(keeping: Set(events.compactMap(\.photoPath) + places.compactMap(\.photoPath)))
    }

    private func updateIngredients(of event: IntakeEvent, from drafts: [IngredientDraft]) {
        var previous = Dictionary(uniqueKeysWithValues: event.ingredients.map { ($0.id, $0) })
        var updated: [IngredientItem] = []

        for draft in drafts {
            guard let name = DiaryName.text(draft.name) else { continue }
            let item: IngredientItem
            if let existing = previous.removeValue(forKey: draft.id) {
                item = existing
            } else {
                item = IngredientItem(id: draft.id, name: name, position: updated.count)
                context.insert(item)
            }
            item.name = name
            item.purchasePlaceName = DiaryName.text(draft.purchasePlaceName)
            item.amountText = DiaryName.text(draft.amountText)
            item.note = DiaryName.text(draft.note)
            item.position = updated.count
            updated.append(item)
        }
        event.ingredients = updated
        for item in previous.values { context.delete(item) }
    }

    private func markFavoritesUsed(in event: IntakeEvent, now: Date) throws {
        let foodKeys = Set(([event.displayName] + event.ingredients.map(\.name)).map(DiaryName.normalized))
        let places = [event.merchantName].compactMap { $0 } + event.ingredients.compactMap(\.purchasePlaceName)
        let placeKeys = Set(places.map(DiaryName.normalized))

        for food in try context.fetch(FetchDescriptor<SavedFood>()) where foodKeys.contains(DiaryName.normalized(food.name)) {
            food.lastUsedAt = now
        }
        for place in try context.fetch(FetchDescriptor<SavedPlace>()) where placeKeys.contains(DiaryName.normalized(place.name)) {
            place.lastUsedAt = now
        }
    }

    private func commitPhoto(_ change: PhotoChange, previous: String?, mutate: (String?) throws -> Void) throws {
        let path = try photos.prepare(change, previous: previous)
        do {
            try commit { try mutate(path) }
        } catch {
            if path != previous { photos.remove(path) }
            throw error
        }
        if path != previous { photos.remove(previous) }
    }

    func commit(_ mutate: () throws -> Void) throws {
        do {
            try mutate()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
