import CoreGraphics
import XCTest

final class PhaseThreeFlowTests: XCTestCase {
    func testStandaloneSymptomCanBeEditedAndDeletedFromTimeline() {
        continueAfterFailure = false
        let app = launchDiary()
        let add = app.buttons["记录身体不适"]
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()

        let diarrhea = app.switches["腹泻"]
        let count = app.collectionViews.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label BEGINSWITH %@", "symptom.diarrheaCount", "腹泻次数"))
            .firstMatch
        XCTAssertTrue(diarrhea.waitForExistence(timeout: 5))
        XCTAssertFalse(count.exists)
        diarrhea.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(diarrhea.value as? String, "1", app.debugDescription)
        XCTAssertTrue(count.waitForExistence(timeout: 5), app.debugDescription)
        app.navigationBars.buttons["保存"].tap()

        app.terminate()
        app.launch()
        let history = app.tabBars.buttons["记录"]
        XCTAssertTrue(history.waitForExistence(timeout: 10))
        history.tap()
        let record = app.descendants(matching: .any)["symptom.record"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertTrue(record.label.contains("感受未填写"))
        record.tap()
        XCTAssertTrue(app.navigationBars["身体记录"].waitForExistence(timeout: 5), app.debugDescription)

        app.navigationBars.buttons["编辑"].tap()
        XCTAssertTrue(diarrhea.waitForExistence(timeout: 5))
        XCTAssertTrue(count.exists)
        diarrhea.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(diarrhea.value as? String, "0", app.debugDescription)
        XCTAssertTrue(count.waitForNonExistence(timeout: 5), app.debugDescription)
        app.navigationBars.buttons["保存"].tap()
        let delete = app.buttons["删除身体记录"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        if !delete.isHittable { app.swipeUp() }
        delete.tap()
        app.buttons["删除"].tap()
        XCTAssertTrue(record.waitForNonExistence(timeout: 5))
    }

    func testCreateApplyEditAndDeleteComboFromApp() {
        continueAfterFailure = false
        let app = launchDiary()
        let ingredients = ["Noodles", "Spinach"]
        let name = ingredients.formatted(.list(type: .and).locale(Locale(identifier: "zh-Hans")))
        let nameField = app.textFields["餐名或菜品名称"]
        let addMeal = app.buttons["记录一餐"]
        XCTAssertTrue(addMeal.waitForExistence(timeout: 10))
        addMeal.tap()
        let homemade = app.buttons["自制"]
        XCTAssertTrue(homemade.waitForExistence(timeout: 5))
        homemade.tap()

        let addIngredient = app.buttons["添加食材"]
        for ingredient in ingredients {
            showInForm(addIngredient, app: app)
            addIngredient.tap()
            let emptyIngredient = app.textFields.matching(NSPredicate(
                format: "placeholderValue == %@ AND NOT (value IN %@)", "食材名称", ingredients
            )).firstMatch
            showInForm(emptyIngredient, app: app)
            emptyIngredient.tap()
            emptyIngredient.typeText(ingredient + "\n")
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), app.debugDescription)
        }

        let saveCombo = app.buttons["保存为 Combo"]
        showInForm(saveCombo, app: app)
        saveCombo.tap()
        let notice = app.alerts.firstMatch
        XCTAssertTrue(notice.staticTexts["已保存为 Combo"].waitForExistence(timeout: 5), app.debugDescription)
        notice.buttons["完成"].tap()
        app.navigationBars.buttons["取消"].tap()

        addMeal.tap()
        let use = app.buttons["套用 Combo"]
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        use.tap()
        let combo = app.buttons.matching(identifier: "combo.record").firstMatch
        XCTAssertTrue(combo.waitForExistence(timeout: 5), app.debugDescription)
        combo.tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertEqual(nameField.value as? String, name)
        XCTAssertTrue(homemade.isSelected)
        app.navigationBars.buttons["保存"].tap()

        app.tabBars.buttons["设置"].tap()
        let manage = app.buttons["自制餐 Combo"]
        XCTAssertTrue(manage.waitForExistence(timeout: 5))
        manage.tap()
        XCTAssertTrue(combo.waitForExistence(timeout: 5))
        combo.tap()
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText(" Test")
        app.navigationBars.buttons["保存"].tap()
        let renamed = app.buttons.matching(identifier: "combo.record")
            .matching(NSPredicate(format: "label CONTAINS %@", name + " Test")).firstMatch
        XCTAssertTrue(renamed.waitForExistence(timeout: 5), app.debugDescription)

        renamed.tap()
        let deleteCombo = app.buttons["删除 Combo"]
        showInForm(deleteCombo, app: app)
        deleteCombo.tap()
        app.buttons["删除"].tap()
        XCTAssertTrue(app.staticTexts["还没有 Combo"].waitForExistence(timeout: 5))

        app.tabBars.buttons["记录"].tap()
        let record = app.descendants(matching: .any)
            .matching(identifier: "intake.record")
            .matching(NSPredicate(format: "label CONTAINS %@", name))
            .firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        for ingredient in ingredients {
            XCTAssertTrue(app.staticTexts[ingredient].exists)
        }
        let deleteMeal = app.buttons["删除饮食记录"]
        if !deleteMeal.isHittable { app.swipeUp() }
        deleteMeal.tap()
        app.buttons["删除"].tap()
        XCTAssertTrue(record.waitForNonExistence(timeout: 5))
    }

    private func launchDiary() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    private func showInForm(_ element: XCUIElement, app: XCUIApplication) {
        let form = app.collectionViews.firstMatch
        let top = app.navigationBars.firstMatch.frame.maxY + 8
        let bottom = app.frame.maxY - 44
        for _ in 0..<7 {
            let above = element.exists && element.frame.midY < top
            if !above && element.isHittable && element.frame.midY < bottom { return }
            let start = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.34 : 0.73))
            let end = form.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.68 : 0.40))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("Could not scroll to \(element)")
    }
}
