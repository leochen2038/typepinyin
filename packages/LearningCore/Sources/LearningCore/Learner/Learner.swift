import Foundation

/// 本机日历日：从 2026-01-01 起的天数，由调用方按本机时区算好传入。
public typealias DayIndex = Int

/// 一个音节的熟练度。只升不降。
public enum Proficiency: Int, Codable, Sendable, Comparable, CaseIterable {
    /// 未解锁：还没打对过，也没碰到过。
    case locked = 0
    /// 拆过：碰到过（打对一次，或第一次拼错成了新招，或看着提示打对）。
    case met
    /// 熟练。
    case fluent
    /// 精通。
    case master

    public static func < (a: Proficiency, b: Proficiency) -> Bool { a.rawValue < b.rawValue }
}

/// 一次打字结果：比武或奇遇打完交回来，一个音节一条。
public struct Attempt: Codable, Sendable, Equatable {
    public var spelling: String
    /// 时刻（秒，调用方的时钟）。
    public var at: Double
    public var day: DayIndex
    /// 没打错（看了提示也算没打错，但见 usedHint）。
    public var correct: Bool
    /// 看着键盘提示打的。
    public var usedHint: Bool
    /// 上手时间：从能开始打这个字到按下第一个字母。
    public var startSeconds: Double

    public init(spelling: String, at: Double, day: DayIndex, correct: Bool, usedHint: Bool, startSeconds: Double) {
        self.spelling = spelling
        self.at = at
        self.day = day
        self.correct = correct
        self.usedHint = usedHint
        self.startSeconds = startSeconds
    }

    /// 算作打对：没错、也没看提示。
    public var counts: Bool { correct && !usedHint }
}

/// 最近一次的结果（只留最近几次）。
public struct RecentAttempt: Codable, Sendable, Equatable {
    public var at: Double
    public var counts: Bool
    public var start: Double

    public init(at: Double, counts: Bool, start: Double) {
        self.at = at
        self.counts = counts
        self.start = start
    }
}

/// 一个音节的学习记录（多台设备合并之后的样子）。
public struct SyllableRecord: Codable, Sendable, Equatable {
    public var spelling: String
    public var proficiency: Proficiency = .locked
    public var correct = 0
    public var wrong = 0
    /// 最近几次，旧的在前。
    public var recent: [RecentAttempt] = []
    /// 打对过的日子（升序、不重复，只留最近几个）。
    public var correctDays: [DayIndex] = []
    public var lastSeen: Double?
    /// 复习到第几档（0 = 还没排过）、下次复习的日子。
    public var reviewStep = 0
    public var nextReview: DayIndex?

    public init(spelling: String) { self.spelling = spelling }

    public var seen: Bool { correct + wrong > 0 }
    /// 最快一次的上手时间（最近几次里）。
    public var fastestStart: Double? { recent.filter(\.counts).map(\.start).min() }

    static let keepRecent = 8
    static let keepDays = 8
}

/// 记一场交回来的结果后，有哪些变化（小结卡片、升重判断用）。
public struct LearnerChange: Sendable, Equatable {
    public var newlyMet: [String] = []
    public var newlyFluent: [String] = []
    public var newlyMaster: [String] = []
    /// 第一次碰到就拼错的音节（新招）。
    public var newMoves: [String] = []
    public init() {}
}

/// 学习者：全部音节的学习记录和规则。
public struct Learner: Sendable, Equatable {
    public var records: [String: SyllableRecord]
    public var tuning: LearningTuning

    public init(records: [String: SyllableRecord] = [:], tuning: LearningTuning = LearningTuning()) {
        self.records = records
        self.tuning = tuning
    }

    public func proficiency(_ s: String) -> Proficiency { records[s]?.proficiency ?? .locked }
    public func record(of s: String) -> SyllableRecord { records[s] ?? SyllableRecord(spelling: s) }

    /// 记下一批结果，按顺序处理；返回这次的变化。
    @discardableResult
    public mutating func record(_ attempts: [Attempt]) -> LearnerChange {
        var change = LearnerChange()
        for a in attempts {
            var r = record(of: a.spelling)
            let first = !r.seen
            let before = r.proficiency
            if a.counts { r.correct += 1 } else { r.wrong += 1 }
            r.recent.append(RecentAttempt(at: a.at, counts: a.counts, start: a.startSeconds))
            if r.recent.count > SyllableRecord.keepRecent { r.recent.removeFirst(r.recent.count - SyllableRecord.keepRecent) }
            if a.counts && !r.correctDays.contains(a.day) {
                r.correctDays.append(a.day)
                r.correctDays.sort()
                if r.correctDays.count > SyllableRecord.keepDays { r.correctDays.removeFirst() }
            }
            r.lastSeen = a.at
            r.proficiency = max(before, level(after: r, first: first, attempt: a))
            records[a.spelling] = r
            scheduleReview(a)
            if first && !a.correct { change.newMoves.append(a.spelling) }
            if before < .met && r.proficiency >= .met { change.newlyMet.append(a.spelling) }
            if before < .fluent && r.proficiency >= .fluent { change.newlyFluent.append(a.spelling) }
            if before < .master && r.proficiency == .master { change.newlyMaster.append(a.spelling) }
        }
        return change
    }

    /// 按规则算出的级别（调用方再和原来的取大，保证只升不降）。
    func level(after r: SyllableRecord, first: Bool, attempt a: Attempt) -> Proficiency {
        let t = tuning
        if first && a.counts && a.startSeconds < t.firstFluentStart { return .fluent }
        var p: Proficiency = .met
        func cleanAndFast(_ n: Int, under s: Double) -> Bool {
            let last = r.recent.suffix(n)
            return last.count == n && last.allSatisfy { $0.counts && $0.start < s }
        }
        if r.correctDays.count >= t.fluentDays && cleanAndFast(t.fluentRecent, under: t.fluentStart) { p = .fluent }
        if max(p, r.proficiency) >= .fluent && cleanAndFast(t.masterRecent, under: t.masterStart) { p = .master }
        return p
    }


    /// 学会了多少个音节（拆过及以上）。
    public var learnedCount: Int { records.values.filter { $0.proficiency >= .met }.count }
}
