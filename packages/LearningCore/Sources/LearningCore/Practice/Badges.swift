import Foundation

/// 勋章的五条台阶（docs/calendar-badges.md 第 3 节）：每上一级拿一枚，拿到不收回，不给经验、不换东西。
public enum BadgeTrack: String, CaseIterable, Codable, Sendable {
    /// 收集词卡：收过的词卡张数。
    case cards
    /// 秘籍收集：掌门盖印的本数；最后一级是当选武林盟主。
    case books
    /// 秘籍等级：十本秘籍一共升了几次级（拿到时的 1 级不算）。
    case levels
    /// 身经百战（原来叫打几场）：打完的场数（比武和文字都算，输了也算，梦里不算）。
    case fights
    /// 日积月累（原来叫来了几天）：练过的天数，不要求连着。
    case days

    /// 台阶名（勋章页每一页的标题）。
    public var name: String {
        switch self {
        case .cards: "收集词卡"
        case .books: "秘籍收集"
        case .levels: "秘籍等级"
        case .fights: "身经百战"
        case .days: "日积月累"
        }
    }
}

/// 一枚勋章：哪条台阶、第几级（从 0 数）、哪天拿到、那一刻记下的东西。
public struct BadgeRecord: Codable, Sendable, Equatable, Hashable {
    public var track: BadgeTrack
    public var step: Int
    public var day: Int
    /// 那一刻：收集词卡记第 N 张是哪个词；秘籍收集记岛（最后一级「盟」）；秘籍等级记「卷|升到几级」；
    /// 打几场记「在哪座岛、打的是谁」那一句；来了几天不记（点开时按那天的日历写）。补发的、不知道的是空的。
    public var memento: String

    public init(track: BadgeTrack, step: Int, day: Int, memento: String = "") {
        self.track = track
        self.step = step
        self.day = day
        self.memento = memento
    }

    public var key: String { Self.key(track, step) }
    public static func key(_ t: BadgeTrack, _ step: Int) -> String { "\(t.rawValue):\(step)" }
}

/// 每条台阶的各级和分段（铜、银、金、朱红）。数在 LearningTuning 里能调。
public struct BadgeRules: Sendable, Equatable {
    /// 各级要到的数。收集词卡最后一级写 0，表示「全部」（按词表总数）。
    public var steps: [BadgeTrack: [Int]]
    /// 每条台阶银、金、朱红从第几级开始（从 0 数）。
    public var cuts: [BadgeTrack: [Int]]

    public static let standardSteps: [BadgeTrack: [Int]] = [
        .cards: [10, 30, 50, 100, 200, 300, 500, 750, 1000, 1500, 2000, 3000, 4000, 5000, 6500, 0],
        .books: Array(1...11),
        .levels: [1, 3, 5, 8, 10, 15, 20, 25, 30, 35, 40],
        .fights: [1, 5, 10, 20, 30, 50, 100, 150, 200, 300, 500, 750, 1000, 1500, 2000],
        .days: [1, 2, 3, 5, 7, 10, 14, 21, 30, 45, 60, 100, 150, 200, 300, 365],
    ]
    public static let standardCuts: [BadgeTrack: [Int]] = [
        .cards: [4, 8, 13], .books: [3, 6, 9], .levels: [3, 6, 9], .fights: [4, 8, 13], .days: [4, 8, 12],
    ]

    public init(steps: [BadgeTrack: [Int]] = standardSteps, cuts: [BadgeTrack: [Int]] = standardCuts) {
        self.steps = steps
        self.cuts = cuts
    }

    /// 从调参里读（缺的、写坏的用默认）。
    public init(tuning t: LearningTuning) {
        var s = Self.standardSteps, c = Self.standardCuts
        for track in BadgeTrack.allCases {
            if let v = t.badgeSteps[track.rawValue], !v.isEmpty { s[track] = v }
            if let v = t.badgeCuts[track.rawValue], v.count == 3 { c[track] = v }
        }
        self.init(steps: s, cuts: c)
    }

    public func steps(_ t: BadgeTrack) -> [Int] { steps[t] ?? [] }

    /// 第 step 级要到的数（「全部」换成 total）。
    public func threshold(_ t: BadgeTrack, _ step: Int, total: Int) -> Int {
        let v = steps(t)[step]
        return v <= 0 ? max(1, total) : v
    }

    /// 走到第几级了（拿到了几枚）：要到的数不超过 value 的级数。
    public func reached(_ t: BadgeTrack, value: Int, total: Int = 0) -> Int {
        steps(t).indices.filter { value >= threshold(t, $0, total: total) }.count
    }

    /// 第 step 级在哪一段：0 铜、1 银、2 金、3 朱红。
    public func band(_ t: BadgeTrack, _ step: Int) -> Int {
        (cuts[t] ?? [99, 99, 99]).filter { step >= $0 }.count
    }
}
