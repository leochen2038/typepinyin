import XCTest

/// 旅程：从梦里的开场一路打到葫芦集；关掉再打开回到原处。
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
        XCTAssertTrue(app.descendants(matching: .any)["guide"].waitForExistence(timeout: 15), "梦里第一张牌有教学引导")
        XCTAssertTrue(app.buttons["backToMap"].waitForExistence(timeout: 120), "打完初入江湖走到葫芦集")
        XCTAssertFalse(app.staticTexts["失败"].exists)
        app.terminate()
        app = launch(reset: false)
        XCTAssertTrue(app.buttons["backToMap"].waitForExistence(timeout: 15), "再打开回到葫芦集，不再从开场白开始")
        XCTAssertFalse(app.staticTexts["openingLine"].exists)
    }
}
