import Foundation
import SwiftData

struct ComboIngredient: Codable {
    let name: String
    let purchasePlaceName: String?
    let amountText: String?
    let note: String?

    init?(draft: IngredientDraft) {
        guard let name = DiaryName.text(draft.name) else { return nil }
        self.name = name
        purchasePlaceName = DiaryName.text(draft.purchasePlaceName)
        amountText = DiaryName.text(draft.amountText)
        note = DiaryName.text(draft.note)
    }

    var draft: IngredientDraft {
        var row = IngredientDraft()
        row.name = name
        row.purchasePlaceName = purchasePlaceName ?? ""
        row.amountText = amountText ?? ""
        row.note = note ?? ""
        return row
    }
}

@Model
final class MealCombo {
    @Attribute(.unique) var id: UUID
    var name: String
    var ingredientsData: Data
    var createdAt: Date
    var updatedAt: Date

    init(name: String, ingredientsData: Data, now: Date) {
        id = UUID()
        self.name = name
        self.ingredientsData = ingredientsData
        createdAt = now
        updatedAt = now
    }

    func ingredientDrafts() throws -> [IngredientDraft] {
        try JSONDecoder().decode([ComboIngredient].self, from: ingredientsData).map(\.draft)
    }

    var ingredientNames: [String] {
        (try? JSONDecoder().decode([ComboIngredient].self, from: ingredientsData))?.map(\.name) ?? []
    }
}
