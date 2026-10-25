import Testing
@testable import DuelCore

/// 群战：场上最多三个，打蓄力最多的那个并打断它，必杀打全场，倒下一个补一个，打完全部才赢。
@Suite struct GroupTests {
    func engine(total: Int = 5) -> (DuelEngine, FakeClock) {
        var t = Tuning.standard
        t.groupFight = true
        t.groupTotal = total
        let e = Fixture.engine(["朋友"], features: [.incoming, .qi], tuning: t)
        e.startGroup()
        return (e, FakeClock())
    }

    @Test func lineupEndsWithBoss() {
        #expect(DuelEngine.groupLineup(total: 5) == [.minion, .minion, .guardsman, .minion, .boss])
    }

    @Test func threeOnFieldRestQueued() {
        let (e, _) = engine()
        #expect(e.foes.count == 3)
        #expect(e.foeQueue.count == 2)
        #expect(Set(e.foes.map(\.slot)) == [0, 1, 2])
        #expect(e.opponent.hp == e.opponent.maxHP)
    }

    @Test func strikeHitsFullestBarAndResetsIt() {
        let (e, clock) = engine()
        e.foes[1].pressureStart = e.gameClock - e.foes[1].pressureDuration * 0.9   // 第二个快满了
        let id = e.foes[1].id
        clock.type(e, "pengyou", dt: 0.05)
        #expect(e.lastStruck == [id])
        let f = e.foes.first { $0.id == id }!
        #expect(f.hp == f.maxHP - "pengyou".count)
        #expect(f.pressureProgress(at: e.gameClock) < 0.1)
    }

    @Test func downedFoeIsReplacedInSameSlot() {
        let (e, clock) = engine()
        let target = e.foes[0]
        e.foes[0].hp = 1
        e.foes[0].pressureStart = e.gameClock - e.foes[0].pressureDuration * 0.95
        clock.type(e, "pengyou", dt: 0.05)
        #expect(e.lastDowned == [target.id])
        #expect(e.foes.count == 3)
        #expect(e.foes.contains { $0.slot == target.slot && $0.id != target.id })
        #expect(e.foeQueue.count == 1)
    }

    @Test func fullBarHitsPlayerAndBreaksCombo() {
        let (e, clock) = engine()
        e.player.combo = 4
        e.player.lastStrikeAt = e.gameClock
        e.target = .card(0)
        let f = e.foes[0]
        e.foes[0].pressureStart = e.gameClock - f.pressureDuration + 0.01
        let ev = clock.wait(e, 0.05)
        #expect(ev.contains(.foeAttacked(id: f.id, damage: f.tier.hit)))
        #expect(e.player.hp == e.tuning.playerMaxHP - f.tier.hit)
        #expect(e.player.combo == 0)
    }

    @Test func winOnlyAfterEveryone() {
        let (e, clock) = engine(total: 2)
        #expect(e.foes.count == 2)
        for i in e.foes.indices { e.foes[i].hp = 1 }
        clock.type(e, "pengyou", dt: 0.05)
        #expect(e.phase == .fighting)            // 只打倒一个
        e.foes[0].hp = 1
        clock.type(e, e.cards[0].word.letters, dt: 0.05)
        #expect(e.phase == .won)
    }
}
