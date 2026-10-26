import Testing
@testable import LearningCore

/// 每天新学的音节有上限；满了以后这一天不再出没会的。
@Suite struct DailyLimitTests {
    let c = TestContent.shared

    func newCount(newToday: Int) -> Int {
        let d = Dealer(content: c, learner: Learner(), probe: ProbeState(),
                       context: DealContext(volume: "biyin-shang", today: 3, newToday: newToday), seed: 4)
        var n = 0
        for _ in 0..<20 { let w = d.next(); n += w.newSyllables.count; d.note(w.word, clean: true) }
        return n
    }

    @Test func capStopsNewOnes() {
        #expect(newCount(newToday: LearningTuning().newPerDay) == 0)
        #expect(newCount(newToday: 0) > 0)
    }

    @Test func dealerCountsWhatItIntroduced() {
        let d = Dealer(content: c, learner: Learner(), probe: ProbeState(),
                       context: DealContext(volume: "biyin-shang", today: 3, newToday: 0), seed: 4)
        var n = 0
        for _ in 0..<20 { let w = d.next(); n += w.newSyllables.count; d.note(w.word, clean: true) }
        #expect(d.context.newToday == n)
    }
}
