import XCTest

final class IntakeFlowTests: XCTestCase {
    func testSnackEntrySurvivesRelaunchAndCanBeEditedAndDeletedFromHistory() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let name = "Snack \(UUID().uuidString.prefix(8))"
        let add = app.buttons["记录零食"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let nameField = app.textFields["零食名称"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(name)
        app.navigationBars.buttons["保存"].tap()
        XCTAssertTrue(record(containing: name, in: app).waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        let history = app.tabBars.buttons["记录"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.tap()
        let stored = record(containing: name, in: app)
        XCTAssertTrue(stored.waitForExistence(timeout: 5))
        stored.tap()

        app.navigationBars.buttons["编辑"].tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(" Test")
        app.navigationBars.buttons["保存"].tap()
        let edited = name + " Test"
        XCTAssertTrue(app.staticTexts[edited].waitForExistence(timeout: 5))

        let delete = app.buttons["删除饮食记录"]
        if !delete.isHittable { app.swipeUp() }
        delete.tap()
        app.buttons["删除"].tap()
        XCTAssertTrue(app.staticTexts["还没有记录"].waitForExistence(timeout: 5))
        XCTAssertFalse(record(containing: edited, in: app).exists)
    }

    private func record(containing name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "intake.record")
            .matching(NSPredicate(format: "label CONTAINS %@", name))
            .firstMatch
    }
}
