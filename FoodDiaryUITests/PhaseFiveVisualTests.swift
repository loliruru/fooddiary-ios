import XCTest

final class PhaseFiveVisualTests: XCTestCase {
    func testCSVShareSheet() {
        checkShareSheet(button: "导出 CSV", fileExtension: "csv")
    }

    func testJSONShareSheet() {
        checkShareSheet(button: "导出 JSON 备份", fileExtension: "json")
    }

    func testBackupAndDataAtLargestTextSize() {
        let app = launch(largeText: true)
        openData(in: app)
        capture("backup-largest")
        let clear = app.buttons["清空全部数据"]
        reveal(clear, in: app)
        clear.tap()
        XCTAssertTrue(app.alerts["清空本机的全部数据？"].waitForExistence(timeout: 5))
        capture("clear-confirmation-largest")
    }

    func testTabRoots() {
        let app = launch()
        for (title, name) in [("首页", "home"), ("记录", "history"), ("避雷", "avoidance"), ("设置", "settings")] {
            let tab = app.tabBars.buttons[title]
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
            capture(name)
        }
        openData(in: app)
        capture("backup-controls")
    }

    private func checkShareSheet(button: String, fileExtension: String) {
        let app = launch()
        openData(in: app)
        let export = app.buttons[button]
        reveal(export, in: app)
        export.tap()
        let preview = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "FoodDiary-")).firstMatch
        let hasPreview = preview.waitForExistence(timeout: 6)
        capture("share-\(fileExtension)")
        XCTAssertTrue(hasPreview, app.debugDescription)
    }

    private func launch(largeText: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    private func openData(in app: XCUIApplication) {
        let settings = app.tabBars.buttons["设置"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        if !settings.isSelected { settings.tap() }
        let data = app.buttons["备份与数据"]
        reveal(data, in: app)
        data.tap()
        XCTAssertTrue(app.navigationBars["备份与数据"].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }

    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
