import Testing
@testable import LearningCore

/// 熟练度：第一次又快又准直接熟练；熟练要隔天打对；看提示不算打对；只升不降。
@Suite struct ProficiencyTests {
    func hit(_ s: String = "shan", day: Int, start: Double = 0.9, ok: Bool = true, hint: Bool = false, at: Double = 0) -> Attempt {
        Attempt(spelling: s, at: at, day: day, correct: ok, usedHint: hint, startSeconds: start)
    }

    @Test func firstTimeFastAndCleanIsFluent() {
        var l = Learner()
        let ch = l.record([hit(day: 1, start: 0.6)])
        #expect(l.proficiency("shan") == .fluent)
        #expect(ch.newlyFluent == ["shan"])
    }

    @Test func firstTimeSlowIsOnlyMet() {
        var l = Learner()
        l.record([hit(day: 1, start: 1.5)])
        #expect(l.proficiency("shan") == .met)
    }

    @Test func fluentNeedsTwoDifferentDays() {
        var l = Learner()
        l.record([hit(day: 1, start: 1.5)])
        l.record([hit(day: 1, start: 1.5), hit(day: 1, start: 1.4)])
        #expect(l.proficiency("shan") == .met)          // 同一天打对多次不算
        l.record([hit(day: 2, start: 1.5)])
        #expect(l.proficiency("shan") == .fluent)       // 隔天再打对，最近 3 次没错、上手 < 2 秒
    }

    @Test func recentMistakeBlocksFluent() {
        var l = Learner()
        l.record([hit(day: 1, start: 1.5), hit(day: 1, start: 1.5, ok: false)])
        l.record([hit(day: 2, start: 1.5)])
        #expect(l.proficiency("shan") == .met)
    }

    @Test func masterAfterFiveFastCleanOnes() {
        var l = Learner()
        l.record([hit(day: 1, start: 0.5)])              // 直接熟练
        l.record((0..<4).map { _ in hit(day: 2, start: 0.7) })
        #expect(l.proficiency("shan") == .master)
    }

    @Test func hintedCorrectDoesNotCount() {
        var l = Learner()
        let ch = l.record([hit(day: 1, start: 0.5, hint: true)])
        #expect(l.proficiency("shan") == .met)
        #expect(ch.newlyFluent.isEmpty)
        l.record([hit(day: 2, start: 1.5, hint: true), hit(day: 3, start: 1.5, hint: true)])
        #expect(l.proficiency("shan") == .met)          // 看提示打对的日子不算
    }

    @Test func firstMissIsNewMove() {
        var l = Learner()
        let ch = l.record([hit("xiong", day: 1, ok: false)])
        #expect(ch.newMoves == ["xiong"])
        #expect(l.proficiency("xiong") == .met)
    }

    @Test func neverGoesDown() {
        var l = Learner()
        l.record([hit(day: 1, start: 0.5)])
        l.record([hit(day: 2, ok: false), hit(day: 2, ok: false)])
        #expect(l.proficiency("shan") == .fluent)
    }

    /// 能打出多少个常用字：只数真打出过的字，不按音节推算；不是常用字的不算。
    @Test func typableCountsOnlyCharsTyped() {
        let c = TestContent.shared
        #expect(c.commonCharCount(in: []) == 0)
        #expect(c.commonCharCount(in: Set("江湖是是")) == 3)
        #expect(c.commonCharCount(in: Set("江湖𠀀")) == 2)
    }
}
