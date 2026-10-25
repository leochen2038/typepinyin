import Testing
@testable import DuelCore

/// 没学过的音节打错：出「新招」，不罚、不暂停（拆招卡已删），排进复习：接下来第 2、5 张牌再出现。
@Suite struct NewMoveTests {
    @Test func newSyllableMissIsNewMoveAndQueuedForReplay() {
        let e = Fixture.engine(["熊猫", "装修", "光明"], features: [.teaching])
        let clock = FakeClock()
        clock.type(e, "x")
        let ev = clock.type(e, "a")                     // xiong 打错
        #expect(ev.contains(.newMove("xiong")))
        #expect(e.phase == .fighting)
        #expect(e.player.hp == e.tuning.playerMaxHP)
        #expect(e.learner.replayQueue.filter { $0.syllable == "xiong" }.count == e.tuning.replayOffsets.count)
        let again = clock.type(e, "q")                  // 再错不重复出新招、也不重复排
        #expect(!again.contains(.newMove("xiong")))
        #expect(e.learner.replayQueue.filter { $0.syllable == "xiong" }.count == e.tuning.replayOffsets.count)
    }
}
