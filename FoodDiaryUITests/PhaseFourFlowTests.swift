import CoreGraphics
import XCTest

final class PhaseFourFlowTests: XCTestCase {
    func testReviewNewSymptomAndTraceAvoidanceCountsToOriginals() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let name = "Review \(UUID().uuidString.prefix(8))"
        let addSnack = app.buttons["记录零食"]
        XCTAssertTrue(addSnack.waitForExistence(timeout: 10))
        addSnack.tap()
        let snackName = app.textFields["零食名称"]
        XCTAssertTrue(snackName.waitForExistence(timeout: 5))
        snackName.tap()
        snackName.typeText(name)
        app.navigationBars.buttons["保存"].tap()

        let addBody = app.buttons["记录身体不适"]
        XCTAssertTrue(addBody.waitForExistence(timeout: 5))
        addBody.tap()
        let uncomfortable = app.buttons["不舒服"]
        XCTAssertTrue(uncomfortable.waitForExistence(timeout: 5))
        uncomfortable.tap()
        let diarrhea = app.switches["腹泻"]
        diarrhea.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(diarrhea.value as? String, "1")
        app.navigationBars.buttons["保存"].tap()

        let review = app.navigationBars["身体记录"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        let candidate = record("exposure.intake", containing: name, app: app)
        reveal(candidate, app: app)
        XCTAssertTrue(candidate.label.contains("距症状开始约"))
        let judgment = app.descendants(matching: .any).matching(identifier: "exposure.judgment").firstMatch
        reveal(judgment, app: app)
        XCTAssertTrue(judgment.label.contains("未判断"))
        judgment.tap()
        app.buttons["我怀疑与此有关"].tap()
        XCTAssertTrue(judgment.label.contains("我怀疑与此有关"))
        review.buttons["完成"].tap()

        app.tabBars.buttons["避雷"].tap()
        let summary = record("avoidance.summary", containing: name, app: app)
        reveal(summary, app: app)
        XCTAssertTrue(summary.label.contains("有不适记录 1 次／共摄入 1 次"), app.debugDescription)
        XCTAssertTrue(summary.label.contains("标记怀疑 1 次"), app.debugDescription)
        summary.tap()
        XCTAssertTrue(app.navigationBars["待观察详情"].waitForExistence(timeout: 5))
        let original = record("intake.record", containing: name, app: app)
        reveal(original, app: app)
        original.tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))

        let deleteIntake = app.buttons["删除饮食记录"]
        reveal(deleteIntake, app: app)
        deleteIntake.tap()
        app.buttons["删除"].tap()

        app.tabBars.buttons["记录"].tap()
        let search = app.textFields["history.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(name + "\n")
        XCTAssertTrue(app.staticTexts["没有符合条件的记录"].waitForExistence(timeout: 5))
        app.buttons["清除搜索"].tap()

        let body = app.descendants(matching: .any).matching(identifier: "symptom.record").firstMatch
        reveal(body, app: app)
        body.tap()
        let deleteBody = app.buttons["删除身体记录"]
        reveal(deleteBody, app: app)
        deleteBody.tap()
        app.buttons["删除"].tap()
        XCTAssertTrue(body.waitForNonExistence(timeout: 5))
    }

    private func record(_ identifier: String, containing name: String, app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .matching(NSPredicate(format: "label CONTAINS %@", name))
            .firstMatch
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<6 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
}
