import SwiftData
import XCTest
@testable import FoodDiary

final class PhaseFourMigrationTests: XCTestCase {
    @MainActor
    func testOpeningPhaseThreeStorePreservesSymptomsAndMealLinks() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Diary.store")
        let time = Date(timeIntervalSince1970: 1_800_000_000)
        let mealID: UUID
        let symptomID: UUID

        do {
            let schema = Schema([
                PhaseThree.IntakeEvent.self, PhaseThree.IngredientItem.self, PhaseThree.SymptomEvent.self,
                SavedPlace.self, SavedFood.self, MealCombo.self
            ])
            let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = container.mainContext
            let meal = PhaseThree.IntakeEvent(time: time)
            let symptom = PhaseThree.SymptomEvent(time: time.addingTimeInterval(3600))
            mealID = meal.id
            symptomID = symptom.id
            context.insert(meal)
            context.insert(symptom)
            meal.linkedSymptoms = [symptom]
            let ingredient = PhaseThree.IngredientItem()
            context.insert(ingredient)
            meal.ingredients = [ingredient]
            let ingredients = try JSONEncoder().encode([ComboIngredient]())
            context.insert(MealCombo(name: "菠菜面", ingredientsData: ingredients, now: time))
            try context.save()
        }

        let container = try DiaryStore.makeContainer(at: url)
        let context = container.mainContext
        let meal = try XCTUnwrap(context.fetch(FetchDescriptor<IntakeEvent>()).first)
        let symptom = try XCTUnwrap(context.fetch(FetchDescriptor<SymptomEvent>()).first)
        XCTAssertEqual(meal.id, mealID)
        XCTAssertEqual(meal.tags, ["晚饭"])
        XCTAssertEqual(meal.orderedIngredients.first?.purchasePlaceName, "菜市场")
        XCTAssertEqual(symptom.id, symptomID)
        XCTAssertEqual(symptom.linkedMeal?.id, mealID)
        XCTAssertEqual(symptom.feeling, .bad)
        XCTAssertEqual(symptom.recordedAt, time.addingTimeInterval(7200))
        XCTAssertEqual(symptom.symptoms, [.diarrhea])
        XCTAssertEqual(symptom.diarrheaCount, 2)
        XCTAssertTrue(symptom.exposureLinks.isEmpty)
        XCTAssertTrue(meal.exposureLinks.isEmpty)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<MealCombo>()), 1)

        try DiaryStore(context: context).saveExposureJudgment(.suspected, symptom: symptom, intake: meal)
        XCTAssertEqual(symptom.exposureLinks.first?.intakeEvent?.id, mealID)
    }
}

// Phase 3 persisted schema before the exposure relationships were added.
private enum PhaseThree {
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
        @Relationship(deleteRule: .nullify, inverse: \SymptomEvent.linkedMeal)
        var linkedSymptoms: [SymptomEvent] = []

        init(time: Date) {
            id = UUID()
            eventTime = time
            intakeTypeRaw = "meal"
            mealTypeRaw = "homemade"
            displayName = "菠菜面"
            tags = ["晚饭"]
            createdAt = time
            updatedAt = time
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

        init(time: Date) {
            id = UUID()
            symptomTime = time
            recordedAt = time.addingTimeInterval(3600)
            symptomCodes = ["diarrhea"]
            diarrheaCount = 2
            feelingCode = "bad"
        }
    }
}
