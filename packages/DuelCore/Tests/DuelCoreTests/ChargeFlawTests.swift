import Testing
@testable import DuelCore

/// 蓄势和破绽
@Suite struct ChargeFlawTests {
    @Test func storeGrowsEightPercentPerSecondCappedAtTwo() {
        let e = Fixture.engine(features: [.store])
        let clock = FakeClock()
        clock.wait(e, 6)
        #expect(abs(e.storeMultiplier(ofCard: 0) - 1.48) < 1e-9)
        clock.wait(e, 10)
        #expect(e.storeMultiplier(ofCard: 0) == 2)
    }

    @Test func lockingFreezesStore() {
        let e = Fixture.engine(features: [.store])
        let clock = FakeClock()
        clock.wait(e, 5)
        clock.type(e, "p")
        let frozen = e.storeMultiplier(ofCard: 0)
        clock.wait(e, 3)
        #expect(e.storeMultiplier(ofCard: 0) == frozen)
    }

    @Test func exactlyOneFlawAndItMoves() {
        let e = Fixture.engine(features: [.flaw])
        e.assignFlaw(excluding: nil)
        #expect(e.cards.filter(\.hasFlaw).count == 1)
        let clock = FakeClock()
        let i = e.cards.firstIndex(where: \.hasFlaw)!
        let ev = clock.type(e, e.cards[i].word.letters)
        #expect(ev.contains { if case .strike(card: i, _, true, _, _) = $0 { return true } else { return false } })
        #expect(e.cards.filter(\.hasFlaw).count == 1)
        #expect(!e.cards[i].hasFlaw)
    }

    @Test func flawPrefersReplayThenVolume() {
        let e = Fixture.engine(["装修", "认真", "熊猫"], features: [.flaw, .teaching])
        e.assignFlaw(excluding: nil)
        #expect(e.cards[1].hasFlaw)                    // 本卷的词
        e.learner.replayQueue = [(deal: 99, syllable: "xiong")]
        e.assignFlaw(excluding: nil)
        #expect(e.cards[2].hasFlaw)                    // 待复现优先
    }

    @Test func flawMultipliesDamageAndQi() {
        let e = Fixture.engine(features: [.flaw, .qi])
        var c = e.cards[1]
        c.hasFlaw = false
        let plain = e.damage(for: c, combo: 1, store: 1)
        c.hasFlaw = true
        #expect(e.damage(for: c, combo: 1, store: 1) == Int((Double(plain) * 1.5).rounded()))
        for k in e.cards.indices { e.cards[k].hasFlaw = (k == 0) }
        let clock = FakeClock()
        clock.type(e, "pengyou")
        #expect(e.player.qi == 5 + 1 + 10)
    }
}
