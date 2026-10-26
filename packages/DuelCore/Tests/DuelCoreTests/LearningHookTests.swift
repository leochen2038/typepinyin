import Testing
@testable import DuelCore
import LearningCore

/// 旅程接口：出牌来源、单场设置、按音节交回打字结果。
@Suite struct LearningHookTests {
    final class FixedSource: CardSource {
        var words: [Word]
        var done: [(String, Bool)] = []
        var newMoves: [String] = []
        init(_ words: [Word]) { self.words = words }
        func nextCard(avoidingFirstLetters: Set<Character>, avoidingTexts: Set<String>) -> (word: Word, rank: Int) {
            let w = words.removeFirst()
            words.append(w)
            return (w, 2)
        }
        func nextIdiom() -> (word: Word, rank: Int)? { nil }
        func cardDone(_ word: Word, clean: Bool) { done.append((word.text, clean)) }
        func newMove(_ spelling: String) { newMoves.append(spelling) }
    }

    func engine(_ source: FixedSource, setup: DuelSetup = DuelSetup()) -> DuelEngine {
        var t = Tuning.standard
        t.hintSeconds = 2
        let e = DuelEngine(bank: Fixture.bank, tuning: t, opponent: Opponent(name: "毛小六", title: "路边的毛贼"),
                           seed: 1, features: .all, setup: setup, source: source)
        e.start(at: 100)
        return e
    }

    @Test func cardsComeFromTheSource() {
        let src = FixedSource([Fixture.word("朋友"), Fixture.word("光明")])
        let e = engine(src)
        #expect(e.cards[0].word.text == "朋友")
        #expect(e.cards[0].rank == 2)
        FakeClock().type(e, "pengyou")
        #expect(src.done.first?.0 == "朋友")
        #expect(e.cards[0].word.text == "光明")
    }

    @Test func setupOverridesSpeedLivesAndBoss() {
        var s = DuelSetup()
        s.secondsPerLetter = 0.3
        s.lives = 3
        s.bossPressure = true
        let e = engine(FixedSource([Fixture.word("朋友")]), setup: s)
        #expect(e.player.secondsPerLetter == 0.3)
        #expect(e.opponent.maxLives == 3)
        #expect(e.bossMode)
    }

    @Test func minHPKeepsPlayerAlive() {
        var s = DuelSetup()
        s.minHP = 1
        let e = engine(FixedSource([Fixture.word("朋友")]), setup: s)
        e.player.hp = 5
        FakeClock().wait(e, e.opponent.pressureDuration + 0.1)
        #expect(e.player.hp == 1)
        #expect(e.phase == .fighting)
    }

    /// 每个音节一条结果：打对、看没看提示、上手时间。
    @Test func attemptsPerSyllable() {
        var s = DuelSetup()
        s.learned = ["peng"]
        let src = FixedSource([Fixture.word("朋友")])
        let e = engine(src, setup: s)
        let clock = FakeClock()
        clock.wait(e, 0.5)
        clock.type(e, "peng", dt: 0.1)
        clock.type(e, "x", dt: 0.1)            // you 打错一次：没学过 → 新招
        clock.type(e, "you", dt: 0.1)
        let a = e.attempts
        #expect(a.map(\.spelling) == ["peng", "you"])
        #expect(a[0].counts)
        #expect(abs(a[0].startSeconds - 0.6) < 0.01)
        #expect(!a[1].correct)
        #expect(src.newMoves == ["you"])
    }

    @Test func hintedSyllableIsMarked() {
        let e = engine(FixedSource([Fixture.word("朋友")]))
        let clock = FakeClock()
        clock.type(e, "p", dt: 0.1)
        clock.wait(e, 2.1)                     // 卡住 2 秒：提示下一个字母
        clock.type(e, "engyou", dt: 0.1)
        #expect(e.attempts.first?.usedHint == true)
    }
}
