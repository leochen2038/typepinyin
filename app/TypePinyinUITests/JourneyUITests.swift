import XCTest

/// 旅程：从开场白一路打到十里坡；关掉再打开回到原处。
/// 用 -autoplay 自动打字、自动点下一步，-fastJourney 让对手一两招就倒、跳过动画。
final class JourneyUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func launch(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestMode", "-fastJourney", "-autoplay"] + (reset ? ["-resetJourney"] : [])
        app.launch()
        return app
    }

    func testOpeningToShilipoAndResume() {
        var app = launch(reset: true)
        XCTAssertTrue(app.staticTexts["打出牌上字的拼音，就是出招。"].waitForExistence(timeout: 15), "初入江湖第一张牌有入门提示")
        XCTAssertTrue(app.buttons["backToMap"].waitForExistence(timeout: 120), "打完初入江湖走到十里坡")
        XCTAssertFalse(app.staticTexts["失败"].exists)
        app.terminate()
        app = launch(reset: false)
        XCTAssertTrue(app.buttons["backToMap"].waitForExistence(timeout: 15), "再打开回到十里坡，不再从开场白开始")
        XCTAssertFalse(app.staticTexts["openingLine"].exists)
    }
}
