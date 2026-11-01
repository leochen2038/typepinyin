import Testing
@testable import LearningCore

/// 没指定地区、也没有词池时的出字：只出已会的高频字；刚错过出会的。
@Suite struct OpeningDealTests {
    let c = TestContent.shared

    func dealer(seed: UInt64 = 1) -> Dealer {
        Dealer(content: c, learner: Learner(), context: DealContext(volume: nil, today: 1), seed: seed)
    }

    /// 摸底去掉了：没指定地区也没有词池时，只出全是会的音节的词，不带新音节。
    @Test func onlyEasyWords() {
        for seed in 1...5 as ClosedRange<UInt64> {
            let d = dealer(seed: seed)
            for _ in 0..<12 {
                let w = d.next()
                #expect(w.newSyllables.isEmpty)
                d.note(w.word, clean: true)
            }
        }
    }

    @Test func afterAMissNextTwoAreEasy() {
        let d = dealer()
        let first = d.next()
        d.note(first.word, clean: false)
        for _ in 0..<2 {
            let w = d.next()
            #expect(w.newSyllables.isEmpty)
            d.note(w.word, clean: true)
        }
    }

    @Test func lowSuccessRateStopsNewOnes() {
        let d = dealer()
        for _ in 0..<10 { let w = d.next(); d.note(w.word, clean: false) }
        for _ in 0..<6 {
            let w = d.next()
            #expect(w.newSyllables.isEmpty)
            d.note(w.word, clean: true)
        }
    }

    @Test func noRepeatWithinRecentWords() {
        let d = dealer()
        var seen: [String] = []
        for _ in 0..<30 {
            let w = d.next()
            #expect(!seen.suffix(LearningTuning().recentWords).contains(w.word.text))
            seen.append(w.word.text)
            d.note(w.word, clean: true)
        }
    }

    @Test func idiomPrefersKnownSyllables() {
        let d = dealer()
        let i = d.nextIdiom()
        #expect(i.isIdiom)
    }
}
