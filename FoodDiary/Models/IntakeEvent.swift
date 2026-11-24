import Foundation
import SwiftData

enum IntakeType: String, Identifiable {
    case meal, snack

    var id: Self { self }
}

enum MealType: String, CaseIterable, Identifiable {
    case takeout, dineIn, homemade

    var id: Self { self }
}

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
    @Relationship(deleteRule: .cascade, inverse: \SymptomExposureLink.intakeEvent)
    var exposureLinks: [SymptomExposureLink] = []

    var intakeType: IntakeType { IntakeType(rawValue: intakeTypeRaw) ?? .meal }
    var mealType: MealType? { mealTypeRaw.flatMap(MealType.init(rawValue:)) }
    var orderedIngredients: [IngredientItem] { ingredients.sorted { $0.position < $1.position } }
    var latestFeeling: BodyFeeling? {
        linkedSymptoms.sorted { $0.symptomTime > $1.symptomTime }.compactMap(\.feeling).first
    }

    init(intakeType: IntakeType, eventTime: Date, displayName: String, now: Date) {
        id = UUID()
        intakeTypeRaw = intakeType.rawValue
        self.eventTime = eventTime
        self.displayName = displayName
        createdAt = now
        updatedAt = now
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

    init(id: UUID, name: String, position: Int) {
        self.id = id
        self.name = name
        self.position = position
    }
}
