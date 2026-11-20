import Testing
@testable import LearningCore

/// 秘籍的经验和等级
@Suite struct BookXPTests {
    @Test func gainRewardsCleanFastAndNew() {
        #expect(BookXP.gain(clean: false, perfect: false, new: false) == 1)
        #expect(BookXP.gain(clean: true, perfect: false, new: false) == 2)
        #expect(BookXP.gain(clean: true, perfect: true, new: false) == 3)
        #expect(BookXP.gain(clean: true, perfect: true, new: true) == 5)
        #expect(BookXP.gain(clean: false, perfect: true, new: false) == 1)   // 打错了不算完美
    }

    @Test func levelsFollowThresholds() {
        let t = BookXP.thresholds
        #expect(BookXP.level(0) == 1)
        #expect(BookXP.level(t[1] - 1) == 1)
        #expect(BookXP.level(t[1]) == 2)
        #expect(BookXP.level(t[2] - 1) == 2)
        #expect(BookXP.level(t[3]) == 4)
        #expect(BookXP.level(99_999) == 5)
    }

    @Test func progressWithinLevel() {
        let t = BookXP.thresholds
        #expect(BookXP.progress(0) == 0)
        #expect(BookXP.progress((t[1] + t[2]) / 2) == 0.5)
        #expect(BookXP.progress(99_999) == 1)
    }

    @Test func defaultsMatchTuning() {
        #expect(LearningTuning().bookXPThresholds == BookXP.standard)
    }

    /// 旧存档的等级补经验后，等级不掉。
    @Test func seedKeepsRank() {
        for r in 1...5 { #expect(BookXP.level(BookXP.seed(rank: r)) == r) }
    }
}
