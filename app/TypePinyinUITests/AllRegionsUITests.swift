import XCTest

/// 十片地区：拿到上一卷后下一座岛能出发；走完十座岛收到请帖，武林大会开放。
/// 用 -obtain 直接标为拿到，不用真打。
final class AllRegionsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func launch(obtain: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestMode", "-fastJourney", "-resetJourney", "-noStele", "-obtain", obtain]   // 碑文在 JourneyUITests 里测
        app.launch()
        return app
    }

    /// 站前卡片出现了：第一站可能是对手（挑战），也可能是随机插进来的奇遇（去看看）。
    func stationCardAppears(_ app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        let either = app.buttons.matching(NSPredicate(format: "label == '挑战' OR label == '去看看'")).firstMatch
        return either.waitForExistence(timeout: timeout)
    }

    func testNewRegionCanSetOut() {
        let app = launch(obtain: "base")
        let isle = app.descendants(matching: .any)["place-banshanzhen"]
        XCTAssertTrue(isle.waitForExistence(timeout: 15), "地图上有半山镇（葫芦集之后的下一座）")
        isle.tap()
        let go = app.buttons["regionGo"]
        XCTAssertTrue(go.waitForExistence(timeout: 5))
        XCTAssertEqual(go.label, "出发", "半山镇能出发，不是「还在修路」")
        go.tap()
        XCTAssertTrue(stationCardAppears(app), "进去出现站前卡片")
        XCTAssertTrue(app.descendants(matching: .any)["stationLine"].exists)
    }

    /// 通关后再去一趟：从头走一整趟（不是随机一场），站前照样问挑战，顶栏写第几站、还剩几站。
    func testClearedRegionStartsFullRoute() {
        let app = launch(obtain: "base,biyin-shang")
        let isle = app.descendants(matching: .any)["place-banshanzhen"]
        XCTAssertTrue(isle.waitForExistence(timeout: 15))
        isle.tap()
        let go = app.buttons["regionGo"]
        XCTAssertTrue(go.waitForExistence(timeout: 5))
        XCTAssertEqual(go.label, "再去一趟")
        go.tap()
        XCTAssertTrue(stationCardAppears(app), "从第一站开始，先问挑战或去看看")
        let bar = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '第 1 站'")).firstMatch
        XCTAssertTrue(bar.exists, "顶栏写第几站")
        XCTAssertTrue(bar.label.contains("还剩"), "是完整的一趟：\(bar.label)")
    }

    /// 走到一半的地区：卡片上有「从头开始」，确认后从第一站重新走。
    func testRestartRegion() {
        let app = launch(obtain: "base")
        let isle = app.descendants(matching: .any)["place-banshanzhen"]
        XCTAssertTrue(isle.waitForExistence(timeout: 15))
        isle.tap()
        app.buttons["regionGo"].tap()
        XCTAssertTrue(app.buttons["返回"].waitForExistence(timeout: 15))
        app.buttons["返回"].tap()
        XCTAssertTrue(isle.waitForExistence(timeout: 10))
        isle.tap()
        XCTAssertTrue(app.buttons["regionGo"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["regionGo"].label, "接着走")
        let restart = app.buttons["regionRestart"]
        XCTAssertTrue(restart.exists, "走到一半有「从头开始」")
        restart.tap()
        XCTAssertTrue(app.staticTexts["这一趟从第一站重新走？"].waitForExistence(timeout: 5))
        // 确认框里的按钮没有标识，只有文字；卡片上那个的标识是 regionRestart
        app.buttons.matching(NSPredicate(format: "label == '从头开始' AND identifier != 'regionRestart'")).firstMatch.tap()
        XCTAssertTrue(stationCardAppears(app), "重新从第一站开始")
    }

    func testAllTenSealsAndGathering() {
        let app = launch(obtain: "all")
        let peak = app.descendants(matching: .any)["place-wuLinDaHui"]
        XCTAssertTrue(peak.waitForExistence(timeout: 15))
        XCTAssertTrue(peak.label.contains("上山去"), "走完十座岛，武林大会开放：\(peak.label)")
        XCTAssertTrue(app.descendants(matching: .any)["invitation"].waitForExistence(timeout: 5), "收到妙笔书生的请帖")
        app.buttons["上山"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["gatheringHall"].waitForExistence(timeout: 10), "上山到擂台（-noStele 跳过碑）")
        XCTAssertTrue(app.buttons["挑战"].exists, "第一场十位掌门可以开打")
    }
}
