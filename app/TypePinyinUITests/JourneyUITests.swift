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
        XCTAssertTrue(app.descendants(matching: .any)["mapGuide"].waitForExistence(timeout: 60), "开场白之后到江湖地图，引导点葫芦集")
        XCTAssertTrue(app.descendants(matching: .any)["stele"].waitForExistence(timeout: 60), "第一次进葫芦集，门口先打葫芦集碑，不比武")
        XCTAssertTrue(app.buttons["backToMap"].waitForExistence(timeout: 30), "进到葫芦集")
        XCTAssertTrue(app.buttons["挑战"].waitForExistence(timeout: 30), "到了一站先问挑战还是返回")
        XCTAssertFalse(app.staticTexts["失败"].exists)
        app.terminate()
        // 这回不自动打：-autoplay 会马上开打，比武和结算要十几秒，顶栏的 backToMap 那时候不在
        app = XCUIApplication()
        app.launchArguments = ["-uiTestMode", "-fastJourney"]
        app.launch()
        XCTAssertTrue(app.buttons["backToMap"].waitForExistence(timeout: 15), "再打开回到葫芦集，不再从开场白开始")
        XCTAssertFalse(app.staticTexts["openingLine"].exists)
    }

    /// 练习场：还没比过武时「词语」是空的；「文章」里有葫芦集的诗文，点开一句句打，「返回」回到练习场。
    func testPracticeRoomBeforeFirstDuel() {
        var app = launch(reset: true)
        XCTAssertTrue(app.buttons["挑战"].waitForExistence(timeout: 120), "打完葫芦集碑，进到葫芦集第一站")
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-uiTestMode", "-fastJourney"]
        app.launch()
        XCTAssertTrue(app.buttons["返回"].waitForExistence(timeout: 15))
        app.buttons["返回"].tap()
        let room = app.descendants(matching: .any)["place-chuRuJiangHu"]
        XCTAssertTrue(room.waitForExistence(timeout: 10), "地图最下面是练习场")
        room.tap()
        XCTAssertTrue(app.staticTexts["这里还没有词"].waitForExistence(timeout: 10), "还没比过武，词语是空的")
        app.descendants(matching: .any)["practiceTab-1"].firstMatch.tap()
        let passage = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'passage-'")).firstMatch
        XCTAssertTrue(passage.waitForExistence(timeout: 5), "文章里有葫芦集的诗文")
        passage.tap()
        XCTAssertTrue(app.buttons["返回"].waitForExistence(timeout: 5), "打字页顶上有返回")
        app.buttons["返回"].tap()
        XCTAssertTrue(passage.waitForExistence(timeout: 5), "返回到练习场的文章")
    }

}
