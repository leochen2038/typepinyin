import Testing
@testable import DuelCore

/// 按偏了不扣血、不计打错、不拆招
@Suite struct NearMissTests {
    @Test func nearMissHasNoPenalty() {
        let e = Fixture.engine(["熊猫", "装修", "光明"], features: [.teaching])
        let clock = FakeClock()
        clock.type(e, "x")
        clock.now += 0.1
        let ev = e.handle(.letter("u", at: clock.now, nearMissOf: "i"), at: clock.now)
        #expect(ev == [.nearMiss(expected: "i")])
        #expect(e.learner.missCount["xiong"] == nil)
        #expect(e.phase == .fighting)
        #expect(e.cards[0].typed == "x")
        #expect(e.player.hp == 100)
    }
}
