import Foundation
import LearningCore
import SwiftData

// MARK: - 快照（值类型，App 拿去显示和交给 LearningCore）

public struct JourneyState: Codable, Sendable, Equatable {
    public var openingDone = false
    /// 初入江湖打完了几场。
    public var openingBattle = 0
    /// 看过的入门提示。
    public var tipsSeen: Set<String> = []
    /// 云雾散开演过了。
    public var fogCleared = false
    /// 渐进摸底的状态（LearningCore 编码）。
    public var probe: Data?
    /// 今天新学了几个音节、是哪一天。
    public var newToday = 0
    public var newTodayDay = 0
    /// 打出过的字（牌、奇遇的句子里打完的），「能打出多少个常用字」按它数。
    public var typedChars: Set<String> = []

    public init(openingDone: Bool = false, openingBattle: Int = 0, tipsSeen: Set<String> = [], fogCleared: Bool = false,
                probe: Data? = nil, newToday: Int = 0, newTodayDay: Int = 0, typedChars: Set<String> = []) {
        self.typedChars = typedChars
        self.openingDone = openingDone
        self.openingBattle = openingBattle
        self.tipsSeen = tipsSeen
        self.fogCleared = fogCleared
        self.probe = probe
        self.newToday = newToday
        self.newTodayDay = newTodayDay
    }
}

public struct VolumeState: Codable, Sendable, Equatable {
    public var obtained: Bool
    /// 记过的最高重数。
    public var rank: Int
    public init(obtained: Bool, rank: Int) {
        self.obtained = obtained
        self.rank = rank
    }
}

public enum RegionPhase: String, Codable, Sendable, Comparable {
    case untouched, inProgress, cleared
    var order: Int { switch self { case .untouched: 0; case .inProgress: 1; case .cleared: 2 } }
    public static func < (a: RegionPhase, b: RegionPhase) -> Bool { a.order < b.order }
}

public struct RegionState: Codable, Sendable, Equatable {
    public var phase: RegionPhase
    /// 这一趟走到第几站（下一站的下标）。
    public var stationIndex: Int
    /// 这一趟的路线（LearningCore 编码）。
    public var route: Data?
    public init(phase: RegionPhase, stationIndex: Int, route: Data?) {
        self.phase = phase
        self.stationIndex = stationIndex
        self.route = route
    }
}

public struct SpeedState: Codable, Sendable, Equatable {
    public var secondsPerLetter: Double
    public var startSeconds: Double
    public var samples: Int
    public init(secondsPerLetter: Double, startSeconds: Double, samples: Int) {
        self.secondsPerLetter = secondsPerLetter
        self.startSeconds = startSeconds
        self.samples = samples
    }
}

/// 合并后的全部进度。
public struct Progress: Sendable, Equatable {
    public var journey = JourneyState()
    public var volumes: [String: VolumeState] = [:]
    public var regions: [String: RegionState] = [:]
    public var records: [String: SyllableRecord] = [:]
    /// 本设备的手速（不合并）。
    public var speed: SpeedState?
    /// 练功房：打过的词（按文字）。
    public var practice: [String: PracticeWord] = [:]
    public init() {}
}

/// 一次要存的变化。没给的部分不动。
public struct ProgressChange: Sendable {
    public var journey: JourneyState?
    public var volumes: [String: VolumeState] = [:]
    public var regions: [String: RegionState] = [:]
    public var records: [SyllableRecord] = []
    public var speed: SpeedState?
    public var practice: [PracticeWord] = []
    public init() {}
}

// MARK: - 存储

/// 本机的进度存储。每台设备只写自己的记录，`load()` 把各设备的记录合起来，取「学到的更多」。
@MainActor
public final class ProgressStore {
    public let deviceId: String
    /// 打开时存档读不出，原文件已改名保留，新建了空存储。
    public private(set) var recovered = false
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    static let schema = Schema([DeviceSyllable.self, DeviceVolume.self, DeviceRegion.self, DeviceJourney.self, DeviceSpeed.self, DevicePracticeWord.self])
    static let deviceKey = "progress.deviceId"

    /// - Parameters:
    ///   - url: 存储文件的位置；nil 时用 App 的默认位置。
    ///   - deviceId: 测试用；nil 时用本机偏好里存的（第一次生成）。
    public init(inMemory: Bool = false, url: URL? = nil, deviceId: String? = nil, defaults: UserDefaults = .standard) throws {
        if let deviceId {
            self.deviceId = deviceId
        } else if let saved = defaults.string(forKey: Self.deviceKey) {
            self.deviceId = saved
        } else {
            let id = UUID().uuidString
            defaults.set(id, forKey: Self.deviceKey)
            self.deviceId = id
        }
        if inMemory {
            container = try ModelContainer(for: Self.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            return
        }
        let config = url.map { ModelConfiguration(schema: Self.schema, url: $0) } ?? ModelConfiguration(schema: Self.schema)
        if let c = Self.open(config) {
            container = c
        } else {
            Self.keepUnreadable(config.url)
            container = try ModelContainer(for: Self.schema, configurations: config)
            recovered = true
        }
    }

    /// 打开并试读一次；读不出返回 nil。
    static func open(_ config: ModelConfiguration) -> ModelContainer? {
        guard let c = try? ModelContainer(for: schema, configurations: config),
              (try? c.mainContext.fetchCount(FetchDescriptor<DeviceJourney>())) != nil else { return nil }
        return c
    }

    /// 把读不出的文件（连同 -wal、-shm）加上时间戳改名留着，便于排查。
    static func keepUnreadable(_ url: URL) {
        let fm = FileManager.default
        let stamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-wal", "-shm"] {
            let src = URL(fileURLWithPath: url.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = URL(fileURLWithPath: url.deletingPathExtension().path + ".unreadable-\(stamp).\(url.pathExtension)" + suffix)
            try? fm.moveItem(at: src, to: dst)
        }
    }

    // MARK: 读

    public func load() -> Progress {
        var p = Progress()
        let syl = (try? context.fetch(FetchDescriptor<DeviceSyllable>())) ?? []
        for row in syl {
            let r = Self.record(from: row)
            p.records[r.spelling] = p.records[r.spelling].map { Self.merge($0, r) } ?? r
        }
        for row in (try? context.fetch(FetchDescriptor<DeviceVolume>())) ?? [] {
            let v = VolumeState(obtained: row.obtained, rank: row.rank)
            if let old = p.volumes[row.volume] {
                p.volumes[row.volume] = VolumeState(obtained: old.obtained || v.obtained, rank: max(old.rank, v.rank))
            } else {
                p.volumes[row.volume] = v
            }
        }
        for row in (try? context.fetch(FetchDescriptor<DeviceRegion>())) ?? [] {
            let r = RegionState(phase: RegionPhase(rawValue: row.phase) ?? .untouched, stationIndex: row.stationIndex, route: row.routeData)
            guard let old = p.regions[row.regionId] else { p.regions[row.regionId] = r; continue }
            if r.phase != old.phase {
                p.regions[row.regionId] = r.phase > old.phase ? r : old
            } else if r.stationIndex > old.stationIndex {
                p.regions[row.regionId] = r
            }
        }
        for row in (try? context.fetch(FetchDescriptor<DeviceJourney>())) ?? [] {
            let j = Self.journey(from: row)
            p.journey = Self.merge(p.journey, j)
        }
        for row in (try? context.fetch(FetchDescriptor<DevicePracticeWord>())) ?? [] {
            let w = Self.practiceWord(from: row)
            if let old = p.practice[w.text], (old.seen, old.lastSeen) >= (w.seen, w.lastSeen) { continue }   // 两台设备取打得多的那份
            p.practice[w.text] = w
        }
        let me = deviceId
        p.speed = (try? context.fetch(FetchDescriptor<DeviceSpeed>(predicate: #Predicate { $0.deviceId == me })))?.first
            .map { SpeedState(secondsPerLetter: $0.secondsPerLetter, startSeconds: $0.startSeconds, samples: $0.samples) }
        return p
    }

    // MARK: 写

    public func save(_ change: ProgressChange) throws {
        try save(change, asDevice: deviceId)
    }

    /// 测试用：以另一台设备的身份写。
    func save(_ change: ProgressChange, asDevice dev: String) throws {
        if let j = change.journey {
            let row = try fetchOne(DeviceJourney.self, #Predicate { $0.deviceId == dev }) ?? insert(DeviceJourney(deviceId: dev))
            row.openingDone = j.openingDone
            row.openingBattle = j.openingBattle
            row.tipsSeenData = try? JSONEncoder().encode(j.tipsSeen.sorted())
            row.fogCleared = j.fogCleared
            row.probeData = j.probe
            row.newToday = j.newToday
            row.newTodayDay = j.newTodayDay
            row.typedCharsData = try? JSONEncoder().encode(j.typedChars.sorted())
            row.updatedAt = Date()
        }
        for (v, s) in change.volumes {
            let row = try fetchOne(DeviceVolume.self, #Predicate { $0.deviceId == dev && $0.volume == v }) ?? insert(DeviceVolume(deviceId: dev, volume: v))
            row.obtained = row.obtained || s.obtained
            row.rank = max(row.rank, s.rank)
        }
        for (id, s) in change.regions {
            let row = try fetchOne(DeviceRegion.self, #Predicate { $0.deviceId == dev && $0.regionId == id }) ?? insert(DeviceRegion(deviceId: dev, regionId: id))
            let old = RegionPhase(rawValue: row.phase) ?? .untouched
            row.phase = max(old, s.phase).rawValue       // 状态不回退（再去一趟时保持 cleared）
            row.stationIndex = s.stationIndex
            row.routeData = s.route
        }
        for r in change.records {
            let sp = r.spelling
            let row = try fetchOne(DeviceSyllable.self, #Predicate { $0.deviceId == dev && $0.spelling == sp }) ?? insert(DeviceSyllable(deviceId: dev, spelling: sp))
            row.proficiency = max(row.proficiency, r.proficiency.rawValue)
            row.correct = r.correct
            row.wrong = r.wrong
            row.recentData = try? JSONEncoder().encode(r.recent)
            row.correctDaysData = try? JSONEncoder().encode(r.correctDays)
            row.lastSeen = r.lastSeen
            row.reviewStep = r.reviewStep
            row.nextReview = r.nextReview
        }
        for w in change.practice {
            let t = w.text
            let row = try fetchOne(DevicePracticeWord.self, #Predicate { $0.deviceId == dev && $0.text == t }) ?? insert(DevicePracticeWord(deviceId: dev, text: t))
            row.syllablesData = try? JSONEncoder().encode(w.syllables)
            row.volume = w.volume
            row.seen = w.seen
            row.clean = w.clean
            row.recentData = try? JSONEncoder().encode(w.recent)
            row.secondsPerLetter = w.secondsPerLetter
            row.lastSeen = w.lastSeen
        }
        if let s = change.speed {
            let row = try fetchOne(DeviceSpeed.self, #Predicate { $0.deviceId == dev }) ?? insert(DeviceSpeed(deviceId: dev))
            row.secondsPerLetter = s.secondsPerLetter
            row.startSeconds = s.startSeconds
            row.samples = s.samples
            row.updatedAt = Date()
        }
        try context.save()
    }

    /// 清空本设备的全部记录。
    public func resetAll() throws {
        let me = deviceId
        try context.delete(model: DeviceSyllable.self, where: #Predicate { $0.deviceId == me })
        try context.delete(model: DeviceVolume.self, where: #Predicate { $0.deviceId == me })
        try context.delete(model: DeviceRegion.self, where: #Predicate { $0.deviceId == me })
        try context.delete(model: DeviceJourney.self, where: #Predicate { $0.deviceId == me })
        try context.delete(model: DeviceSpeed.self, where: #Predicate { $0.deviceId == me })
        try context.delete(model: DevicePracticeWord.self, where: #Predicate { $0.deviceId == me })
        try context.save()
    }

    // MARK: 工具

    func fetchOne<T: PersistentModel>(_ type: T.Type, _ p: Predicate<T>) throws -> T? {
        var d = FetchDescriptor<T>(predicate: p)
        d.fetchLimit = 1
        return try context.fetch(d).first
    }

    func insert<T: PersistentModel>(_ m: T) -> T {
        context.insert(m)
        return m
    }

    static func record(from row: DeviceSyllable) -> SyllableRecord {
        var r = SyllableRecord(spelling: row.spelling)
        r.proficiency = Proficiency(rawValue: row.proficiency) ?? .locked
        r.correct = row.correct
        r.wrong = row.wrong
        r.recent = row.recentData.flatMap { try? JSONDecoder().decode([RecentAttempt].self, from: $0) } ?? []
        r.correctDays = row.correctDaysData.flatMap { try? JSONDecoder().decode([Int].self, from: $0) } ?? []
        r.lastSeen = row.lastSeen
        r.reviewStep = row.reviewStep
        r.nextReview = row.nextReview
        return r
    }

    static func practiceWord(from row: DevicePracticeWord) -> PracticeWord {
        PracticeWord(text: row.text, syllables: row.syllablesData.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [],
                     volume: row.volume, seen: row.seen, clean: row.clean,
                     recent: row.recentData.flatMap { try? JSONDecoder().decode([Bool].self, from: $0) } ?? [],
                     secondsPerLetter: row.secondsPerLetter, lastSeen: row.lastSeen)
    }

    static func journey(from row: DeviceJourney) -> JourneyState {
        JourneyState(openingDone: row.openingDone, openingBattle: row.openingBattle,
                     tipsSeen: Set(row.tipsSeenData.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []),
                     fogCleared: row.fogCleared, probe: row.probeData, newToday: row.newToday, newTodayDay: row.newTodayDay,
                     typedChars: Set(row.typedCharsData.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []))
    }

    /// 两台设备的同一个音节：熟练度取最高、次数取最大、最近几次按时间合并去重、日子并集、下次复习取最早。
    static func merge(_ a: SyllableRecord, _ b: SyllableRecord) -> SyllableRecord {
        var r = a
        r.proficiency = max(a.proficiency, b.proficiency)
        r.correct = max(a.correct, b.correct)
        r.wrong = max(a.wrong, b.wrong)
        var seen = Set<Double>()
        r.recent = (a.recent + b.recent).sorted { $0.at < $1.at }.filter { seen.insert($0.at).inserted }.suffix(8).map { $0 }
        r.correctDays = Array(Set(a.correctDays + b.correctDays)).sorted().suffix(8).map { $0 }
        r.lastSeen = [a.lastSeen, b.lastSeen].compactMap { $0 }.max()
        r.reviewStep = max(a.reviewStep, b.reviewStep)
        r.nextReview = [a.nextReview, b.nextReview].compactMap { $0 }.min()
        return r
    }

    static func merge(_ a: JourneyState, _ b: JourneyState) -> JourneyState {
        var j = a
        j.openingDone = a.openingDone || b.openingDone
        j.openingBattle = max(a.openingBattle, b.openingBattle)
        j.tipsSeen = a.tipsSeen.union(b.tipsSeen)
        j.fogCleared = a.fogCleared || b.fogCleared
        j.typedChars = a.typedChars.union(b.typedChars)
        j.probe = a.probe ?? b.probe
        if b.newTodayDay > a.newTodayDay {
            j.newToday = b.newToday
            j.newTodayDay = b.newTodayDay
        } else if b.newTodayDay == a.newTodayDay {
            j.newToday = max(a.newToday, b.newToday)
        }
        return j
    }
}
