import Testing
@testable import LearningCore

/// 复习：按 1、3、7、16、35 天排；到期打对往后排一档，没到期不变；打错提前到第二天，熟练度不降。
@Suite struct ReviewTests {
    func a(_ day: Int, ok: Bool = true) -> Attempt {
        Attempt(spelling: "shan", at: Double(day), day: day, correct: ok, usedHint: false, startSeconds: 0.5)
    }

    @Test func schedulesByIntervals() {
        var l = Learner()
        l.record([a(1)])
        #expect(l.record(of: "shan").reviewStep == 1)
        #expect(l.record(of: "shan").nextReview == 2)
        l.record([a(2)])
        #expect(l.record(of: "shan").reviewStep == 2)
        #expect(l.record(of: "shan").nextReview == 5)
        l.record([a(3)])                                       // 没到期：不变
        #expect(l.record(of: "shan").nextReview == 5)
    }

    @Test func missMovesReviewToTomorrow() {
        var l = Learner()
        l.record([a(1)])
        l.record([a(2)])
        let before = l.proficiency("shan")
        l.record([a(3, ok: false)])
        #expect(l.record(of: "shan").nextReview == 4)
        #expect(l.proficiency("shan") == before)
    }

    @Test func dueSyllablesAreListed() {
        var l = Learner()
        l.record([a(1)])
        #expect(l.due(on: 1).isEmpty)
        #expect(l.due(on: 2) == ["shan"])
    }
}
