import Testing
@testable import LearningCore

/// 渐进摸底：按杠杆挑族，每族挑对应常用字最多的代表；错两个以上记重点再多探几个。
@Suite struct ProbeTests {
    let c = TestContent.shared

    @Test func leverageSumsCommonCharsOfUnlearned() {
        let l = Learner()
        let fam = "sanpin-shang"
        let expected = c.commonSyllables(in: fam).reduce(0) { $0 + $1.commonChars.count }
        #expect(Probe.leverage(of: fam, learner: l, content: c) == expected)
        var l2 = l
        let top = c.commonSyllables(in: fam).max { $0.commonChars.count < $1.commonChars.count }!
        l2.records[top.spelling] = { var r = SyllableRecord(spelling: top.spelling); r.proficiency = .fluent; return r }()
        #expect(Probe.leverage(of: fam, learner: l2, content: c) == expected - top.commonChars.count)
    }

    @Test func picksTopFamiliesExcludingBase() {
        let fams = Probe.families(learner: Learner(), content: c, count: 3)
        #expect(fams.count == 3)
        #expect(!fams.contains("base"))
        let all = Volumes.all.filter { $0 != "base" }.map { ($0, Probe.leverage(of: $0, learner: Learner(), content: c)) }
        let best = all.sorted { $0.1 > $1.1 }.prefix(3).map(\.0)
        #expect(Set(fams) == Set(best))
    }

    @Test func representativesAreMostCommon() {
        var p = ProbeState()
        let t = LearningTuning()
        let cands = p.candidates(learner: Learner(), content: c, tuning: t)
        #expect(cands.count == t.probeFamilies * t.probePerFamily)
        for fam in Probe.families(learner: Learner(), content: c, count: t.probeFamilies) {
            let reps = c.commonSyllables(in: fam).sorted { $0.commonChars.count > $1.commonChars.count }.prefix(t.probePerFamily).map(\.spelling)
            #expect(Set(reps).isSubset(of: Set(cands)))
        }
        p.note("xiang", correct: true, content: c)
        #expect(!p.candidates(learner: Learner(), content: c, tuning: t).contains("xiang"))   // 探过的不再探
    }

    @Test func twoMissesMakeAFocusFamily() {
        var p = ProbeState()
        let t = LearningTuning()
        let fam = Probe.families(learner: Learner(), content: c, count: t.probeFamilies)[0]
        let reps = c.commonSyllables(in: fam).sorted { $0.commonChars.count > $1.commonChars.count }.map(\.spelling)
        p.note(reps[0], correct: false, content: c)
        p.note(reps[1], correct: false, content: c)
        #expect(p.families[fam]?.focus == true)
        let more = p.candidates(learner: Learner(), content: c, tuning: t).filter { c.volume(of: $0) == fam }
        #expect(more.count == t.probePerFamily - 2 + t.probeFocusExtra)
    }
}
