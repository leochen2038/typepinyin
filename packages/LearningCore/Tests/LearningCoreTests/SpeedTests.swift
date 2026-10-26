import Testing
@testable import LearningCore

/// 手速：每场结束按权重滑动更新；没有记录时用这一场的。
@Suite struct SpeedTests {
    @Test func firstDuelSetsIt() {
        let s = PlayerSpeed.updated(nil, secondsPerLetter: 0.5, startSeconds: 1.2, weight: 0.2)
        #expect(s.secondsPerLetter == 0.5)
        #expect(s.startSeconds == 1.2)
        #expect(s.samples == 1)
    }

    @Test func movesByWeight() {
        let s0 = PlayerSpeed(secondsPerLetter: 0.5, startSeconds: 1.0, samples: 3)
        let s = PlayerSpeed.updated(s0, secondsPerLetter: 0.3, startSeconds: 2.0, weight: 0.2)
        #expect(abs(s.secondsPerLetter - 0.46) < 1e-9)
        #expect(abs(s.startSeconds - 1.2) < 1e-9)
        #expect(s.samples == 4)
    }
}
