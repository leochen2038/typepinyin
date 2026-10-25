import Testing
@testable import DuelCore

/// 一次只出一张牌：没有挑牌、破绽、来招；对手蓄力条满之前没打完就出手。
@Suite struct SingleCardTests {
    func engine(_ features: DuelEngine.Features = .all) -> DuelEngine {
        let e = DuelEngine(bank: Fixture.bank, tuning: .standard, opponent: .init(name: "林大", title: "镖师"), seed: 3, features: features)
        e.start(at: 100)
        return e
    }

    @Test func dealsOneCardWithoutFlaw() {
        let e = engine()
        #expect(e.cards.count == 1)
        #expect(!e.cards[0].hasFlaw)
        #expect(e.opponent.nextAttackAt == .infinity)      // 没有单独的来招
        #expect(e.opponent.pressureStart != nil)
    }

    @Test func pressureDurationScalesWithWord() {
        let e = engine()
        let n = Double(e.cards[0].word.letterCount)
        #expect(abs(e.opponent.pressureDuration - max(3.0, n * 0.45 * 2.4 + 1.5)) < 1e-9)
    }

    @Test func finishingInTimeRestartsPressureForNextCard() {
        let e = engine()
        let clock = FakeClock()
        let ev = clock.type(e, e.cards[0].word.letters)
        #expect(ev.contains { if case .pressureStarted = $0 { return true } else { return false } })
        #expect(e.player.hp == 100)
    }

    @Test func tooSlowGetsHitAndKeepsTypedLetters() {
        let e = engine([.incoming])
        let clock = FakeClock()
        let w = e.cards[0].word.letters
        clock.type(e, String(w.prefix(2)))
        let ev = clock.wait(e, e.opponent.pressureDuration + 0.1)
        #expect(ev.contains(.hitByIncoming(damage: 10)))
        #expect(e.player.hp == 90)
        #expect(e.cards[0].typed == String(w.prefix(2)))
    }
}
