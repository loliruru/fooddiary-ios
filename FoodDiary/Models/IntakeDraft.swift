import Foundation

enum DiaryName {
    static func text(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalized(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    static func distinct(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            guard let name = text(value), seen.insert(normalized(name)).inserted else { return nil }
            return name
        }
    }
}

struct IngredientDraft: Equatable, Identifiable {
    let id: UUID
    var name: String
    var purchasePlaceName: String
    var amountText: String
    var note: String

    init(_ item: IngredientItem? = nil, copying: Bool = false) {
        id = copying ? UUID() : item?.id ?? UUID()
        name = item?.name ?? ""
        purchasePlaceName = item?.purchasePlaceName ?? ""
        amountText = item?.amountText ?? ""
        note = item?.note ?? ""
    }

    var isEmpty: Bool {
        [name, purchasePlaceName, amountText, note].allSatisfy { DiaryName.text($0) == nil }
    }

    var isValid: Bool { isEmpty || DiaryName.text(name) != nil }
}

struct IntakeDraft {
    let intakeType: IntakeType
    var mealType: MealType = .takeout
    var eventTime: Date
    var displayName = ""
    var merchantName = ""
    var brandName = ""
    var amountText = ""
    var note = ""
    var tags: [String] = []
    var ingredients: [IngredientDraft] = []
    var photo: PhotoChange = .keep

    init(type: IntakeType, now: Date = .now) {
        intakeType = type
        eventTime = now
    }

    init(event: IntakeEvent, copying: Bool = false, now: Date = .now) {
        intakeType = event.intakeType
        mealType = event.mealType ?? .takeout
        eventTime = copying ? now : event.eventTime
        displayName = event.displayName
        merchantName = event.merchantName ?? ""
        brandName = event.brandName ?? ""
        amountText = event.amountText ?? ""
        note = event.note ?? ""
        tags = event.tags
        ingredients = event.orderedIngredients.map { IngredientDraft($0, copying: copying) }
        if copying, let path = event.photoPath {
            photo = .copy(path)
        }
    }

    var isHomemade: Bool { intakeType == .meal && mealType == .homemade }

    var canSave: Bool {
        DiaryName.text(displayName) != nil && (!isHomemade || ingredients.allSatisfy(\.isValid))
    }

    mutating func applyCombo(_ combo: MealCombo) throws {
        let rows = try combo.ingredientDrafts()
        displayName = combo.name
        ingredients = rows
    }
}
