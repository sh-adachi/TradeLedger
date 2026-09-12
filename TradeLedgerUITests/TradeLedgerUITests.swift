import XCTest

final class TradeLedgerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testRecordCashFlowAdjustmentAndEditing() {
        replaceText("onboarding.initialBalance", with: "1000000")
        tapVisible(app.buttons["onboarding.start"])
        XCTAssertTrue(app.buttons["tab.dashboard"].waitForExistence(timeout: 5))

        tapVisible(app.buttons["record.add"].firstMatch)
        replaceText("record.balance", with: "1150000")
        replaceText("record.deposit", with: "100000")
        replaceText("record.withdrawal", with: "20000")
        tapVisible(app.buttons["record.save"])

        // 1,150,000 - 1,000,000 - 100,000 + 20,000 = 70,000.
        assertMetric("dashboard.currentBalance", contains: "1,150,000")
        assertMetric("dashboard.totalProfit", contains: "70,000")
        attachScreenshot(named: "01-recorded-dashboard")

        app.buttons["tab.history"].tap()
        tapVisible(app.buttons["history.record"].firstMatch)
        replaceText("record.balance", with: "1160000")
        tapVisible(app.buttons["record.save"])
        app.buttons["tab.dashboard"].tap()
        assertMetric("dashboard.currentBalance", contains: "1,160,000")
        assertMetric("dashboard.totalProfit", contains: "80,000")

        app.buttons["tab.analysis"].tap()
        XCTAssertTrue(app.buttons["tab.settings"].exists)
        attachScreenshot(named: "02-analysis")
        app.buttons["tab.settings"].tap()
        XCTAssertFalse(app.alerts.firstMatch.exists)
        attachScreenshot(named: "03-settings")
    }

    func testDemoIsExplicitAndReturnsToFreshOnboarding() {
        XCTAssertTrue(app.buttons["onboarding.demo"].waitForExistence(timeout: 5))
        tapVisible(app.buttons["onboarding.demo"])
        XCTAssertTrue(app.buttons["demo.exit"].waitForExistence(timeout: 5))
        attachScreenshot(named: "04-demo-dashboard")
        app.buttons["tab.history"].tap()
        XCTAssertTrue(app.buttons["history.record"].firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(named: "05-demo-history")
        app.buttons["demo.exit"].tap()
        XCTAssertTrue(app.textFields["onboarding.initialBalance"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tab.dashboard"].exists)
    }

    func testDemoLaunchArgumentAndAllTabs() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--demo"]
        app.launch()
        XCTAssertTrue(app.buttons["demo.exit"].waitForExistence(timeout: 5))
        for tab in ["history", "analysis", "settings", "dashboard"] {
            let button = app.buttons["tab.\(tab)"]
            XCTAssertTrue(button.exists)
            button.tap()
            XCTAssertFalse(app.alerts.firstMatch.exists)
        }
        attachScreenshot(named: "06-demo-launch")
    }

    private func replaceText(_ identifier: String, with value: String) {
        let field = app.textFields[identifier]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing field \(identifier)")
        scrollToVisible(field)
        field.tap()
        let current = field.value as? String ?? ""
        // Tapping the far right places the insertion point after an existing amount.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + value)
        if app.buttons["完了"].isHittable { app.buttons["完了"].tap() }
    }

    private func scrollToVisible(_ element: XCUIElement) {
        for _ in 0..<6 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Element is not reachable: \(element.identifier)")
    }

    private func tapVisible(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        scrollToVisible(element)
        element.tap()
    }

    private func assertMetric(_ identifier: String, contains value: String) {
        let element = app.staticTexts[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let expected = NSPredicate(format: "label CONTAINS %@", value)
        expectation(for: expected, evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
