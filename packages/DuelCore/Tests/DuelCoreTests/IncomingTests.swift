import Testing
@testable import DuelCore

/// 来招：格挡、弹反
@Suite struct IncomingTests {
    func engineWithIncoming() -> (DuelEngine, FakeClock) {
        let e = Fixture.engine(features: [.incoming])
        let clock = FakeClock()
        e.opponent.nextAttackAt = 0
        clock.wait(e, 0.01)
        return (e, clock)
    }

    @Test func attackIntervalWithinJitter() {
        for seed in 1...20 {
            let e = DuelEngine(bank: Fixture.bank, tuning: Fixture.hpMode, opponent: .init(name: "a", title: "b"), seed: UInt64(seed))
            e.start(at: 0)
            #expect(e.opponent.nextAttackAt >= 5.5 * 0.7 && e.opponent.nextAttackAt <= 5.5 * 1.3)
        }
    }

    @Test func chargeDurationFormula() throws {
        let (e, _) = engineWithIncoming()
        let inc = try #require(e.opponent.incoming)
        let expected = max(2.4, Double(inc.word.letterCount) * e.player.secondsPerLetter * 2.0 + 0.9)
        #expect(abs(inc.duration - expected) < 1e-9)
        #expect(inc.duration >= 2.4)
    }

    @Test func incomingUsesOnlyLearnedSyllables() {
        for seed in 1...30 {
            let e = Fixture.engine(features: [.incoming], seed: UInt64(seed))
            let clock = FakeClock()
            e.opponent.nextAttackAt = 0
            clock.wait(e, 0.01)
            if let inc = e.opponent.incoming {
                #expect(inc.word.syllables.allSatisfy(e.learner.learned.contains))
            }
        }
    }

    @Test func fastAnswerIsParry() {
        let (e, clock) = engineWithIncoming()
        let inc = e.opponent.incoming!
        let ev = clock.type(e, inc.word.letters, dt: inc.duration * 0.4 / Double(inc.word.letterCount))
        #expect(ev.contains(.parried))
        #expect(e.opponent.isStunned(at: e.gameClock))
        #expect(abs(e.opponent.stunnedUntil - e.gameClock - 1.6) < 1e-9)
    }

    @Test func lateAnswerIsBlock() {
        let (e, clock) = engineWithIncoming()
        let inc = e.opponent.incoming!
        let ev = clock.type(e, inc.word.letters, dt: inc.duration * 0.8 / Double(inc.word.letterCount))
        #expect(ev.contains(.blocked))
        #expect(!ev.contains(.parried))
    }

    @Test func missedIncomingHurtsAndBreaksCombo() {
        let (e, clock) = engineWithIncoming()
        e.player.combo = 3
        e.player.lastStrikeAt = e.gameClock
        e.target = .card(0)                       // 正在打牌，窗口内不会断
        let ev = clock.wait(e, e.opponent.incoming!.duration + 0.01)
        #expect(ev.contains(.hitByIncoming(damage: 10)))
        #expect(e.player.hp == 90)
        #expect(e.player.combo == 0)
    }

    @Test func noAttackWhileStunned() {
        let (e, clock) = engineWithIncoming()
        let inc = e.opponent.incoming!
        clock.type(e, inc.word.letters, dt: 0.01)
        e.opponent.nextAttackAt = e.gameClock + 0.1
        clock.wait(e, 0.5)
        #expect(e.opponent.incoming == nil)
    }

    @Test func stunMultipliesDamage() {
        let e = Fixture.engine(features: [])
        let card = e.cards[0]
        let normal = e.damage(for: card, combo: 1, store: 1)
        e.opponent.stunnedUntil = e.gameClock + 1
        #expect(e.damage(for: card, combo: 1, store: 1) == Int((Double(normal) * 1.5).rounded()))
    }
}
