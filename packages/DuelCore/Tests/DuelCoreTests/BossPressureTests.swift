import Testing
@testable import DuelCore

/// 掌门蓄力打不断（试玩）：打完一张牌只往回推一截，必杀清零，满了照打。
@Suite struct BossPressureTests {
    func engine(lives: Int = 3, on: Bool = true) -> DuelEngine {
        var t = Tuning.standard
        t.foeLives = lives
        t.bossPressure = on
        let e = DuelEngine(bank: Fixture.bank, tuning: t, opponent: .init(name: "掌门", title: "掌门"), seed: 3, features: .all)
        e.start(at: 100)
        return e
    }

    @Test func onlyWithThreeOrMoreLives() {
        #expect(engine().bossMode)
        #expect(!engine(lives: 1).bossMode)
        #expect(!engine(on: false).bossMode)
    }

    @Test func finishingACardOnlyPushesBack() {
        let e = engine()
        let start = e.opponent.pressureStart!
        let d = e.opponent.pressureDuration
        #expect(abs(d - e.bossCycleSeconds) < 1e-9)
        let clock = FakeClock()
        let ev = clock.type(e, e.cards[0].word.letters)
        #expect(!ev.contains { if case .pressureStarted = $0 { return true } else { return false } })
        #expect(abs(e.opponent.pressureStart! - min(e.gameClock, start + 0.2 * d)) < 1e-9)
    }

    @Test func fullBarHitsWithBossDamage() {
        let e = engine()
        let ev = FakeClock().wait(e, e.opponent.pressureDuration + 0.1)
        #expect(ev.contains(.hitByIncoming(damage: 8)))
        #expect(e.player.hp == 100 - 8)
    }

    @Test func finisherInterrupts() throws {
        let e = engine()
        e.player.qi = 95
        let clock = FakeClock()
        clock.type(e, e.cards[0].word.letters)
        let found = e.cards.filter(\.isFinisher).first
        let card = try #require(found)
        let ev = clock.type(e, card.word.letters)
        #expect(ev.contains(.chargeInterrupted))
        #expect(ev.contains { if case .pressureStarted = $0 { return true } else { return false } })
    }
}
