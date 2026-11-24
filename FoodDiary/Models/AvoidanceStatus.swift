import Foundation
import SwiftData

enum AvoidanceKind: String {
    case food, ingredient, place, brand
}

enum AvoidanceChoice: String, CaseIterable, Identifiable {
    case watch, avoid, retried, dismissed

    var id: Self { self }
}

struct AvoidanceTarget: Identifiable, Hashable {
    let kind: AvoidanceKind
    let name: String

    var id: String { "\(kind.rawValue):\(DiaryName.normalized(name))" }
}

@Model
final class AvoidanceStatus {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var targetKey: String
    var kindCode: String
    var displayName: String
    var choiceCode: String
    var updatedAt: Date

    var target: AvoidanceTarget {
        AvoidanceTarget(kind: AvoidanceKind(rawValue: kindCode) ?? .food, name: displayName)
    }

    var choice: AvoidanceChoice? { AvoidanceChoice(rawValue: choiceCode) }

    init(target: AvoidanceTarget, choice: AvoidanceChoice, now: Date) {
        id = UUID()
        targetKey = target.id
        kindCode = target.kind.rawValue
        displayName = target.name
        choiceCode = choice.rawValue
        updatedAt = now
    }
}
