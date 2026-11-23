import SwiftData
import XCTest
@testable import FoodDiary

final class DiaryStoreTests: XCTestCase {
    @MainActor
    func testHomemadeMealPersistsInOrderAndCascadesOnDelete() throws {
        let directory = try temporaryDirectory()
        let location = directory.appending(path: "test.store")
        let time = Date(timeIntervalSince1970: 1_700_000_000)
        let id = try autoreleasepool {
            let container = try DiaryStore.makeContainer(at: location)
            let store = DiaryStore(context: container.mainContext)
            var draft = IntakeDraft(type: .meal, now: time)
            draft.mealType = .homemade
            draft.displayName = "菠菜鸡蛋面"
            draft.tags = ["生鲜", "晚餐", " 生鲜 ", "份量,适中"]
            draft.note = "记录一\n行"
            draft.ingredients = [
                ingredient("菠菜", place: "叮咚买菜", amount: "一把", note: "洗净"),
                ingredient("面条", place: "超市"),
                ingredient("水饺", place: "超市"),
                ingredient("鸡蛋")
            ]
            let event = try store.saveIntake(draft)
            return event.id
        }

        let reopened = try DiaryStore.makeContainer(at: location)
        let store = DiaryStore(context: reopened.mainContext)
        let event = try XCTUnwrap(reopened.mainContext.fetch(FetchDescriptor<IntakeEvent>()).first)
        XCTAssertEqual(event.id, id)
        XCTAssertEqual(event.mealType, .homemade)
        XCTAssertEqual(event.eventTime, time)
        XCTAssertEqual(event.tags, ["生鲜", "晚餐", "份量,适中"])
        XCTAssertEqual(event.note, "记录一\n行")
        XCTAssertEqual(event.orderedIngredients.map(\.name), ["菠菜", "面条", "水饺", "鸡蛋"])
        XCTAssertEqual(event.orderedIngredients.map(\.purchasePlaceName), ["叮咚买菜", "超市", "超市", nil])
        XCTAssertEqual(event.orderedIngredients.first?.amountText, "一把")
        XCTAssertEqual(event.orderedIngredients.first?.note, "洗净")
        XCTAssertTrue(event.ingredients.allSatisfy { $0.intakeEvent?.id == id })

        let firstID = try XCTUnwrap(event.orderedIngredients.first?.id)
        var edited = IntakeDraft(event: event)
        edited.ingredients.remove(at: 1)
        edited.ingredients[0].purchasePlaceName = ""
        try store.saveIntake(edited, editing: event)
        let verifyingContext = ModelContext(reopened)
        let updated = try XCTUnwrap(verifyingContext.fetch(FetchDescriptor<IntakeEvent>()).first)
        XCTAssertEqual(updated.orderedIngredients.first?.id, firstID)
        XCTAssertEqual(updated.orderedIngredients.map(\.purchasePlaceName), [nil, "超市", nil])
        XCTAssertEqual(try verifyingContext.fetchCount(FetchDescriptor<IngredientItem>()), 3)

        try store.deleteIntake(event)
        let afterDeletion = ModelContext(reopened)
        XCTAssertEqual(try afterDeletion.fetchCount(FetchDescriptor<IntakeEvent>()), 0)
        XCTAssertEqual(try afterDeletion.fetchCount(FetchDescriptor<IngredientItem>()), 0)
    }

    @MainActor
    func testFavoritesRequireSeparateActionsAndNeverRewriteHistory() throws {
        let container = try DiaryStore.makeContainer(at: temporaryDirectory().appending(path: "test.store"))
        let context = container.mainContext
        let store = DiaryStore(context: context)
        var takeout = IntakeDraft(type: .meal)
        takeout.displayName = "卤鸡腿"
        takeout.merchantName = "老乡鸡"
        try store.saveIntake(takeout)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SavedPlace>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SavedFood>()), 0)

        try store.saveFavorite(.place, name: "灶美味")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SavedPlace>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SavedFood>()), 0)
        try store.saveFavorite(.food, name: "卤鸡腿")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SavedPlace>()), 1)
        let place = try XCTUnwrap(context.fetch(FetchDescriptor<SavedPlace>()).first)
        let food = try XCTUnwrap(context.fetch(FetchDescriptor<SavedFood>()).first)

        let usedAt = Date()
        takeout.mealType = .dineIn
        takeout.merchantName = place.name
        let event = try store.saveIntake(takeout, now: usedAt)
        XCTAssertEqual(place.lastUsedAt, usedAt)
        XCTAssertEqual(food.lastUsedAt, usedAt)
        try store.saveFavorite(.place, name: "灶美味分店", editing: .place(place))
        try store.saveFavorite(.food, name: "鸡腿饭", editing: .food(food))
        try store.deleteFavorite(.place(place))
        try store.deleteFavorite(.food(food))

        let verification = ModelContext(container)
        let records = try verification.fetch(FetchDescriptor<IntakeEvent>())
        let savedEvent = try XCTUnwrap(records.first { $0.id == event.id })
        XCTAssertEqual(savedEvent.merchantName, "灶美味")
        XCTAssertEqual(savedEvent.displayName, "卤鸡腿")
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(try verification.fetchCount(FetchDescriptor<SavedPlace>()), 0)
        XCTAssertEqual(try verification.fetchCount(FetchDescriptor<SavedFood>()), 0)
    }

    @MainActor
    func testRepeatSnackCopiesFieldsAndOwnsSeparatePhoto() throws {
        let directory = try temporaryDirectory()
        let container = try DiaryStore.makeContainer(at: directory.appending(path: "test.store"))
        let photos = DiaryPhotos(directory: directory.appending(path: "Photos", directoryHint: .isDirectory))
        let store = DiaryStore(context: container.mainContext, photos: photos)
        let image = try DiaryPhotos.jpeg(from: fixturePNG())
        let yesterday = Date(timeIntervalSince1970: 1_700_000_000)
        let now = yesterday.addingTimeInterval(9.5 * 3600)

        var snack = IntakeDraft(type: .snack, now: yesterday)
        snack.displayName = "卤鸡腿"
        snack.merchantName = "便利店"
        snack.brandName = "示例品牌"
        snack.amountText = "半包"
        snack.tags = ["夜宵"]
        snack.note = "饭后"
        snack.photo = .replace(image)
        let original = try store.saveIntake(snack)
        let originalPath = try XCTUnwrap(original.photoPath)
        let copy = try store.saveIntake(IntakeDraft(event: original, copying: true, now: now))
        let copyPath = try XCTUnwrap(copy.photoPath)
        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertNotEqual(copyPath, originalPath)
        XCTAssertEqual(photos.data(for: copyPath), image)
        XCTAssertEqual(original.eventTime, yesterday)
        XCTAssertEqual(copy.eventTime, now)
        XCTAssertEqual(copy.intakeType, .snack)
        XCTAssertNil(copy.mealType)
        XCTAssertEqual(copy.merchantName, "便利店")
        XCTAssertEqual(copy.brandName, "示例品牌")
        XCTAssertEqual(copy.amountText, "半包")
        XCTAssertEqual(copy.tags, ["夜宵"])
        XCTAssertEqual(copy.note, "饭后")

        var edit = IntakeDraft(event: copy)
        edit.photo = .replace(image)
        try store.saveIntake(edit, editing: copy)
        let replacement = try XCTUnwrap(copy.photoPath)
        XCTAssertNotEqual(replacement, copyPath)
        XCTAssertNil(photos.data(for: copyPath))
        XCTAssertEqual(photos.data(for: replacement), image)

        edit.photo = .remove
        try store.saveIntake(edit, editing: copy)
        XCTAssertNil(copy.photoPath)
        XCTAssertNil(photos.data(for: replacement))
        XCTAssertEqual(photos.data(for: originalPath), image)
        try store.deleteIntake(original)
        XCTAssertNil(photos.data(for: originalPath))
    }

    @MainActor
    func testCleanupPreservesSavedPlaceAvatarAndDropsOrphan() throws {
        let directory = try temporaryDirectory()
        let container = try DiaryStore.makeContainer(at: directory.appending(path: "test.store"))
        let photos = DiaryPhotos(directory: directory.appending(path: "Photos", directoryHint: .isDirectory))
        let store = DiaryStore(context: container.mainContext, photos: photos)
        let image = try DiaryPhotos.jpeg(from: fixturePNG())

        try store.saveFavorite(.place, name: "超市", category: "商店", note: "日常采购", photo: .replace(image))
        let place = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<SavedPlace>()).first)
        let avatar = try XCTUnwrap(place.photoPath)
        let orphan = try XCTUnwrap(photos.prepare(.replace(image), previous: nil))
        try store.cleanUpPhotos()
        XCTAssertNil(photos.data(for: orphan))
        XCTAssertEqual(photos.data(for: avatar), image)
        XCTAssertEqual(place.category, "商店")
        XCTAssertEqual(place.note, "日常采购")
        try store.deleteFavorite(.place(place))
        XCTAssertNil(photos.data(for: avatar))
    }

    @MainActor
    func testValidationAllowsMealNameOnlyAndRejectsNormalizedFavoriteDuplicates() throws {
        let container = try DiaryStore.makeContainer(at: temporaryDirectory().appending(path: "test.store"))
        let store = DiaryStore(context: container.mainContext)
        var draft = IntakeDraft(type: .meal)
        draft.mealType = .homemade
        draft.displayName = "晚饭"
        draft.ingredients = [IngredientDraft()]
        let event = try store.saveIntake(draft)
        XCTAssertTrue(event.ingredients.isEmpty)
        draft.ingredients[0].purchasePlaceName = "菜市场"
        XCTAssertThrowsError(try store.saveIntake(draft))

        XCTAssertEqual(DiaryName.normalized(" \tＦＯＯ　 ｍａｒｔ "), "foo mart")
        try store.saveFavorite(.place, name: "Foo  Mart")
        XCTAssertThrowsError(try store.saveFavorite(.place, name: "ＦＯＯ　ＭＡＲＴ")) { error in
            XCTAssertTrue(error is DiaryStore.InputError)
        }
        try store.saveFavorite(.food, name: "FOO Mart")
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<SavedPlace>()), 1)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<SavedFood>()), 1)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func ingredient(_ name: String, place: String = "", amount: String = "", note: String = "") -> IngredientDraft {
        var draft = IngredientDraft()
        draft.name = name
        draft.purchasePlaceName = place
        draft.amountText = amount
        draft.note = note
        return draft
    }

    private func fixturePNG() throws -> Data {
        try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAAD0lEQVR4nGP4z8DA8J8BAAf/Af8Bf4mnAAAAAElFTkSuQmCC"))
    }
}
