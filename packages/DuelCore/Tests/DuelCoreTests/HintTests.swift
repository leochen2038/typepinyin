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

    @Test func wrongFirstLetterHintsRightAway() {
        let e = Fixture.engine(features: [])
        let clock = FakeClock()
        let first = Array(e.cards[0].word.letters)[0]
        let wrong = wrongFirstLetter(e)
        let ev = clock.type(e, String(wrong))              // 第一个字母就按错：马上亮出该按的字母
        #expect(ev.contains(.letterRejected(wrong)))
        #expect(ev.contains(.hint(first)))
        #expect(e.currentHint == first)
        #expect(clock.type(e, String(first)).contains(.hintCleared))
        #expect(e.currentHint == nil)
    }

    @Test func wrongFirstLetterNoHintWhenHintsOff() {
        var t = Tuning()
        t.hintSeconds = 0
        let e = Fixture.engine(features: [], tuning: t)
        let ev = FakeClock().type(e, String(wrongFirstLetter(e)))
        #expect(!ev.contains { if case .hint = $0 { return true } else { return false } })
        #expect(e.currentHint == nil)
    }

    @Test func wrongFirstLetterThenHintedCardIsNotGold() {
        let e = Fixture.engine(features: [], tuning: Fixture.threeCards)
        let clock = FakeClock()
        clock.type(e, String(wrongFirstLetter(e)))
        clock.type(e, "pengyou")                           // 照着提示打的
        #expect(e.moveMarks == [false])
    }

    @Test func wrongFirstLetterThenOwnPickStaysGold() {
        let e = Fixture.engine(features: [], tuning: Fixture.threeCards)
        let clock = FakeClock()
        clock.type(e, String(wrongFirstLetter(e)))         // 亮的是朋友的 p
        clock.type(e, "zhuangxiu")                         // 自己挑了装修，没看提示
        #expect(e.moveMarks == [true])
    }

    @Test func secondWrongFirstLetterKeepsTheHint() {
        let e = Fixture.engine(features: [], tuning: Fixture.threeCards)
        let clock = FakeClock()
        let wrong = wrongFirstLetter(e)
        clock.type(e, String(wrong))
        clock.type(e, String(wrong))                       // 再按错一次，提示还亮着，这一招照样不算完美
        #expect(e.currentHint == "p")
        clock.type(e, "pengyou")
        #expect(e.moveMarks == [false])
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

/// 一个和桌上所有牌的首字母都不一样的字母。
private func wrongFirstLetter(_ e: DuelEngine) -> Character {
    let used = Set(e.cards.compactMap { $0.word.letters.first })
    return "abcdefghijklmnopqrstuvwxyz".first { !used.contains($0) }!
}
