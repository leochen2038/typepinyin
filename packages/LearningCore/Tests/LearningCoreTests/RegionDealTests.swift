import Testing
@testable import LearningCore

/// 地区里的出字：本卷已会 / 本卷没会 / 复习 / 垫底按配比；没会的受护栏约束。
@Suite struct RegionDealTests {
    let c = TestContent.shared

    func learnerKnowing(_ volumes: [String], dueBefore: Int? = nil) -> Learner {
        var l = Learner()
        for v in volumes {
            for s in c.syllables(in: v) {
                var r = SyllableRecord(spelling: s.spelling)
                r.proficiency = .fluent
                r.correct = 3
                r.nextReview = dueBefore
                l.records[s.spelling] = r
            }
        }
        return l
    }

    @Test func mixFollowsTheRatios() {
        var l = learnerKnowing(["biyin-shang"])
        for (k, v) in learnerKnowing(["base"], dueBefore: 1).records { l.records[k] = v }
        var count: [DealReason: Int] = [:]
        var total = 0
        for seed in 1...10 as ClosedRange<UInt64> {
            let d = Dealer(content: c, learner: l, probe: ProbeState(), context: DealContext(volume: "biyin-shang", today: 5), seed: seed)
            for _ in 0..<20 {
                let w = d.next()
                count[w.reason, default: 0] += 1
                total += 1
                d.note(w.word, clean: true)
            }
        }
        func share(_ r: DealReason) -> Double { Double(count[r] ?? 0) / Double(total) }
        #expect(abs(share(.review) - 0.3) < 0.08, "\(count)")
        #expect(abs(share(.knownInVolume) - 0.6) < 0.08, "\(count)")
        #expect(abs(share(.filler) - 0.1) < 0.08, "\(count)")
    }

    @Test func newOnesAreCappedAndSpaced() {
        let d = Dealer(content: c, learner: learnerKnowing(["base"]), probe: ProbeState(),
                       context: DealContext(volume: "biyin-shang", today: 5), seed: 3)
        var news: [Int] = []
        var total = 0
        for k in 0..<20 {
            let w = d.next()
            if !w.newSyllables.isEmpty { news.append(k) }
            total += w.newSyllables.count
            d.note(w.word, clean: true)
        }
        #expect(total <= LearningTuning().newPerDuel)
        #expect(!news.isEmpty)
        for (a, b) in zip(news, news.dropFirst()) { #expect(b - a > LearningTuning().newGap) }
    }
}
