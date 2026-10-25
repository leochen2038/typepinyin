import Testing
@testable import DuelCore

/// 新牌被回顾牌盖着的那一两秒不算玩家的时间：露出来才开始算上手时间、连招间隔和对手蓄力。
@Suite struct RevealTests {
    func engine(hold: Bool = true) -> (DuelEngine, FakeClock) {
        let e = Fixture.engine(["朋友"], features: [.incoming], tuning: .standard)
        e.holdNewCards = hold
        return (e, FakeClock())
    }

    @Test func newCardWaitsForReveal() {
        let (e, clock) = engine()
        clock.type(e, "pengyou")
        #expect(e.player.combo == 1)
        #expect(e.opponent.pressureStart == nil)
        clock.wait(e, 5)                                   // 回顾演得再久，连招不断、对手不出手
        #expect(e.player.combo == 1)
        #expect(e.player.hp == e.tuning.playerMaxHP)
        e.cardRevealed(0, at: clock.now)
        #expect(e.opponent.pressureStart == e.gameClock)
        #expect(e.readyAt == e.gameClock)
    }

    @Test func revealTimeNotCountedForGold() {
        let (e, clock) = engine()
        clock.type(e, "pengyou")
        clock.wait(e, 3)
        e.cardRevealed(0, at: clock.now)
        let ev = clock.type(e, e.cards[0].word.letters, dt: 0.1)
        #expect(ev.contains(.moveDone(index: 1, gold: true)))
        #expect(e.player.combo == 2)
    }

    @Test func comboBreaksAfterRevealIfIdle() {
        let (e, clock) = engine()
        clock.type(e, "pengyou")
        clock.wait(e, 3)
        e.cardRevealed(0, at: clock.now)
        clock.wait(e, e.comboWindow + 0.1)                 // 露出来以后还不打，照旧断
        #expect(e.player.combo == 0)
    }

    @Test func withoutHoldPressureStartsRightAway() {
        let (e, clock) = engine(hold: false)
        clock.type(e, "pengyou")
        #expect(e.opponent.pressureStart == e.gameClock)
    }
}
