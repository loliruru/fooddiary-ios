import XCTest

final class DiaryNavigationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTabsAndQuickActionPreviews() {
        let app = launchDiary()
        expectText("今日饮食", in: app)
        capture("home")

        for title in ["记录一餐", "记录零食", "记录身体不适"] {
            app.buttons[title].tap()
            expectText("录入将在后续开放", in: app)
            app.buttons["完成"].tap()
            expectText("今日饮食", in: app)
        }

        let tabs = app.tabBars.firstMatch
        tabs.buttons["记录"].tap()
        expectText("还没有记录", in: app)
        capture("history")
        app.buttons["回到首页"].tap()
        expectText("今日饮食", in: app)

        tabs.buttons["避雷"].tap()
        expectText("暂无待观察的线索", in: app)
        capture("avoidance")

        tabs.buttons["设置"].tap()
        expectText("隐私与数据", in: app)
        capture("settings")
    }

    func testAccessibilityTextSizeKeepsActionsReachable() {
        let app = launchDiary(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        expectText("今日饮食", in: app)
        capture("home-largest-text")

        let symptom = app.buttons["记录身体不适"]
        if !symptom.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(symptom.isHittable)
        capture("home-largest-text-actions")
        symptom.tap()
        expectText("录入将在后续开放", in: app)
    }

    private func launchDiary(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + arguments
        app.launch()
        return app
    }

    private func expectText(_ text: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 5), text, file: file, line: line)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
