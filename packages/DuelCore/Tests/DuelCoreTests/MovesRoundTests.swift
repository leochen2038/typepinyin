import Testing
@testable import DuelCore

/// 一场 10 招：每招点亮一个圆点，第 10 招是金色成语牌，打完就赢。
@Suite struct MovesRoundTests {
    func engine() -> DuelEngine {
        var t = Fixture.threeCards
        t.movesPerDuel = 10
        return Fixture.engine(features: [], tuning: t)
    }

    /// 一直打第一张能打的牌。
    @discardableResult
    func strikeOnce(_ e: DuelEngine, _ clock: FakeClock, dt: Double = 0.1) -> [DuelEvent] {
        let i = e.cards.firstIndex { !$0.inactive }!
        return clock.type(e, e.cards[i].word.letters, dt: dt)
    }

    @Test func eachStrikeIsOneMove() {
        let e = engine()
        let clock = FakeClock()
        let ev = strikeOnce(e, clock)
        #expect(ev.contains(.moveDone(index: 0, gold: true)))
        #expect(e.moveMarks == [true])
        #expect(e.opponent.hp == Int((Double(e.opponent.maxHP) * 0.9).rounded()))
    }

    @Test func slowOrWrongMoveIsNotGold() {
        let e = engine()
        let clock = FakeClock()
        strikeOnce(e, clock, dt: 1.0)
        #expect(e.moveMarks == [false])
        let i = e.cards.firstIndex { !$0.inactive }!
        let w = e.cards[i].word.letters
        clock.type(e, String(w.prefix(1)))
        clock.type(e, "q")                              // 打错一个
        clock.type(e, String(w.dropFirst()))
        #expect(e.moveMarks.last == false)
    }

    @Test func ninthMoveDealsGoldenIdiomAndLocksOthers() {
        let e = engine()
        let clock = FakeClock()
        var finale = false
        for _ in 0..<9 { finale = strikeOnce(e, clock).contains(.finale) || finale }
        #expect(finale)
        let active = e.cards.filter { !$0.inactive }
        #expect(active.count == 1)
        #expect(active[0].isFinisher && active[0].word.isIdiom)
        // 被暂停的牌按首字母也锁不上
        if let idle = e.cards.first(where: \.inactive), idle.word.firstLetter != active[0].word.firstLetter {
            #expect(clock.type(e, String(idle.word.firstLetter)) == [.letterRejected(idle.word.firstLetter)])
        }
    }

    @Test func tenthMoveWins() {
        let e = engine()
        let clock = FakeClock()
        for _ in 0..<10 { strikeOnce(e, clock) }
        #expect(e.phase == .won)
        #expect(e.summary?.movesDone == 10)
        #expect(e.summary?.goldMoves == 10)
    }

    @Test func noQiFinisherDuringFinale() {
        let e = Fixture.engine(features: [.qi], tuning: Fixture.threeCards)
        let clock = FakeClock()
        for _ in 0..<8 { strikeOnce(e, clock) }
        e.player.qi = 99
        strikeOnce(e, clock)
        #expect(e.cards.filter(\.isFinisher).count == 1)
    }
}
