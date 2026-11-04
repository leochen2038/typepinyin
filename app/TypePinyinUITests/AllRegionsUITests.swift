import XCTest

/// 十片地区全部开放：拿到《基本功》后新地区能出发；十卷集齐时武林大会说还在筹备。
/// 用 -obtain 直接标为拿到，不用真打。
final class AllRegionsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func launch(obtain: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestMode", "-fastJourney", "-resetJourney", "-obtain", obtain]
        app.launch()
        return app
    }

    func testNewRegionCanSetOut() {
        let app = launch(obtain: "base")
        let isle = app.descendants(matching: .any)["place-baimeitai"]
        XCTAssertTrue(isle.waitForExistence(timeout: 15), "地图上有白梅台")
        isle.tap()
        let go = app.buttons["regionGo"]
        XCTAssertTrue(go.waitForExistence(timeout: 5))
        XCTAssertEqual(go.label, "出发", "白梅台能出发，不是「还在修路」")
        go.tap()
        XCTAssertTrue(app.buttons["挑战"].waitForExistence(timeout: 15), "进去出现站前卡片")
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
        XCTAssertTrue(app.buttons["挑战"].waitForExistence(timeout: 15), "从第一站开始，先问挑战")
        let bar = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '第 1 站'")).firstMatch
        XCTAssertTrue(bar.exists, "顶栏写第几站")
        XCTAssertTrue(bar.label.contains("还剩"), "是完整的一趟：\(bar.label)")
    }

    /// 走到一半的地区：卡片上有「从头开始」，确认后从第一站重新走。
    func testRestartRegion() {
        let app = launch(obtain: "base")
        let isle = app.descendants(matching: .any)["place-baimeitai"]
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
        XCTAssertTrue(app.buttons["挑战"].waitForExistence(timeout: 15), "重新从第一站开始")
    }

    func testAllTenSealsAndGathering() {
        let app = launch(obtain: "all")
        let peak = app.descendants(matching: .any)["place-wuLinDaHui"]
        XCTAssertTrue(peak.waitForExistence(timeout: 15))
        XCTAssertTrue(peak.label.contains("十卷集齐"), "十方印盖满：\(peak.label)")
        peak.tap()
        let text = app.staticTexts["gatheringText"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(text.label.contains("还在筹备"))
    }
}
