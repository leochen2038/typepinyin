import Foundation

public enum PauseReason: Sendable, Equatable {
    case background
}

public enum DuelPhase: Sendable, Equatable {
    case ready
    case fighting
    case paused(PauseReason)
    case won
    case lost
}

/// 当前锁定的目标。
public enum Target: Sendable, Equatable {
    case none
    case card(Int)
    case incoming
}

public enum KeyKind: Sendable, Equatable {
    case letter(Character)
    case backspace
    case teach
}

/// 键盘交给引擎的一次按键。时间都是调用方的单调时钟秒数。
public struct KeyEvent: Sendable, Equatable {
    public var kind: KeyKind
    public var downAt: Double
    public var upAt: Double
    public var commitAt: Double
    /// 键盘判定为「按偏了」时，记录本来应该按的字母。
    public var nearMissOf: Character?

    public init(kind: KeyKind, downAt: Double, upAt: Double, commitAt: Double, nearMissOf: Character? = nil) {
        self.kind = kind
        self.downAt = downAt
        self.upAt = upAt
        self.commitAt = commitAt
        self.nearMissOf = nearMissOf
    }

    public static func letter(_ c: Character, at t: Double, nearMissOf: Character? = nil) -> KeyEvent {
        KeyEvent(kind: .letter(c), downAt: t, upAt: t, commitAt: t, nearMissOf: nearMissOf)
    }

    public static func backspace(at t: Double) -> KeyEvent {
        KeyEvent(kind: .backspace, downAt: t, upAt: t, commitAt: t)
    }

    public static func teach(at t: Double) -> KeyEvent {
        KeyEvent(kind: .teach, downAt: t, upAt: t, commitAt: t)
    }
}

/// 引擎发给画面层的事件。画面层只按事件播放演出，不自己判断规则。
public enum DuelEvent: Sendable, Equatable {
    case started
    case locked(Target)
    case letterAccepted(Target, Character)
    case letterRejected(Character)
    case nearMiss(expected: Character)
    case targetCleared
    case strike(card: Int, damage: Int, flaw: Bool, finisher: Bool, heavy: Bool)
    case cardDealt(Int)
    case comboChanged(Int)
    case comboBroken
    case incomingStarted(word: String, duration: Double)
    case blocked
    case parried
    case hitByIncoming(damage: Int)
    /// 群战：一个敌人站上场（id、等级、站位）。
    case foeJoined(id: Int, tier: FoeTier, slot: Int)
    /// 群战：一个敌人蓄力满了出手，玩家掉血。
    case foeAttacked(id: Int, damage: Int)
    /// 群战：一个敌人被打倒。
    case foeDefeated(id: Int)
    /// 对手丢了一条命（跪地再站起来，血条满上），还剩 left 条。
    case lifeLost(left: Int)
    case chargeInterrupted
    case newMove(String)
    case mistake(String, damage: Int)
    case qiFull
    /// 一场按招数计时：第 index 招打完（从 0 起），gold 表示又快又准。
    case moveDone(index: Int, gold: Bool)
    /// 只剩最后一招：补出金色成语牌，其余两张暂停。
    case finale
    /// 卡壳：在键盘上提示下一个字母；hintCleared 时熄灭。
    case hint(Character)
    /// 1 张牌模式：对手开始蓄力（条满之前没打完就出手）。
    case pressureStarted(duration: Double)
    case hintCleared
    case paused(PauseReason)
    case resumed
    case won
    case lost
}

/// 小结卡片的数据，只记收获。
public struct DuelSummary: Sendable, Equatable {
    public var charactersTyped: Int
    public var maxCombo: Int
    public var parries: Int
    public var newMoves: [String]
    public var durationSeconds: Double
    public var won: Bool
    public var movesDone: Int = 0
    public var goldMoves: Int = 0
}
