import Testing
@testable import DuelCore

/// 卡壳提示：卡住 2 秒提示下一个字母，打对就熄灭；被提示过的招不算金色。
@Suite struct HintTests {
    @Test func hintsNextLetterOfLockedCard() {
        let e = Fixture.engine(features: [])
        let clock = FakeClock()
        clock.type(e, "pe")
        #expect(clock.wait(e, 1.9).isEmpty)
        let ev = clock.wait(e, 0.2)
        #expect(ev.contains(.hint("n")))
        #expect(e.currentHint == "n")
        let next = clock.type(e, "n")
        #expect(next.contains(.hintCleared))
        #expect(e.currentHint == nil)
        #expect(clock.wait(e, 2.1).contains(.hint("g")))   // 后面的字母同理
    }

    @Test func mistakeHintsRightAway() {
        let e = Fixture.engine(features: [])
        let clock = FakeClock()
        clock.type(e, "pe")
        let ev = clock.type(e, "x")                        // 打错：不用等 2 秒，马上提示 n
        #expect(ev.contains(.hint("n")))
        #expect(e.currentHint == "n")
        #expect(clock.type(e, "n").contains(.hintCleared))
    }

    @Test func noHintForFirstLetter() {
        let e = Fixture.engine(features: [.flaw])
        let clock = FakeClock()
        let ev = clock.wait(e, 5)
        #expect(!ev.contains { if case .hint = $0 { return true } else { return false } })
        #expect(e.currentHint == nil)
    }

    @Test func hintedMoveIsNotGold() {
        let e = Fixture.engine(features: [], tuning: Fixture.threeCards)
        let clock = FakeClock()
        clock.type(e, "pe")
        clock.wait(e, 2.1)
        clock.type(e, "ngyou")
        #expect(e.moveMarks == [false])
    }
}
