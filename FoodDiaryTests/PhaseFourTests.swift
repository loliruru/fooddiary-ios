import SwiftData
import XCTest
@testable import FoodDiary

final class PhaseFourTests: XCTestCase {
    func testCrossDayWindowUsesElapsedTimeAndStrictlyPrecedesSymptoms() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let symptomTime = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 8))!
        let snackTime = calendar.date(from: DateComponents(year: 2026, month: 11, day: 22, hour: 22, minute: 30))!
        let boundary = ExposureReview.windowStart(for: symptomTime)

        XCTAssertTrue(ExposureReview.contains(snackTime, before: symptomTime))
        XCTAssertEqual(ExposureReview.hoursBefore(symptomTime, intakeTime: snackTime), 9.5)
        XCTAssertEqual(symptomTime.timeIntervalSince(boundary), 48 * 3600)
        XCTAssertTrue(ExposureReview.contains(boundary, before: symptomTime))
        XCTAssertFalse(ExposureReview.contains(boundary.addingTimeInterval(-1), before: symptomTime))
        XCTAssertFalse(ExposureReview.contains(symptomTime, before: symptomTime))
        XCTAssertFalse(ExposureReview.contains(symptomTime.addingTimeInterval(1), before: symptomTime))
    }

    @MainActor
    func testMultipleJudgmentsPersistChangeAndCascadeIndependently() throws {
        let url = try temporaryStore()
        let begin = Date(timeIntervalSince1970: 1_800_000_000)
        let recordedAt = begin.addingTimeInterval(9 * 3600)
        let symptomID: UUID

        do {
            let container = try DiaryStore.makeContainer(at: url)
            let context = container.mainContext
            let store = DiaryStore(context: context)
            let snack = try addIntake("卤鸡腿", type: .snack, at: begin.addingTimeInterval(-9.5 * 3600), store: store)
            let meal = try addIntake("菠菜面", at: begin.addingTimeInterval(-12 * 3600), store: store)
            let older = try addIntake("更早的餐", at: begin.addingTimeInterval(-49 * 3600), store: store)
            let body = try store.saveSymptom(SymptomDraft(now: begin), now: recordedAt)
            let candidates = FetchDescriptor(
                predicate: ExposureReview.predicate(before: body.symptomTime),
                sortBy: [SortDescriptor(\IntakeEvent.eventTime, order: .reverse)]
            )
            XCTAssertEqual(try context.fetch(candidates).map(\.id), [snack.id, meal.id])
            symptomID = body.id
            XCTAssertTrue(body.exposureLinks.isEmpty)
            XCTAssertNil(body.linkedMeal)
            XCTAssertThrowsError(try store.saveExposureJudgment(.suspected, symptom: body, intake: older))
            try store.saveExposureJudgment(.unreviewed, symptom: body, intake: snack)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<SymptomExposureLink>()), 0)

            try store.saveExposureJudgment(.suspected, symptom: body, intake: snack)
            try store.saveExposureJudgment(.suspected, symptom: body, intake: meal)
            XCTAssertEqual(body.exposureLinks.filter { $0.judgment == .suspected }.count, 2)
            try store.saveExposureJudgment(.unsure, symptom: body, intake: meal)
            XCTAssertEqual(body.exposureLinks.count, 2)
            let other = try store.saveSymptom(SymptomDraft(now: begin), now: recordedAt)
            try store.saveExposureJudgment(.notRelated, symptom: other, intake: meal)
        }

        let container = try DiaryStore.makeContainer(at: url)
        let context = container.mainContext
        let store = DiaryStore(context: context)
        let bodies = try context.fetch(FetchDescriptor<SymptomEvent>())
        let body = try XCTUnwrap(bodies.first { $0.id == symptomID })
        XCTAssertEqual(body.recordedAt, recordedAt)
        XCTAssertEqual(body.symptomTime, begin)
        let snackLink = try XCTUnwrap(body.exposureLinks.first { $0.judgment == .suspected })
        let snack = try XCTUnwrap(snackLink.intakeEvent)
        let linkID = snackLink.id
        XCTAssertEqual(snack.displayName, "卤鸡腿")
        XCTAssertEqual(snack.exposureLinks.first?.symptomEvent?.id, body.id)
        XCTAssertEqual(body.exposureLinks.first { $0.intakeEvent?.displayName == "菠菜面" }?.judgment, .unsure)
        try store.saveExposureJudgment(.unreviewed, symptom: body, intake: snack)
        XCTAssertEqual(snack.exposureLinks.first?.judgment, .unreviewed)
        XCTAssertEqual(snack.exposureLinks.first?.id, linkID)

        try store.deleteIntake(snack)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SymptomExposureLink>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SymptomEvent>()), 2)
        try store.deleteSymptom(body)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IntakeEvent>()), 2)
        let remaining = try context.fetch(FetchDescriptor<SymptomExposureLink>())
        XCTAssertEqual(remaining.map(\.judgment), [.notRelated])
        XCTAssertEqual(remaining.first?.intakeEvent?.displayName, "菠菜面")
    }

    @MainActor
    func testAvoidanceCountsDistinctIntakesAndExplicitJudgmentsAndKeepsScopedStatus() throws {
        let url = try temporaryStore()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let container = try DiaryStore.makeContainer(at: url)
        let context = container.mainContext
        let store = DiaryStore(context: context)

        var draft = IntakeDraft(type: .meal, now: base)
        draft.mealType = .homemade
        draft.displayName = "Spinach"
        var spinach = IngredientDraft()
        spinach.name = "SPINACH"
        spinach.purchasePlaceName = " Spinach "
        var repeated = IngredientDraft()
        repeated.name = "ｓｐｉｎａｃｈ"
        repeated.purchasePlaceName = "SPINACH"
        draft.ingredients = [spinach, repeated]
        let meal = try store.saveIntake(draft)
        draft.displayName = "spinach"
        draft.eventTime = base.addingTimeInterval(3600)
        draft.ingredients = []
        let earlierMeal = try store.saveIntake(draft)
        var snackDraft = IntakeDraft(type: .snack, now: base.addingTimeInterval(7200))
        snackDraft.displayName = "Ｓｐｉｎａｃｈ"
        snackDraft.brandName = " Box "
        snackDraft.merchantName = "BOX"
        let snack = try store.saveIntake(snackDraft)
        let otherSnack = try addIntake("零食", type: .snack, at: base, store: store)

        var symptom = SymptomDraft(now: base.addingTimeInterval(4 * 3600))
        symptom.symptoms = [.diarrhea]
        symptom.diarrheaCount = 2
        symptom.feeling = .bad
        symptom.linkedMeal = earlierMeal
        let bad = try store.saveSymptom(symptom)
        try store.saveExposureJudgment(.suspected, symptom: bad, intake: meal)
        try store.saveExposureJudgment(.notRelated, symptom: bad, intake: earlierMeal)

        symptom.linkedMeal = nil
        symptom.feeling = nil
        let unknown = try store.saveSymptom(symptom)
        try store.saveExposureJudgment(.suspected, symptom: unknown, intake: meal)
        try store.saveExposureJudgment(.suspected, symptom: unknown, intake: otherSnack)

        symptom.feeling = .bad
        symptom.symptoms = []
        let withoutSymptoms = try store.saveSymptom(symptom)
        try store.saveExposureJudgment(.suspected, symptom: withoutSymptoms, intake: meal)

        func statistics() throws -> [String: AvoidanceSummary] {
            let summaries = try AvoidanceStatistics.summarize(
                intakes: context.fetch(FetchDescriptor<IntakeEvent>()),
                symptoms: context.fetch(FetchDescriptor<SymptomEvent>()),
                links: context.fetch(FetchDescriptor<SymptomExposureLink>()),
                statuses: context.fetch(FetchDescriptor<AvoidanceStatus>())
            )
            return Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
        }

        var summaries = try statistics()
        let food = try XCTUnwrap(summaries["food:spinach"])
        XCTAssertEqual(food.intakes.map(\.id), [snack.id, earlierMeal.id, meal.id])
        XCTAssertEqual(food.intakes.first?.suspectedBy.count, 0)
        XCTAssertEqual(food.evidenceCount, 1)
        XCTAssertEqual(food.suspectedCount, 3)
        XCTAssertEqual(food.latestEvidence, bad.symptomTime)
        XCTAssertEqual(food.symptoms, [.diarrhea])
        XCTAssertEqual(summaries["ingredient:spinach"]?.intakes.count, 1)
        XCTAssertEqual(summaries["place:spinach"]?.intakes.count, 1)
        XCTAssertEqual(summaries["brand:box"]?.target.name, "Box")
        XCTAssertEqual(summaries["place:box"]?.target.name, "BOX")
        XCTAssertEqual(summaries["food:零食"]?.evidenceCount, 0)
        XCTAssertEqual(summaries["food:零食"]?.suspectedCount, 1)

        try store.saveExposureJudgment(.unreviewed, symptom: bad, intake: earlierMeal)
        summaries = try statistics()
        XCTAssertEqual(summaries["food:spinach"]?.evidenceCount, 2)
        XCTAssertEqual(summaries["food:spinach"]?.suspectedCount, 3)

        let ingredient = try XCTUnwrap(summaries["ingredient:spinach"])
        try store.saveAvoidanceChoice(.avoid, for: ingredient.target)
        try store.saveAvoidanceChoice(.retried, for: ingredient.target)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<AvoidanceStatus>()), 1)
        summaries = try statistics()
        XCTAssertEqual(summaries["ingredient:spinach"]?.choice, .retried)
        XCTAssertNil(summaries["food:spinach"]?.choice)
        XCTAssertNil(summaries["place:spinach"]?.choice)

        var changedTime = SymptomDraft(event: bad)
        changedTime.symptomTime = base.addingTimeInterval(60 * 3600)
        try store.saveSymptom(changedTime, editing: bad)
        XCTAssertEqual(try statistics()["ingredient:spinach"]?.evidenceCount, 0)
        XCTAssertEqual(try statistics()["ingredient:spinach"]?.suspectedCount, 2)

        try store.deleteIntake(meal)
        let reopened = try DiaryStore.makeContainer(at: url)
        let status = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<AvoidanceStatus>()).first)
        XCTAssertEqual(status.choice, .retried)
        XCTAssertEqual(try statistics()["ingredient:spinach"]?.intakes.count, 0)
        try store.saveAvoidanceChoice(nil, for: ingredient.target)
        XCTAssertNil(try statistics()["ingredient:spinach"])
    }

    @MainActor
    func testTimelineFiltersCombineSearchKindFeelingSymptomAndLocalDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23))!
        let time = midnight.addingTimeInterval(-3600)
        let meal = IntakeEvent(intakeType: .meal, eventTime: time, displayName: "牛肉面", now: time)
        meal.mealTypeRaw = MealType.homemade.rawValue
        let ingredient = IngredientItem(id: UUID(), name: "牛肉", position: 0)
        ingredient.purchasePlaceName = " Ｋ  MARKET "
        meal.ingredients = [ingredient]
        let snack = IntakeEvent(intakeType: .snack, eventTime: midnight, displayName: "牛肉干", now: midnight)
        let body = SymptomEvent(symptomTime: midnight, recordedAt: midnight.addingTimeInterval(50 * 3600))
        body.feelingCode = BodyFeeling.bad.rawValue
        body.symptomCodes = [Symptom.diarrhea.rawValue]
        body.linkedMeal = meal
        meal.linkedSymptoms = [body]
        let entries = TimelineEntry.ordered(intakes: [meal, snack], symptoms: [body])

        var filter = TimelineFilter(kind: .homemade, feeling: .bad, symptom: .diarrhea, days: time...time)
        XCTAssertEqual(filter.apply(to: entries, searching: " k  market\n", calendar: calendar).map(\.id), [meal.id])
        XCTAssertTrue(filter.apply(to: entries, searching: "其他店", calendar: calendar).isEmpty)
        filter.kind = .takeout
        XCTAssertTrue(filter.apply(to: entries, searching: "", calendar: calendar).isEmpty)
        filter.kind = .symptoms
        filter.days = midnight...midnight
        XCTAssertEqual(filter.apply(to: entries, searching: "", calendar: calendar).map(\.id), [body.id])
        filter = TimelineFilter(kind: .snacks, feeling: .unknown, days: midnight...midnight)
        XCTAssertEqual(filter.apply(to: entries, searching: "牛肉", calendar: calendar).map(\.id), [snack.id])
        filter.feeling = .good
        XCTAssertTrue(filter.apply(to: entries, searching: "", calendar: calendar).isEmpty)
    }

    @MainActor
    private func addIntake(_ name: String, type: IntakeType = .meal, at date: Date, store: DiaryStore) throws -> IntakeEvent {
        var draft = IntakeDraft(type: type, now: date)
        draft.displayName = name
        return try store.saveIntake(draft)
    }

    private func temporaryStore() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory.appending(path: "test.store")
    }
}
