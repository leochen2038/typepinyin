import Testing
@testable import LearningCore

/// 初入江湖和第一关的牌：每个字都只用第一卷的 30 个音节，不管奇遇里碰到过什么、也不探；必杀也一样。
@Suite struct FirstLevelCardsTests {
    let c = TestContent.shared

    @Test func everyCardUsesOnlyCoreSyllables() {
        var l = Learner()
        for s in ["jie", "xin", "shan", "yi", "qu", "san"] {      // 奇遇里碰到过的
            var r = SyllableRecord(spelling: s)
            r.proficiency = .met
            r.nextReview = 1
            l.records[s] = r
        }
        for (i, lengths) in [[2: 1.0], [2: 0.85, 3: 0.15], [2: 0.55, 3: 0.25, 4: 0.2], [3: 0.4, 4: 0.35, 5: 0.25]].enumerated() {
            // 葫芦集（volume base）和初入江湖（volume nil）都一样
            let d = Dealer(content: c, learner: l, probe: ProbeState(),
                           context: DealContext(volume: i % 2 == 0 ? "base" : nil, today: 5, lengths: lengths,
                                                allowedSyllables: Volumes.baseCore),
                           seed: UInt64(i + 1))
            for _ in 0..<60 {
                let w = d.next()
                #expect(w.word.syllables.allSatisfy { Volumes.baseCore.contains($0) }, "\(w.word.text)")
                d.note(w.word, clean: true)
            }
            let f = d.nextIdiom()
            #expect(f.syllables.allSatisfy { Volumes.baseCore.contains($0) }, "必杀 \(f.text)")
        }
    }
}
