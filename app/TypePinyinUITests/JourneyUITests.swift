import XCTest

/// 旅程：从梦里的开场打完，到江湖地图点葫芦集，站前问挑战；关掉再打开回到原处。
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
        XCTAssertTrue(app.descendants(matching: .any)["mapGuide"].waitForExistence(timeout: 120), "梦醒后到江湖地图，引导点葫芦集")
        XCTAssertTrue(app.buttons["backToMap"].waitForExistence(timeout: 30), "进到葫芦集")
        XCTAssertTrue(app.buttons["挑战"].waitForExistence(timeout: 30), "到了一站先问挑战还是返回")
        XCTAssertFalse(app.staticTexts["失败"].exists)
        app.terminate()
        app = launch(reset: false)
        XCTAssertTrue(app.buttons["backToMap"].waitForExistence(timeout: 15), "再打开回到葫芦集，不再从开场白开始")
        XCTAssertFalse(app.staticTexts["openingLine"].exists)
    }

    /// 练功房：梦里打过的词进了练功房；从地图点进去，先问挑战，挑战后开打。
    func testPracticeRoomUsesWordsTyped() {
        var app = launch(reset: true)
        XCTAssertTrue(app.buttons["挑战"].waitForExistence(timeout: 120), "打完梦，进到葫芦集第一站")
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-uiTestMode", "-fastJourney"]
        app.launch()
        XCTAssertTrue(app.buttons["返回"].waitForExistence(timeout: 15))
        app.buttons["返回"].tap()
        let room = app.descendants(matching: .any)["place-chuRuJiangHu"]
        XCTAssertTrue(room.waitForExistence(timeout: 10), "地图最下面是练功房")
        room.tap()
        let count = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '这里有你打过的'")).firstMatch
        XCTAssertTrue(count.waitForExistence(timeout: 10), "练功房里有梦里打过的词")
        XCTAssertTrue(app.buttons["挑战"].exists)
        app.buttons["挑战"].tap()
        XCTAssertFalse(app.buttons["挑战"].waitForExistence(timeout: 3), "挑战后进比武")
    }
}
