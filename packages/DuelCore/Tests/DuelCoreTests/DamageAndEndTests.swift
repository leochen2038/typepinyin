import Testing
@testable import DuelCore

/// 伤害和胜负
@Suite struct DamageAndEndTests {
    @Test func baseDamageUsesLettersAndRank() {
        let e = Fixture.engine(features: [])
        var c = e.cards[1]                      // 装修 zhuang xiu = 9 个字母
        c.rank = 0
        #expect(e.baseDamage(c) == 9)
        c.rank = 2
        #expect(abs(e.baseDamage(c) - 10.8) < 1e-9)
    }

    @Test func comboAddsEightPercentPerHit() {
        let e = Fixture.engine(features: [])
        let c = e.cards[1]
        #expect(e.damage(for: c, combo: 1, store: 1) == 9)
        #expect(e.damage(for: c, combo: 6, store: 1) == Int((9 * 1.4).rounded()))
        #expect(e.damage(for: c, combo: 1, store: 2) == 18)
    }

    @Test func opponentHPScalesWithSpeed() {
        let slow = DuelEngine.opponentHP(secondsPerLetter: 0.9, tuning: .standard)
        let fast = DuelEngine.opponentHP(secondsPerLetter: 0.3, tuning: .standard)
        #expect(fast > slow)
        #expect(DuelEngine.opponentHP(secondsPerLetter: 0.45, tuning: .standard) == 119)
        #expect(DuelEngine.opponentHP(secondsPerLetter: 5, tuning: .standard) == 50)
    }

    @Test func winsWhenOpponentHPReachesZero() throws {
        let e = Fixture.engine(features: [])
        e.opponent.hp = 3
        let clock = FakeClock()
        let ev = clock.type(e, "pengyou")
        #expect(ev.contains(.won))
        #expect(e.phase == .won)
        let s = try #require(e.summary)
        #expect(s.won && s.charactersTyped == 2 && s.maxCombo == 1)
    }

    @Test func losesWhenPlayerHPReachesZero() {
        let e = Fixture.engine(features: [.incoming])
        e.player.hp = 10
        e.opponent.nextAttackAt = 0
        let clock = FakeClock()
        clock.wait(e, 0.01)
        let ev = clock.wait(e, 20)
        #expect(ev.contains(.lost))
        #expect(e.phase == .lost)
        #expect(e.summary?.won == false)
    }

    @Test func playerStartsWithFullHP() {
        let e = Fixture.engine()
        #expect(e.player.hp == 100)
    }

    @Test func nothingHappensAfterEnd() {
        let e = Fixture.engine(features: [])
        e.opponent.hp = 1
        let clock = FakeClock()
        clock.type(e, "pengyou")
        #expect(clock.type(e, "g").isEmpty)
    }
}
