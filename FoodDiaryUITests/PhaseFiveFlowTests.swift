import XCTest

final class PhaseFiveFlowTests: XCTestCase {
    func testClearRequiresConfirmationAndUpdatesTimeline() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let addSnack = app.buttons["记录零食"]
        XCTAssertTrue(addSnack.waitForExistence(timeout: 10))
        addSnack.tap()
        let field = app.textFields["零食名称"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let name = "Backup \(UUID().uuidString.prefix(8))"
        field.typeText(name)
        app.navigationBars.buttons["保存"].tap()

        app.tabBars.buttons["设置"].tap()
        let data = app.buttons["备份与数据"]
        reveal(data, app: app)
        data.tap()
        XCTAssertTrue(app.navigationBars["备份与数据"].waitForExistence(timeout: 5))
        let clear = app.buttons["清空全部数据"]
        reveal(clear, app: app)
        clear.tap()
        let confirmation = app.alerts["清空本机的全部数据？"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["取消"].tap()
        app.tabBars.buttons["记录"].tap()
        let record = app.descendants(matching: .any).matching(identifier: "intake.record")
            .matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        reveal(record, app: app)
        record.tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))

        app.tabBars.buttons["设置"].tap()
        reveal(clear, app: app)
        clear.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["清空全部数据"].tap()
        app.tabBars.buttons["记录"].tap()
        XCTAssertTrue(app.staticTexts["还没有记录"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        app.tabBars.buttons["记录"].tap()
        XCTAssertTrue(app.staticTexts["还没有记录"].waitForExistence(timeout: 5))
    }

    func testBackupControlsRemainReachableAtAccessibilityTextSize() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let settings = app.tabBars.buttons["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let data = app.buttons["备份与数据"]
        reveal(data, app: app)
        data.tap()
        XCTAssertTrue(app.navigationBars["备份与数据"].waitForExistence(timeout: 5))
        reveal(app.buttons["导出 CSV"], app: app)
        reveal(app.buttons["导出 JSON 备份"], app: app)
        reveal(app.buttons["恢复 JSON 备份"], app: app)
        reveal(app.buttons["清空全部数据"], app: app)
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<6 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
}
