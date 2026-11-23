import SwiftUI

extension IntakeType {
    var addTitle: LocalizedStringKey {
        switch self {
        case .meal: "home.action.meal"
        case .snack: "home.action.snack"
        }
    }

    var symbol: String {
        switch self {
        case .meal: "fork.knife"
        case .snack: "takeoutbag.and.cup.and.straw"
        }
    }

    var repeatTitle: LocalizedStringKey {
        switch self {
        case .meal: "intake.repeatMeal"
        case .snack: "intake.repeatSnack"
        }
    }
}

extension MealType {
    var title: LocalizedStringKey {
        switch self {
        case .takeout: "intake.takeout"
        case .dineIn: "intake.dineIn"
        case .homemade: "intake.homemade"
        }
    }

    var symbol: String {
        switch self {
        case .takeout: "bag"
        case .dineIn: "fork.knife"
        case .homemade: "frying.pan"
        }
    }
}

extension IntakeEvent {
    var kindTitle: LocalizedStringKey {
        intakeType == .snack ? "intake.snack" : mealType?.title ?? "intake.meal"
    }
}

extension SavedKind {
    var title: LocalizedStringKey {
        switch self {
        case .food: "favorites.food"
        case .place: "favorites.place"
        }
    }

    var addTitle: LocalizedStringKey {
        switch self {
        case .food: "favorites.addFood"
        case .place: "favorites.addPlace"
        }
    }

    var symbol: String {
        switch self {
        case .food: "fork.knife"
        case .place: "storefront"
        }
    }
}
