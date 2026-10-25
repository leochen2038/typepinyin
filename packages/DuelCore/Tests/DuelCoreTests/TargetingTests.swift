import Testing
@testable import DuelCore

/// 锁定目标
@Suite struct TargetingTests {
    @Test func firstLetterLocksMatchingCardAndStrikes() {
        let e = Fixture.engine(features: [])
        let clock = FakeClock()
        let ev = clock.type(e, "z")
        #expect(e.target == .card(1))
        #expect(ev.contains(.locked(.card(1))))
        let hp = e.opponent.hp
        let out = clock.type(e, "huangxiu")
        #expect(out.contains { if case .strike(card: 1, _, _, _, _) = $0 { return true } else { return false } })
        #expect(e.opponent.hp < hp)
        #expect(e.target == .none)
        #expect(out.contains(.cardDealt(1)))
        #expect(e.cards[1].word.text != "装修")
    }

    @Test func rejectedLetterDoesNotChangeState() {
        let e = Fixture.engine(features: [])
        let clock = FakeClock()
        let ev = clock.type(e, "q")
        #expect(ev == [.letterRejected("q")])
        #expect(e.target == .none)
        #expect(e.cards.allSatisfy { $0.typed.isEmpty })
    }

    @Test func wrongLetterOnLockedCardIsNotEntered() {
        let e = Fixture.engine(features: [])
        let clock = FakeClock()
        clock.type(e, "pe")
        clock.type(e, "x")
        #expect(e.cards[0].typed == "pe")
    }

    @Test func backspaceClearsTarget() {
        let e = Fixture.engine(features: [])
        let clock = FakeClock()
        clock.type(e, "zhu")
        clock.now += 0.1
        let ev = e.handle(.backspace(at: clock.now), at: clock.now)
        #expect(ev.contains(.targetCleared))
        #expect(e.target == .none)
        #expect(e.cards[1].typed.isEmpty)
    }

    @Test func spaceIsIgnored() {
        let e = Fixture.engine(features: [])
        let clock = FakeClock()
        let ev = clock.type(e, " ")
        #expect(ev.isEmpty)
    }

    @Test func dealtCardsKeepFirstLettersUnique() {
        let e = Fixture.engine(features: [.incoming])
        let clock = FakeClock()
        for _ in 0..<12 {
            let w = e.cards[0].word.letters
            clock.type(e, w)
            let firsts = e.cards.map(\.word.firstLetter) + (e.opponent.incoming.map { [$0.word.firstLetter] } ?? [])
            #expect(Set(firsts).count == firsts.count)
        }
    }

    @Test func incomingWordAvoidsCardFirstLetters() throws {
        let e = Fixture.engine(features: [.incoming])
        let clock = FakeClock()
        e.opponent.nextAttackAt = 0
        clock.wait(e, 0.01)
        let inc = try #require(e.opponent.incoming)
        #expect(!e.cards.map(\.word.firstLetter).contains(inc.word.firstLetter))
    }
}
