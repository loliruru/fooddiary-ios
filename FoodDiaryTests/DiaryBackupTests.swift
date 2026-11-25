import SwiftData
import XCTest
@testable import FoodDiary

final class DiaryBackupTests: XCTestCase {
    private let exportedAt = Date(timeIntervalSince1970: 1_800_000_000.125)
    private let timeZone = TimeZone(identifier: "Asia/Singapore")!
    private let specialText = "中文, \"有引号\"\n下一行"

    @MainActor
    func testJSONRoundTripReplacesCurrentRecordsAndKeepsIndependentHistory() throws {
        let directory = try temporaryDirectory()
        let location = directory.appending(path: "restored.store")
        let photos = DiaryPhotos(directory: directory.appending(path: "RestoredPhotos", directoryHint: .isDirectory))
        let source = try makeFixture(in: directory)
        let backup = try source.backup(now: exportedAt, timeZone: timeZone)
        let export = try DiaryExportFile(backup: backup, format: .json, timeZone: timeZone)
        defer { export.remove() }
        let decoded = try DiaryBackup.readJSON(from: export.url)
        XCTAssertEqual(decoded.exportedAt, exportedAt)
        XCTAssertEqual(decoded.timeZone, timeZone.identifier)

        try autoreleasepool {
            let container = try DiaryStore.makeContainer(at: location)
            let store = DiaryStore(context: container.mainContext, photos: photos)
            try store.restore(decoded)
            XCTAssertEqual(try store.backup(now: exportedAt, timeZone: timeZone).json(), try backup.json())

            let meal = try XCTUnwrap(store.context.fetch(FetchDescriptor<IntakeEvent>()).first { $0.intakeType == .meal })
            var changed = IntakeDraft(event: meal)
            changed.displayName = "后改的餐名"
            changed.ingredients = []
            try store.saveIntake(changed, editing: meal)
            var extra = IntakeDraft(type: .snack)
            extra.displayName = "备份之后新增"
            extra.photo = .replace(try XCTUnwrap(decoded.intakes.first { $0.intakeType == "snack" }?.photoJPEG))
            let extraEvent = try store.saveIntake(extra)
            let extraPath = try XCTUnwrap(extraEvent.photoPath)
            let oldAvatar = try XCTUnwrap(store.context.fetch(FetchDescriptor<SavedPlace>()).first?.photoPath)

            try store.restore(decoded)
            XCTAssertNil(photos.data(for: extraPath))
            XCTAssertNil(photos.data(for: oldAvatar))
        }

        let reopened = try DiaryStore.makeContainer(at: location)
        let store = DiaryStore(context: reopened.mainContext, photos: photos)
        XCTAssertEqual(try store.backup(now: exportedAt, timeZone: timeZone).json(), try backup.json())
        let places = try store.context.fetch(FetchDescriptor<SavedPlace>())
        let foods = try store.context.fetch(FetchDescriptor<SavedFood>())
        let combos = try store.context.fetch(FetchDescriptor<MealCombo>())
        for place in places { try store.deleteFavorite(.place(place)) }
        for food in foods { try store.deleteFavorite(.food(food)) }
        for combo in combos { try store.deleteCombo(combo) }

        let withoutTemplates = try store.backup(now: exportedAt, timeZone: timeZone)
        XCTAssertEqual(withoutTemplates.templateCount, 0)
        XCTAssertEqual(withoutTemplates.intakes.flatMap(\.ingredients).map(\.purchasePlaceName), ["菜市场", "超市", nil])
        XCTAssertEqual(withoutTemplates.symptoms.map(\.linkedMealID), decoded.symptoms.map(\.linkedMealID))
        XCTAssertEqual(withoutTemplates.exposureLinks.map(\.id), decoded.exposureLinks.map(\.id))
        XCTAssertEqual(withoutTemplates.exposureLinks.map(\.judgment), ["suspected", "unsure"])

        try store.restore(DiaryBackup.readJSON(withoutTemplates.json()))
        let remaining = try store.backup()
        XCTAssertEqual(remaining.recordCount, 4)
        XCTAssertEqual(remaining.templateCount, 0)
        XCTAssertEqual(remaining.exposureLinks.count, 2)
    }

    @MainActor
    func testCSVIncludesEveryRecordTypeAndEscapesTextAndLocalTime() throws {
        let store = try makeFixture(in: temporaryDirectory())
        let backup = try store.backup(includingPhotos: false, now: exportedAt, timeZone: timeZone)
        let export = try DiaryExportFile(backup: backup, format: .csv, timeZone: timeZone)
        defer { export.remove() }
        let contents = String(decoding: try Data(contentsOf: export.url), as: UTF8.self)
        XCTAssertTrue(contents.hasPrefix("\u{FEFF}recordType,id,intakeID,symptomID,comboID,linkedMealID,position,"))
        XCTAssertEqual(DiaryBackup.csvField(specialText), "\"中文, \"\"有引号\"\"\n下一行\"")
        XCTAssertEqual(DiaryBackup.csvField("第一行\r\n第二行"), "\"第一行\r\n第二行\"")
        XCTAssertTrue(contents.contains(DiaryBackup.csvField(specialText)))
        for type in ["intake", "ingredient", "symptom", "exposure", "savedPlace", "savedFood",
                     "mealCombo", "comboIngredient", "avoidanceStatus"] {
            XCTAssertTrue(contents.contains("\r\n\(type),"), type)
        }
        for field in ["homemade", "snack", "菜市场", "超市", "suspected", "unsure", "retried", ".125+08:00"] {
            XCTAssertTrue(contents.contains(field), field)
        }
        let link = try XCTUnwrap(backup.exposureLinks.first)
        XCTAssertTrue(contents.contains("exposure,\(link.id),\(link.intakeID),\(link.symptomID),"))
        let meal = try XCTUnwrap(backup.intakes.first)
        let ingredient = try XCTUnwrap(meal.ingredients.first)
        XCTAssertTrue(contents.contains("ingredient,\(ingredient.id),\(meal.id),,,,0,"))
        XCTAssertNil(backup.intakes.last?.photoJPEG)
        XCTAssertNil(backup.savedPlaces.first?.photoJPEG)
    }

    @MainActor
    func testRejectsMalformedBackupAndRollsBackWhenPhotoWriteFails() throws {
        let directory = try temporaryDirectory()
        let source = try makeFixture(in: directory)
        let backup = try source.backup()
        let data = try backup.json()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["formatVersion"] = 2
        XCTAssertThrowsError(try DiaryBackup.readJSON(JSONSerialization.data(withJSONObject: object))) {
            XCTAssertEqual($0 as? DiaryBackup.FormatError, .unsupportedVersion)
        }
        object["formatVersion"] = 1
        var links = try XCTUnwrap(object["exposureLinks"] as? [[String: Any]])
        links[0]["intakeID"] = UUID().uuidString
        object["exposureLinks"] = links
        XCTAssertThrowsError(try DiaryBackup.readJSON(JSONSerialization.data(withJSONObject: object))) {
            XCTAssertEqual($0 as? DiaryBackup.FormatError, .invalidData)
        }

        let meal = try XCTUnwrap(source.context.fetch(FetchDescriptor<IntakeEvent>()).first { $0.intakeType == .meal })
        var edit = IntakeDraft(event: meal)
        edit.displayName = "备份后的编辑"
        try source.saveIntake(edit, editing: meal)
        let before = try source.backup(now: exportedAt, timeZone: timeZone).json()
        let blockedDirectory = directory.appending(path: "NotADirectory")
        try Data([0]).write(to: blockedDirectory)
        let brokenStore = DiaryStore(context: source.context, photos: DiaryPhotos(directory: blockedDirectory))
        XCTAssertThrowsError(try brokenStore.restore(backup))
        XCTAssertEqual(try source.backup(now: exportedAt, timeZone: timeZone).json(), before)
    }

    @MainActor
    func testClearAllRemovesEveryRecordAndEveryPhoto() throws {
        let directory = try temporaryDirectory()
        let store = try makeFixture(in: directory)
        let snack = try XCTUnwrap(store.context.fetch(FetchDescriptor<IntakeEvent>()).first { $0.intakeType == .snack })
        let image = try XCTUnwrap(snack.photoPath.flatMap(store.photos.data(for:)))
        _ = try store.photos.prepare(.replace(image), previous: nil)
        try store.clearAll()
        let backup = try store.backup()
        XCTAssertEqual(backup.recordCount, 0)
        XCTAssertEqual(backup.templateCount, 0)
        XCTAssertTrue(backup.exposureLinks.isEmpty)
        XCTAssertTrue(backup.avoidanceStatuses.isEmpty)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<IngredientItem>()), 0)
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: store.photos.directory.path).isEmpty)
    }

    @MainActor
    private func makeFixture(in directory: URL) throws -> DiaryStore {
        let container = try DiaryStore.makeContainer(at: directory.appending(path: "Source.store"))
        let photos = DiaryPhotos(directory: directory.appending(path: "SourcePhotos", directoryHint: .isDirectory))
        let store = DiaryStore(context: container.mainContext, photos: photos)
        let png = try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAAD0lEQVR4nGP4z8DA8J8BAAf/Af8Bf4mnAAAAAElFTkSuQmCC"))
        let jpeg = try DiaryPhotos.jpeg(from: png)
        let mealTime = exportedAt.addingTimeInterval(-11 * 3600)
        let snackTime = exportedAt.addingTimeInterval(-9.5 * 3600)
        let symptomTime = exportedAt.addingTimeInterval(-300)
        try store.saveFavorite(.place, name: "菜市场", category: "采购", note: specialText, photo: .replace(jpeg), now: mealTime)
        try store.saveFavorite(.food, name: "卤鸡腿", category: "夜宵", now: mealTime)

        var meal = IntakeDraft(type: .meal, now: mealTime)
        meal.mealType = .homemade
        meal.displayName = "菠菜面"
        meal.note = specialText
        meal.ingredients = [ingredient("菠菜", source: "菜市场"), ingredient("面条", source: "超市"), ingredient("鸡蛋")]
        let originalMeal = try store.saveIntake(meal, now: mealTime)
        try store.saveCombo(name: "周末面食", ingredients: meal.ingredients, now: mealTime)

        var snack = IntakeDraft(type: .snack, now: snackTime)
        snack.displayName = "卤鸡腿"
        snack.merchantName = "便利店"
        snack.brandName = "示例牌"
        snack.amountText = "半包"
        snack.tags = ["辣,微辣", "夜宵"]
        snack.photo = .replace(jpeg)
        let originalSnack = try store.saveIntake(snack, now: snackTime)

        var body = SymptomDraft(now: symptomTime)
        body.feeling = .bad
        body.symptoms = [.abdominalPain, .diarrhea]
        body.diarrheaCount = 2
        body.severity = .mild
        body.duration = .oneToThree
        body.note = specialText
        body.linkedMeal = originalMeal
        let event = try store.saveSymptom(body, now: exportedAt)
        try store.saveSymptom(SymptomDraft(now: exportedAt), now: exportedAt)
        try store.saveExposureJudgment(.suspected, symptom: event, intake: originalSnack, now: symptomTime)
        try store.saveExposureJudgment(.unsure, symptom: event, intake: originalMeal, now: exportedAt)
        try store.saveAvoidanceChoice(.retried, for: AvoidanceTarget(kind: .ingredient, name: "菠菜"), now: exportedAt)
        return store
    }

    private func ingredient(_ name: String, source: String = "") -> IngredientDraft {
        var draft = IngredientDraft()
        draft.name = name
        draft.purchasePlaceName = source
        draft.amountText = "适量"
        return draft
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory
    }
}
