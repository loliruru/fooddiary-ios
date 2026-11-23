import Foundation
import SwiftData

enum SavedKind: String, Identifiable {
    case food, place

    var id: Self { self }
}

@Model
final class SavedPlace {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String?
    var note: String?
    var photoPath: String?
    var createdAt: Date
    var lastUsedAt: Date?

    init(name: String, now: Date) {
        id = UUID()
        self.name = name
        createdAt = now
    }
}

@Model
final class SavedFood {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String?
    var createdAt: Date
    var lastUsedAt: Date?

    init(name: String, now: Date) {
        id = UUID()
        self.name = name
        createdAt = now
    }
}

enum SavedName: Identifiable {
    case food(SavedFood)
    case place(SavedPlace)

    var id: UUID {
        switch self {
        case .food(let food): food.id
        case .place(let place): place.id
        }
    }

    var name: String {
        switch self {
        case .food(let food): food.name
        case .place(let place): place.name
        }
    }

    var category: String? {
        switch self {
        case .food(let food): food.category
        case .place(let place): place.category
        }
    }

    var lastUsedAt: Date? {
        switch self {
        case .food(let food): food.lastUsedAt
        case .place(let place): place.lastUsedAt
        }
    }

    var photoPath: String? {
        guard case .place(let place) = self else { return nil }
        return place.photoPath
    }

    static func sorted(_ names: [Self]) -> [Self] {
        names.sorted {
            let left = $0.lastUsedAt ?? .distantPast
            let right = $1.lastUsedAt ?? .distantPast
            if left != right { return left > right }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}
