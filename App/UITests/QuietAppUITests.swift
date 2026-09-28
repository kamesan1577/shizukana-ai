import XCTest

final class QuietAppUITests: XCTestCase {
    func testHomeAndSettingsOnIPhone16() throws {
        let app = XCUIApplication()
        app.launch()
        if app.buttons["はじめる"].waitForExistence(timeout: 10) {
            app.buttons["はじめる"].tap()
        }
        XCTAssertTrue(app.buttons["発話標本箱"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["設定"].exists)
        XCTAssertFalse(app.textFields.firstMatch.exists)
        let home = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        home.name = "iPhone 16 home"
        home.lifetime = .keepAlways
        add(home)
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .sufficientElementDescription, .hitRegion])

        app.buttons["発話標本箱"].tap()
        XCTAssertTrue(app.staticTexts["まだ標本はありません"].waitForExistence(timeout: 5))
        app.buttons["閉じる"].tap()

        app.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["感覚"].waitForExistence(timeout: 5))
        let settings = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        settings.name = "iPhone 16 settings"
        settings.lifetime = .keepAlways
        add(settings)
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription, .hitRegion])
    }

    func testSettingsWithAccessibilityLargeText() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        if app.buttons["はじめる"].waitForExistence(timeout: 10) {
            app.buttons["はじめる"].tap()
        }
        app.buttons["設定"].tap()
        XCTAssertTrue(app.staticTexts["感覚"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["写真"].exists)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "iPhone 16 settings large text"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        try app.performAccessibilityAudit(for: [.textClipped, .hitRegion])
    }
}
