import Testing
@testable import LearningCore

/// 重数：拿到 → 一重；一半常用音节熟练 → 二重、全部 → 三重、一半精通 → 四重、全部 → 五重；只升不降。
@Suite struct RankTests {
    let c = TestContent.shared
    let vol = "biyin-shang"

    func learner(fluent: Double, master: Double = 0) -> Learner {
        var l = Learner()
        let common = c.commonSyllables(in: vol).map(\.spelling).sorted()
        for (i, s) in common.enumerated() {
            var r = SyllableRecord(spelling: s)
            let k = Double(i) / Double(common.count)
            r.proficiency = k < master ? .master : k < fluent ? .fluent : .met
            l.records[s] = r
        }
        return l
    }

    @Test func notObtainedIsZero() {
        #expect(learner(fluent: 1).rank(of: vol, obtained: false, previous: 0, content: c) == 0)
    }

    @Test func ladder() {
        #expect(learner(fluent: 0).rank(of: vol, obtained: true, previous: 0, content: c) == 1)
        #expect(learner(fluent: 0.5).rank(of: vol, obtained: true, previous: 0, content: c) == 2)
        #expect(learner(fluent: 1).rank(of: vol, obtained: true, previous: 0, content: c) == 3)
        #expect(learner(fluent: 1, master: 0.5).rank(of: vol, obtained: true, previous: 0, content: c) == 4)
        #expect(learner(fluent: 1, master: 1).rank(of: vol, obtained: true, previous: 0, content: c) == 5)
    }

    @Test func neverGoesDown() {
        #expect(learner(fluent: 0).rank(of: vol, obtained: true, previous: 3, content: c) == 3)
    }

    @Test func progressBetweenZeroAndOne() {
        let l = learner(fluent: 0.25)
        let p = l.rankProgress(of: vol, rank: 1, content: c)
        #expect(p > 0.3 && p < 0.7)
        #expect(l.rankProgress(of: vol, rank: 5, content: c) == 1)
    }

    @Test func uncommonSyllablesDontCount() {
        var l = learner(fluent: 1)
        for s in c.syllables(in: vol) where !s.isCommon { l.records[s.spelling] = nil }
        #expect(l.rank(of: vol, obtained: true, previous: 0, content: c) == 3)
    }
}
