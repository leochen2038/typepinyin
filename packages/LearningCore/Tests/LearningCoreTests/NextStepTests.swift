import Testing
@testable import LearningCore

/// 秘籍页「下一步做到什么就升一级」：说成往前走的一步，不写「还差几次」。
@Suite struct NextStepTests {
    func rec(_ p: Proficiency, days: [Int] = []) -> Learner {
        var r = SyllableRecord(spelling: "shan")
        r.proficiency = p
        r.correctDays = days
        return Learner(records: ["shan": r])
    }

    @Test func steps() {
        #expect(Learner().nextStep(for: "shan")?.text == "打对一次就解锁")
        #expect(rec(.met, days: [1]).nextStep(for: "shan")?.text == "隔一天再打对一次，就熟练了")
        #expect(rec(.met, days: [1, 2]).nextStep(for: "shan")?.text == "再连着打对几次、上手快一点，就熟练了")
        #expect(rec(.fluent, days: [1, 2]).nextStep(for: "shan")?.text == "再连着打对几次、打得更快，就精通了")
        #expect(rec(.master).nextStep(for: "shan") == nil)
    }

    @Test func noCountingDown() {
        for p in Proficiency.allCases {
            let t = rec(p, days: [1]).nextStep(for: "shan")?.text ?? ""
            #expect(!t.contains("还差"))
        }
    }
}
