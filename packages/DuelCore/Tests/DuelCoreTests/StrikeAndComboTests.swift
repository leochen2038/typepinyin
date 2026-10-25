import Testing
@testable import DuelCore

/// 出招和连招
@Suite struct StrikeAndComboTests {
    @Test func comboGrowsInsideWindow() {
        let e = Fixture.engine(["朋友", "装修", "光明"], features: [])
        let clock = FakeClock()
        clock.type(e, "pengyou")
        #expect(e.player.combo == 1)
        clock.now += 0.5
        clock.type(e, "zhuangxiu")
        #expect(e.player.combo == 2)
        #expect(e.player.maxCombo == 2)
    }

    @Test func comboBreaksWhenWaitingTooLong() {
        let e = Fixture.engine(features: [])
        let clock = FakeClock()
        clock.type(e, "pengyou")
        let ev = clock.wait(e, 2.7)
        #expect(ev.contains(.comboBroken))
        #expect(e.player.combo == 0)
    }

    @Test func comboBreaksWhenStartingLate() {
        let e = Fixture.engine(features: [])
        let clock = FakeClock()
        clock.type(e, "pengyou")
        clock.now += 3
        let ev = clock.type(e, "g")                 // 晚于窗口才开始打
        #expect(ev.contains(.comboBroken))
    }

    @Test func windowStartsAt2_6AndShrinksButNotBelowMin() {
        let e = Fixture.engine(features: [])
        #expect(e.comboWindow == 2.6)
        e.player.reaction = 0.2
        #expect(abs(e.comboWindow - 1.0) < 1e-9)       // 1.7 × 0.2 + 0.4 = 0.74 → 下限 1.0
        e.player.reaction = 0.8
        #expect(abs(e.comboWindow - 1.76) < 1e-9)
        e.player.reaction = 3
        #expect(e.comboWindow == 2.6)
    }

    @Test func strikeUpdatesSpeedAverages() {
        let e = Fixture.engine(features: [])
        let clock = FakeClock()
        clock.type(e, "pengyou", dt: 0.2)
        #expect(e.player.reaction != nil)
        #expect(e.player.secondsPerLetter != 0.45)
    }
}
