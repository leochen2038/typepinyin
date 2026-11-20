import Foundation
import LearningCore
import Testing
@testable import ProgressStore

@MainActor
@Suite struct StoreTests {
    func record(_ s: String, _ p: Proficiency, correct: Int = 1, days: [Int] = [1], next: Int? = nil, recentAt: [Double] = [1]) -> SyllableRecord {
        var r = SyllableRecord(spelling: s)
        r.proficiency = p
        r.correct = correct
        r.correctDays = days
        r.nextReview = next
        r.recent = recentAt.map { RecentAttempt(at: $0, counts: true, start: 1) }
        return r
    }

    @Test func savesAndLoadsAStation() throws {
        let store = try ProgressStore(inMemory: true, deviceId: "A")
        var ch = ProgressChange()
        ch.journey = JourneyState(openingDone: true, openingBattle: 3)
        ch.regions["shilipo"] = RegionState(phase: .inProgress, stationIndex: 2, route: Data([1, 2]))
        ch.records = [record("shan", .fluent)]
        ch.speed = SpeedState(secondsPerLetter: 0.4, startSeconds: 1.1, samples: 3)
        try store.save(ch)
        let p = store.load()
        #expect(p.journey.openingDone)
        #expect(p.regions["shilipo"]?.stationIndex == 2)
        #expect(p.regions["shilipo"]?.route == Data([1, 2]))
        #expect(p.records["shan"]?.proficiency == .fluent)
        #expect(p.speed?.secondsPerLetter == 0.4)
    }

    /// 两台设备各写一份，读的时候取「学到的更多」。
    @Test func mergesTwoDevices() throws {
        let store = try ProgressStore(inMemory: true, deviceId: "A")
        var a = ProgressChange()
        a.records = [record("shan", .met, correct: 2, days: [1], next: 9, recentAt: [1, 2])]
        a.volumes["base"] = VolumeState(obtained: true, rank: 2)
        a.regions["shilipo"] = RegionState(phase: .cleared, stationIndex: 0, route: nil)
        a.speed = SpeedState(secondsPerLetter: 0.4, startSeconds: 1, samples: 1)
        try store.save(a)
        var b = ProgressChange()
        b.records = [record("shan", .fluent, correct: 5, days: [2, 3], next: 4, recentAt: [2, 3])]
        b.volumes["base"] = VolumeState(obtained: false, rank: 1)
        b.volumes["biyin-shang"] = VolumeState(obtained: true, rank: 1)
        b.regions["shilipo"] = RegionState(phase: .inProgress, stationIndex: 3, route: nil)
        b.speed = SpeedState(secondsPerLetter: 0.9, startSeconds: 2, samples: 1)
        try store.save(b, asDevice: "B")
        let p = store.load()
        let r = try #require(p.records["shan"])
        #expect(r.proficiency == .fluent)
        #expect(r.correct == 5)
        #expect(r.correctDays == [1, 2, 3])
        #expect(r.nextReview == 4)
        #expect(r.recent.map(\.at) == [1, 2, 3])
        #expect(p.volumes["base"] == VolumeState(obtained: true, rank: 2))
        #expect(p.volumes["biyin-shang"]?.obtained == true)
        #expect(p.regions["shilipo"]?.phase == .cleared)
        #expect(p.speed?.secondsPerLetter == 0.4)          // 速度按设备分开
    }

    /// 打出过的字：两台设备取并集。
    @Test func typedCharsUnion() throws {
        let store = try ProgressStore(inMemory: true, deviceId: "A")
        var a = ProgressChange()
        a.journey = JourneyState(typedChars: ["江", "湖"])
        try store.save(a)
        var b = ProgressChange()
        b.journey = JourneyState(typedChars: ["湖", "大"])
        try store.save(b, asDevice: "B")
        #expect(store.load().journey.typedChars == ["江", "湖", "大"])
    }

    @Test func resetClearsThisDevice() throws {
        let store = try ProgressStore(inMemory: true, deviceId: "A")
        var ch = ProgressChange()
        ch.journey = JourneyState(openingDone: true, openingBattle: 3)
        ch.records = [record("shan", .fluent)]
        try store.save(ch)
        try store.resetAll()
        let p = store.load()
        #expect(!p.journey.openingDone)
        #expect(p.records.isEmpty)
    }

    /// 练功房的词：存下来读得回；两台设备取打得多的那份；清空时一起清掉。
    @Test func practiceWords() throws {
        let store = try ProgressStore(inMemory: true, deviceId: "A")
        var w = PracticeWord(text: "江湖", syllables: ["jiang", "hu"], volume: "sanpin-shang")
        w.note(clean: false, secondsPerLetter: 0.8, at: 10)
        var a = ProgressChange()
        a.practice = [w]
        try store.save(a)
        w.note(clean: true, secondsPerLetter: 0.4, at: 20)
        var b = ProgressChange()
        b.practice = [w]
        try store.save(b, asDevice: "B")
        let got = try #require(store.load().practice["江湖"])
        #expect(got.seen == 2)
        #expect(got.recent == [false, true])
        #expect(got.syllables == ["jiang", "hu"])
        try store.resetAll()
        #expect(store.load().practice["江湖"]?.seen == 2)  // 只清本设备：B 的还在
    }

    @Test func unreadableFileIsKeptAndReplaced() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("progress.store")
        try Data("这不是数据库".utf8).write(to: url)
        let store = try ProgressStore(url: url, deviceId: "A")
        #expect(store.recovered)
        let kept = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.contains("unreadable") }
        #expect(!kept.isEmpty)
        try store.save(ProgressChange())
    }
}

@MainActor
@Suite struct CalendarStoreTests {
    /// 日历：两台设备同一天各记一份，读出来两份都在；同一台再存一次是整份替换。
    @Test func daysKeepOnePerDevice() throws {
        let store = try ProgressStore(inMemory: true, deviceId: "A")
        var a = DayLog(day: 300, deviceId: "A", device: "iPhone")
        a.duels = 2
        var ch = ProgressChange()
        ch.days = [a]
        try store.save(ch)
        a.duels = 3
        try store.save(ch.with(days: [a]))
        var b = DayLog(day: 300, deviceId: "B", device: "Mac")
        b.texts = 1
        try store.save(ProgressChange().with(days: [b]), asDevice: "B")
        let logs = store.load().days[300] ?? []
        #expect(logs.count == 2)
        #expect(DaySummary(logs).duels == 3)
        #expect(DaySummary(logs).fights == 4)
    }

    /// 勋章：同一枚两台设备都拿到，取日期早的那份和它记下的那一刻。
    @Test func badgesKeepEarliest() throws {
        let store = try ProgressStore(inMemory: true, deviceId: "A")
        var ch = ProgressChange()
        ch.badges = [BadgeRecord(track: .cards, step: 2, day: 310, memento: "白菜")]
        try store.save(ch)
        var other = ProgressChange()
        other.badges = [BadgeRecord(track: .cards, step: 2, day: 305, memento: "地图")]
        try store.save(other, asDevice: "B")
        let p = store.load()
        #expect(p.badges["cards:2"]?.day == 305)
        #expect(p.badges["cards:2"]?.memento == "地图")
        try store.resetBadges()
        #expect(store.load().badges["cards:2"]?.day == 305)       // B 的那份还在
    }
}

extension ProgressChange {
    func with(days: [DayLog]) -> ProgressChange {
        var c = self
        c.days = days
        return c
    }
}
