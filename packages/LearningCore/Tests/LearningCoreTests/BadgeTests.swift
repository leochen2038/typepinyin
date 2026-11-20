import Testing
@testable import LearningCore

@Suite struct BadgeTests {
    let r = BadgeRules()

    /// 五条台阶一共 69 级（docs/calendar-badges.md 3.2）。
    @Test func sixtyNineSteps() {
        #expect(BadgeTrack.allCases.map { r.steps($0).count }.reduce(0, +) == 69)
    }

    /// 收集词卡最后一级是「全部」：按词表总数算。
    @Test func cardsReachAll() {
        #expect(r.reached(.cards, value: 9, total: 8376) == 0)
        #expect(r.reached(.cards, value: 1032, total: 8376) == 9)
        #expect(r.reached(.cards, value: 8000, total: 8376) == 15)
        #expect(r.reached(.cards, value: 8376, total: 8376) == 16)
    }

    /// 分段：词卡 10–100 铜、200–750 银、1000–4000 金、5000 以上朱红。
    @Test func bands() {
        #expect(r.band(.cards, 3) == 0)
        #expect(r.band(.cards, 4) == 1)
        #expect(r.band(.cards, 8) == 2)
        #expect(r.band(.cards, 13) == 3)
        #expect(r.band(.books, 10) == 3)
        #expect(r.band(.days, 11) == 2)
        #expect(r.band(.days, 12) == 3)
    }

    /// 合并一天：场数相加；方块按经验最多的那本，一样多取最后打的那本。
    @Test func dayTopVolume() {
        var a = DayLog(day: 1, deviceId: "A", device: "iPhone")
        a.duels = 2; a.xp = ["an": 40, "ai": 40]; a.xpAt = ["an": 10, "ai": 20]
        var b = DayLog(day: 1, deviceId: "B", device: "Mac")
        b.texts = 1
        let s = DaySummary([a, b])
        #expect(s.fights == 3)
        #expect(s.topVolume == "ai")
        #expect(s.devices.count == 2)
    }
}
