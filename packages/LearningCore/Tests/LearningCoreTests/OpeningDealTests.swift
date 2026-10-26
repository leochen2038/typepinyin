import Testing
@testable import LearningCore

/// 初入江湖的出字：已会的高频字为主，每场 2–3 个摸底音节且不连着出；刚错过出会的；打对率低时少出新的。
@Suite struct OpeningDealTests {
    let c = TestContent.shared

    func dealer(seed: UInt64 = 1) -> Dealer {
        Dealer(content: c, learner: Learner(), probe: ProbeState(), context: DealContext(volume: nil, today: 1), seed: seed)
    }

    @Test func mostlyEasyWithAFewSpacedProbes() {
        for seed in 1...5 as ClosedRange<UInt64> {
            let d = dealer(seed: seed)
            var news: [Int] = []
            for k in 0..<12 {
                let w = d.next()
                if w.newSyllables.count > 0 { news.append(k) }
                d.note(w.word, clean: true)
            }
            #expect((2...3).contains(news.count), "seed \(seed): \(news)")
            for (a, b) in zip(news, news.dropFirst()) { #expect(b - a > LearningTuning().newGap) }
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
