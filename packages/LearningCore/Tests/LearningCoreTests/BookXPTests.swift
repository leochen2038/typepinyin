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
        #expect(BookXP.level(0) == 1)
        #expect(BookXP.level(99) == 1)
        #expect(BookXP.level(100) == 2)
        #expect(BookXP.level(499) == 2)
        #expect(BookXP.level(1100) == 4)
        #expect(BookXP.level(99_999) == 5)
    }

    @Test func progressWithinLevel() {
        #expect(BookXP.progress(0) == 0)
        #expect(BookXP.progress(300) == 0.5)          // 2 级：100…500
        #expect(BookXP.progress(5000) == 1)
    }

    /// 旧存档的等级补经验后，等级不掉。
    @Test func seedKeepsRank() {
        for r in 1...5 { #expect(BookXP.level(BookXP.seed(rank: r)) == r) }
    }
}
