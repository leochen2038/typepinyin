import XCTest

/// 主流程：开打 → 打完一张牌就赢（测试模式下对手血量极低）→ 小结卡片 → 再来一场。
final class DuelFlowUITests: XCTestCase {
    @MainActor
    func testWinShowsSummaryAndRestarts() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestMode"]
        app.launch()

        // 读出第一张牌的拼音（测试模式下引擎会把它写在无障碍标识里）
        let first = app.descendants(matching: .any)["card0"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let letters = first.value as? String ?? ""
        XCTAssertFalse(letters.isEmpty)
        for ch in letters {
            let key = app.keys[String(ch)].firstMatch
            XCTAssertTrue(key.waitForExistence(timeout: 2), "找不到键 \(ch)")
            key.tap()
        }
        let again = app.buttons["again"]
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH '打赢了'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '失败'")).firstMatch.exists)
        again.tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
    }
}
