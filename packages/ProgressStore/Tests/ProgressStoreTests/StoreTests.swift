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
