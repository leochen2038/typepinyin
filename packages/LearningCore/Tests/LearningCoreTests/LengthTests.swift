import Testing
@testable import LearningCore

/// 招式牌的字数按站点来：前面二字为主，中间二到四字，掌门三到五字；凑不出就退回别的字数。
@Suite struct LengthTests {
    let c = TestContent.shared

    func knowsAll() -> Learner {
        var l = Learner()
        for s in c.syllables {
            var r = SyllableRecord(spelling: s.spelling)
            r.proficiency = .fluent
            l.records[s.spelling] = r
        }
        return l
    }

    func lengths(_ weights: [Int: Double], volume: String?, learner: Learner) -> [Int] {
        let d = Dealer(content: c, learner: learner, probe: ProbeState(),
                       context: DealContext(volume: volume, today: 1, lengths: weights), seed: 7)
        var out: [Int] = []
        for _ in 0..<40 { let w = d.next(); out.append(w.word.text.count); d.note(w.word, clean: true) }
        return out
    }

    @Test func twoCharOnlyWhenAsked() {
        #expect(lengths([2: 1], volume: nil, learner: Learner()).allSatisfy { $0 == 2 })
    }

    @Test func bossDealsLongOnes() {
        let l = lengths([3: 0.4, 4: 0.35, 5: 0.25], volume: "biyin-shang", learner: knowsAll())
        #expect(Double(l.filter { $0 >= 3 }.count) / Double(l.count) >= 0.7, "\(l)")
        #expect(l.contains(5))
    }

    /// 第一关凑不出那么多长词：退回二字，不卡住。
    @Test func fallsBackWhenNothingFits() {
        let l = lengths([5: 1], volume: nil, learner: Learner())
        #expect(l.count == 40)
    }
}
