import Foundation

public enum CardWeight: String, Sendable {
    case light = "轻"
    case medium = "中"
    case heavy = "重"
}

public struct MoveCard: Sendable, Equatable {
    public var id: Int
    public var word: Word
    public var typed: String = ""
    public var dealtAt: Double
    /// 被锁定时冻结的蓄势倍数；没锁定时为 nil，按放置时间实时算。
    public var frozenStore: Double?
    public var hasFlaw: Bool = false
    public var isFinisher: Bool = false
    public var rank: Int
    /// 最后一招时其余两张牌暂时不能打。
    public var inactive: Bool = false

    public func weight(_ t: Tuning) -> CardWeight {
        let n = word.letterCount
        if n >= t.heavyLetters { return .heavy }
        if n >= t.mediumLetters { return .medium }
        return .light
    }
}

public struct IncomingAttack: Sendable, Equatable {
    public var word: Word
    public var startedAt: Double
    public var duration: Double
    public var typed: String = ""

    public func progress(at now: Double) -> Double { min(1, max(0, (now - startedAt) / duration)) }
}

public struct OpponentState: Sendable, Equatable {
    public var name: String
    public var title: String
    public var maxHP: Int
    public var hp: Int
    public var nextAttackAt: Double
    public var incoming: IncomingAttack?
    public var stunnedUntil: Double = -1
    /// 命数：还剩几条（算上正在打的这条）、开场几条（1 = 只有一条血）。
    public var lives: Int = 1
    public var maxLives: Int = 1
    /// 1 张牌模式下对手的蓄力：开始时刻和时长。
    public var pressureStart: Double?
    public var pressureDuration: Double = 0

    public func pressureProgress(at now: Double) -> Double {
        guard let s = pressureStart, pressureDuration > 0 else { return 0 }
        return min(1, max(0, (now - s) / pressureDuration))
    }

    public func isStunned(at now: Double) -> Bool { now < stunnedUntil }
}

/// 群战里的敌人分几等：血量、蓄力快慢、打一下多重都不一样（用等级来控制一场多长，不单独调每个人的血）。
public enum FoeTier: Int, Sendable, CaseIterable {
    case minion = 0, guardsman, boss

    public var name: String { ["喽啰", "镖师", "头目"][rawValue] }
    /// 血量 = 单挑时对手血量 × 这个系数。
    var hpFactor: Double { [0.15, 0.3, 0.5][rawValue] }
    /// 蓄力时长的倍数（越大越慢）。
    var pressureFactor: Double { [1.25, 1.0, 0.9][rawValue] }
    /// 蓄力满了打玩家一下掉多少血。
    var hit: Int { [6, 10, 14][rawValue] }
}

/// 群战里场上的一个敌人。slot 是站位（0 离主角最近）。
public struct Foe: Sendable, Equatable {
    public var id: Int
    public var tier: FoeTier
    public var slot: Int
    public var maxHP: Int
    public var hp: Int
    public var pressureStart: Double
    public var pressureDuration: Double

    public func pressureProgress(at now: Double) -> Double {
        guard pressureDuration > 0 else { return 0 }
        return min(1, max(0, (now - pressureStart) / pressureDuration))
    }
}

public struct PlayerState: Sendable, Equatable {
    public var hp: Int
    public var qi: Int = 0
    public var combo: Int = 0
    public var maxCombo: Int = 0
    public var lastStrikeAt: Double?
    /// 滚动平均：每个字母的用时（含上手时间），初始 0.45 秒。
    public var secondsPerLetter: Double = 0.45
    /// 滚动平均：上手时间（牌可打到按下第一个字母）。
    public var reaction: Double?
}

public struct Opponent: Sendable {
    public var name: String
    public var title: String
    public init(name: String, title: String) {
        self.name = name
        self.title = title
    }
}
