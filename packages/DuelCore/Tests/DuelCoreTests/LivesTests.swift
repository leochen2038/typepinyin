import Testing
@testable import DuelCore

/// 命数（试玩）：打空一条血扣一条命、血条满上，打空最后一条才赢。
@Suite struct LivesTests {
    static func lives(_ n: Int, finisherTakes: Bool = false) -> Tuning {
        var t = Fixture.hpMode
        t.foeLives = n
        t.finisherTakesLife = finisherTakes
        t.finisherShare = 0.25
        return t
    }

    @Test func defaultIsOneLife() {
        #expect(Tuning.standard.foeLives == 1)
        let e = Fixture.engine(features: [])
        #expect(e.opponent.lives == 1 && e.opponent.maxLives == 1)
    }

    /// 每条命都和单挑的对手一样厚（掌门战就是要长），必杀照样打掉这条命的 finisherShare。
    @Test func eachLifeHasFullHP() {
        let plain = Fixture.engine(features: [])
        let e = Fixture.engine(features: [], tuning: Self.lives(3))
        #expect(e.opponent.lives == 3)
        #expect(e.opponent.maxHP == plain.opponent.maxHP)
        var card = e.cards[0]
        card.isFinisher = true
        #expect(e.damage(for: card, combo: 1, store: 1) == Int((Double(e.opponent.maxHP) * 0.25).rounded()))
    }

    /// 每个对手的血量倍数（内容里定）：一条命和多条命都按它，必杀照样打这条命满血的 25%。
    @Test func perFoeHPFactor() {
        let plain = Fixture.engine(features: [])
        var setup = DuelSetup()
        setup.hpFactor = 1.4
        for lives in [1, 3] {
            setup.lives = lives
            let e = DuelEngine(bank: Fixture.bank, tuning: Self.lives(lives), opponent: Opponent(name: "林大", title: ""), seed: 1, setup: setup)
            e.start(at: 100)
            #expect(e.opponent.maxHP == Int((Double(plain.opponent.maxHP) * 1.4).rounded()))
            var card = e.cards[0]
            card.isFinisher = true
            #expect(e.damage(for: card, combo: 1, store: 1) == Int((Double(e.opponent.maxHP) * 0.25).rounded()))
        }
    }

    @Test func emptyingABarCostsALifeAndOverflowCarries() {
        let e = Fixture.engine(features: [], tuning: Self.lives(3))
        e.opponent.hp = 2
        let dmg = e.damage(for: e.cards[0], combo: 1, store: 1)
        let ev = FakeClock().type(e, "pengyou", dt: 1)
        #expect(ev.contains(.lifeLost(left: 2)))
        #expect(e.opponent.lives == 2)
        #expect(e.opponent.hp == e.opponent.maxHP - (dmg - 2))
        #expect(e.phase == .fighting)
    }

    @Test func lastBarEmptyWins() {
        let e = Fixture.engine(features: [], tuning: Self.lives(3))
        e.opponent.lives = 1
        e.opponent.hp = 1
        let ev = FakeClock().type(e, "pengyou", dt: 1)
        #expect(ev.contains(.won))
        #expect(!ev.contains(.lifeLost(left: 0)))
    }

    @Test func finisherTakesLifeWhenSwitchOn() throws {
        let e = Fixture.engine(features: [.qi], tuning: Self.lives(3, finisherTakes: true))
        e.player.qi = 95
        let clock = FakeClock()
        clock.type(e, "pengyou", dt: 1)
        let found = e.cards.filter(\.isFinisher).first
        let card = try #require(found)
        let ev = clock.type(e, card.word.letters, dt: 1)
        #expect(ev.contains(.lifeLost(left: 2)))
        #expect(e.opponent.hp == e.opponent.maxHP)
    }

    /// 丢了命，对手蓄力变快。
    @Test func pressureSpeedsUpAfterLostLife() {
        let e = Fixture.engine(features: [], tuning: Self.lives(3))
        #expect(e.lifePressureFactor == 1)
        e.opponent.lives = 2
        #expect(abs(e.lifePressureFactor - 0.9) < 1e-9)
    }
}
