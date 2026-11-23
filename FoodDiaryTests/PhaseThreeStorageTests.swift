import SwiftData
import XCTest
@testable import FoodDiary

final class PhaseThreeStorageTests: XCTestCase {
    @MainActor
    func testIndependentSymptomPersistsBothTimesAndNormalizesDiarrheaCount() throws {
        let url = try temporaryStore()
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let recorded = started.addingTimeInterval(8 * 3600)
        let corrected = started.addingTimeInterval(-30 * 60)
        let id: UUID

        do {
            let container = try DiaryStore.makeContainer(at: url)
            let store = DiaryStore(context: container.mainContext)
            var draft = SymptomDraft(now: started)
            draft.symptoms = [.diarrhea, .abdominalPain]
            draft.diarrheaCount = -3
            draft.severity = .moderate
            draft.duration = .oneToThree
            draft.note = " 夜间开始 "
            let event = try store.saveSymptom(draft, now: recorded)
            id = event.id
            XCTAssertEqual(event.diarrheaCount, 0)

            draft.symptomTime = corrected
            draft.diarrheaCount = 3
            try store.saveSymptom(draft, editing: event, now: recorded.addingTimeInterval(3600))
        }

        let container = try DiaryStore.makeContainer(at: url)
        let context = container.mainContext
        let event = try XCTUnwrap(context.fetch(FetchDescriptor<SymptomEvent>()).first)
        XCTAssertEqual(event.id, id)
        XCTAssertEqual(event.symptomTime, corrected)
        XCTAssertEqual(event.recordedAt, recorded)
        XCTAssertEqual(event.symptoms, [.abdominalPain, .diarrhea])
        XCTAssertEqual(event.diarrheaCount, 3)
        XCTAssertEqual(event.severity, .moderate)
        XCTAssertEqual(event.duration, .oneToThree)
        XCTAssertEqual(event.note, "夜间开始")
        XCTAssertNil(event.feeling)
        XCTAssertNil(event.linkedMeal)

        let store = DiaryStore(context: context)
        var edited = SymptomDraft(event: event)
        edited.symptoms.remove(.diarrhea)
        edited.feeling = .neutral
        try store.saveSymptom(edited, editing: event)
        XCTAssertEqual(event.symptoms, [.abdominalPain])
        XCTAssertEqual(event.diarrheaCount, 0)
        XCTAssertEqual(event.feeling, .neutral)
        XCTAssertEqual(event.recordedAt, recorded)
        try store.deleteSymptom(event)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SymptomEvent>()), 0)
    }

    @MainActor
    func testMealAssociationIsOptionalAndDeletingEitherSidePreservesTheOther() throws {
        let url = try temporaryStore()
        let mealID: UUID
        do {
            let container = try DiaryStore.makeContainer(at: url)
            let store = DiaryStore(context: container.mainContext)
            var mealDraft = IntakeDraft(type: .meal)
            mealDraft.displayName = "晚饭"
            let meal = try store.saveIntake(mealDraft)
            mealID = meal.id
            let draft = SymptomDraft()
            let standalone = try store.saveSymptom(draft)
            XCTAssertNil(standalone.linkedMeal)
            XCTAssertTrue(meal.linkedSymptoms.isEmpty)
            XCTAssertNil(meal.latestFeeling)

            var linked = draft
            linked.linkedMeal = meal
            linked.feeling = .bad
            try store.saveSymptom(linked)
            linked.symptomTime = linked.symptomTime.addingTimeInterval(600)
            linked.feeling = nil
            try store.saveSymptom(linked)
        }

        do {
            let container = try DiaryStore.makeContainer(at: url)
            let context = container.mainContext
            let store = DiaryStore(context: context)
            let meal = try XCTUnwrap(context.fetch(FetchDescriptor<IntakeEvent>()).first)
            XCTAssertEqual(meal.id, mealID)
            XCTAssertEqual(meal.linkedSymptoms.count, 2)
            XCTAssertEqual(meal.latestFeeling, .bad)
            let linked = try XCTUnwrap(meal.linkedSymptoms.first { $0.feeling == nil })
            XCTAssertEqual(linked.linkedMeal?.id, mealID)
            try store.deleteSymptom(linked)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<IntakeEvent>()), 1)
            try store.deleteIntake(meal)
        }

        let container = try DiaryStore.makeContainer(at: url)
        let remaining = try container.mainContext.fetch(FetchDescriptor<SymptomEvent>())
        XCTAssertEqual(remaining.count, 2)
        XCTAssertTrue(remaining.allSatisfy { $0.linkedMeal == nil })
        XCTAssertEqual(remaining.compactMap(\.feeling), [.bad])
    }

    @MainActor
    func testComboEditsAndDeletionLeaveMealSnapshotsAndSymptomLinkIntact() throws {
        let url = try temporaryStore()
        let originalID: UUID

        do {
            let container = try DiaryStore.makeContainer(at: url)
            let context = container.mainContext
            let store = DiaryStore(context: context)
            var draft = IntakeDraft(type: .meal)
            draft.mealType = .homemade
            draft.displayName = "菠菜面"
            var spinach = IngredientDraft()
            spinach.name = "菠菜"
            spinach.purchasePlaceName = "菜市场"
            spinach.amountText = "一把"
            spinach.note = "切段"
            var noodles = IngredientDraft()
            noodles.name = "面条"
            draft.ingredients = [spinach, noodles, IngredientDraft()]

            let meal = try store.saveIntake(draft)
            originalID = meal.id
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealCombo>()), 0)
            var symptom = SymptomDraft()
            symptom.linkedMeal = meal
            try store.saveSymptom(symptom)
            try store.saveCombo(name: draft.displayName, ingredients: draft.ingredients)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<SavedFood>()), 0)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<SavedPlace>()), 0)
        }

        do {
            let container = try DiaryStore.makeContainer(at: url)
            let context = container.mainContext
            let store = DiaryStore(context: context)
            let combo = try XCTUnwrap(context.fetch(FetchDescriptor<MealCombo>()).first)
            let original = try XCTUnwrap(context.fetch(FetchDescriptor<IntakeEvent>()).first)
            let originalIngredientIDs = Set(original.ingredients.map(\.id))
            var next = IntakeDraft(type: .meal)
            next.mealType = .homemade
            try next.applyCombo(combo)
            XCTAssertEqual(next.displayName, "菠菜面")
            XCTAssertEqual(next.ingredients.map(\.name), ["菠菜", "面条"])
            XCTAssertEqual(next.ingredients.map(\.purchasePlaceName), ["菜市场", ""])
            XCTAssertEqual(next.ingredients.map(\.amountText), ["一把", ""])
            XCTAssertEqual(next.ingredients.map(\.note), ["切段", ""])
            XCTAssertTrue(originalIngredientIDs.isDisjoint(with: next.ingredients.map(\.id)))
            next.ingredients[0].purchasePlaceName = "超市"
            next.ingredients.removeLast()
            let reused = try store.saveIntake(next)
            var templateRows = try combo.ingredientDrafts()
            XCTAssertEqual(templateRows.map(\.purchasePlaceName), ["菜市场", ""])

            templateRows[0].name = "生菜"
            try store.saveCombo(name: "生菜面", ingredients: templateRows, editing: combo)
            try next.applyCombo(combo)
            XCTAssertEqual(next.displayName, "生菜面")
            XCTAssertEqual(next.ingredients.map(\.name), ["生菜", "面条"])
            XCTAssertEqual(reused.displayName, "菠菜面")
            XCTAssertEqual(reused.orderedIngredients.map(\.name), ["菠菜"])
            try store.deleteCombo(combo)
        }

        let container = try DiaryStore.makeContainer(at: url)
        let context = container.mainContext
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealCombo>()), 0)
        let meals = try context.fetch(FetchDescriptor<IntakeEvent>())
        XCTAssertEqual(meals.count, 2)
        let original = try XCTUnwrap(meals.first { $0.id == originalID })
        XCTAssertEqual(original.displayName, "菠菜面")
        XCTAssertEqual(original.orderedIngredients.map(\.name), ["菠菜", "面条"])
        XCTAssertEqual(original.orderedIngredients.map(\.purchasePlaceName), ["菜市场", nil])
        let reused = try XCTUnwrap(meals.first { $0.id != originalID })
        XCTAssertEqual(reused.orderedIngredients.map(\.purchasePlaceName), ["超市"])
        let symptom = try XCTUnwrap(context.fetch(FetchDescriptor<SymptomEvent>()).first)
        XCTAssertEqual(symptom.linkedMeal?.id, originalID)
    }

    @MainActor
    func testOpeningPhaseTwoStorePreservesExistingData() throws {
        let url = try temporaryStore()
        let mealID: UUID
        do {
            let schema = Schema([PhaseTwo.IntakeEvent.self, PhaseTwo.IngredientItem.self, SavedPlace.self, SavedFood.self])
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            let meal = PhaseTwo.IntakeEvent(name: "菠菜面")
            mealID = meal.id
            let ingredient = PhaseTwo.IngredientItem()
            context.insert(meal)
            context.insert(ingredient)
            meal.ingredients = [ingredient]
            context.insert(SavedPlace(name: "菜市场", now: .now))
            context.insert(SavedFood(name: "菠菜", now: .now))
            try context.save()
        }

        let container = try DiaryStore.makeContainer(at: url)
        let context = container.mainContext
        let meal = try XCTUnwrap(context.fetch(FetchDescriptor<IntakeEvent>()).first)
        XCTAssertEqual(meal.id, mealID)
        XCTAssertEqual(meal.displayName, "菠菜面")
        XCTAssertEqual(meal.tags, ["晚饭"])
        XCTAssertEqual(meal.photoPath, "legacy.jpg")
        XCTAssertEqual(meal.orderedIngredients.first?.purchasePlaceName, "菜市场")
        XCTAssertTrue(meal.linkedSymptoms.isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<SavedPlace>()).first?.name, "菜市场")
        XCTAssertEqual(try context.fetch(FetchDescriptor<SavedFood>()).first?.name, "菠菜")
        let store = DiaryStore(context: context)
        var symptom = SymptomDraft()
        symptom.linkedMeal = meal
        try store.saveSymptom(symptom)
        XCTAssertEqual(meal.linkedSymptoms.count, 1)
        try store.saveCombo(name: "菠菜面", ingredients: [])
    }

    private func temporaryStore() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory.appending(path: "test.store")
    }
}

// Phase 2 schema fixture. Both favorites still use the unchanged app models.
private enum PhaseTwo {
    @Model
    final class IntakeEvent {
        @Attribute(.unique) var id: UUID
        var eventTime: Date
        var intakeTypeRaw: String
        var mealTypeRaw: String?
        var displayName: String
        var merchantName: String?
        var brandName: String?
        var amountText: String?
        var note: String?
        var photoPath: String?
        var tags: [String] = []
        var createdAt: Date
        var updatedAt: Date
        @Relationship(deleteRule: .cascade, inverse: \IngredientItem.intakeEvent)
        var ingredients: [IngredientItem] = []

        init(name: String) {
            id = UUID()
            eventTime = .now
            intakeTypeRaw = "meal"
            mealTypeRaw = "homemade"
            displayName = name
            photoPath = "legacy.jpg"
            tags = ["晚饭"]
            createdAt = eventTime
            updatedAt = eventTime
        }
    }

    @Model
    final class IngredientItem {
        @Attribute(.unique) var id: UUID
        var intakeEvent: IntakeEvent?
        var name: String
        var purchasePlaceName: String?
        var amountText: String?
        var note: String?
        var position: Int

        init() {
            id = UUID()
            name = "菠菜"
            purchasePlaceName = "菜市场"
            position = 0
        }
    }
}
