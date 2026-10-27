import Testing
@testable import LearningCore

/// 第一关减负：基本功只有 30 个核心音节；初入江湖第一场不探，后面每场最多探 1 个。
@Suite struct LightStartTests {
    let c = TestContent.shared

    /// 第一关只有 30 个核心音节；其余的基本功音节按韵母挂到两字诀、省字诀。
    @Test func baseIsTheThirtyCoreSyllables() {
        #expect(Set(c.syllables(in: "base").map(\.spelling)) == Volumes.baseCore)
        #expect(Volumes.classify("ma") == "liangzi-shang")
        #expect(Volumes.classify("zhe") == "liangzi-shang")
        #expect(Volumes.classify("shu") == "liangzi-xia")
        #expect(Volumes.classify("bo") == "liangzi-xia")
        #expect(Volumes.classify("shi") == "shengzi")
        #expect(Volumes.classify("bai") == "liangzi-shang")
    }

    func probes(limit: Int, seed: UInt64) -> Int {
        let d = Dealer(content: c, learner: Learner(), probe: ProbeState(),
                       context: DealContext(volume: nil, today: 1, probeLimit: limit), seed: seed)
        var n = 0
        for _ in 0..<12 { let w = d.next(); if w.reason == .probe { n += 1 }; d.note(w.word, clean: true) }
        return n
    }

    @Test func openingProbeLimits() {
        for seed in 1...5 as ClosedRange<UInt64> {
            #expect(probes(limit: 0, seed: seed) == 0)
            #expect(probes(limit: 1, seed: seed) == 1)
        }
    }
}
