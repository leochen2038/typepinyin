import Foundation

/// 比武规则引擎。不读系统时间：所有时间由调用方传入（单调时钟秒数）。
/// 每帧：先把排队的按键按 commitAt 依次 `handle`，再 `advance(to:)`。
public final class DuelEngine {
    /// 可单独关掉的机制，方便分故事测试（全部默认开启）。
    public struct Features: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        /// 新招：没学过的音节打错不罚，并排进复习（第 2、5 张牌再出现）。
        public static let teaching = Features(rawValue: 1 << 0)
        public static let store = Features(rawValue: 1 << 1)
        public static let flaw = Features(rawValue: 1 << 2)
        public static let qi = Features(rawValue: 1 << 3)
        public static let incoming = Features(rawValue: 1 << 4)
        public static let all: Features = [.teaching, .store, .flaw, .qi, .incoming]
    }

    public let bank: WordBank
    public let tuning: Tuning
    public let features: Features
    let syllableTable: [String: Syllable]
    var rng: SeededRandom

    public internal(set) var phase: DuelPhase = .ready
    public internal(set) var player: PlayerState
    public internal(set) var opponent: OpponentState
    public internal(set) var cards: [MoveCard] = []
    public internal(set) var target: Target = .none
    public internal(set) var learner: LearnerState
    public internal(set) var summary: DuelSummary?

    // 时间：游戏时间 = 墙上时间 - 开打时刻 - 暂停累计
    var startedAtWall: Double = 0
    var pausedTotal: Double = 0
    var pauseStartedAtWall: Double?
    var clock: Double = 0

    // 发牌
    var dealCount = 0
    var nextCardId = 0
    var wordOrder: [Word] = []
    var wordCursor = 0
    var finisherPending = false

    // 本次目标的计时
    var firstLetterAt: Double?
    var lastAcceptedAt: Double?
    var readyAt: Double = 0

    // 收获统计
    var charactersTyped = 0
    var parries = 0
    var newMoves: [String] = []

    // 按招数计的一场
    public internal(set) var moveMarks: [Bool] = []
    /// 键盘上正在提示的字母。
    public internal(set) var currentHint: Character?
    var wordClean = true
    var hintedBeforeLock = false

    /// 界面会先用回顾牌盖住刚发的新牌时设为 true：新牌的上手计时、连招间隔和对手蓄力都先不走，
    /// 等界面调 `cardRevealed` 才开始（不然回顾演的那一两秒会被算成玩家慢）。
    public var holdNewCards = false
    /// 新牌发了、还被盖着，等界面说露出来了。
    var awaitingReveal = false
    /// 新牌开始被盖着的时刻（群战：露出来时把所有敌人的蓄力往后推这么久）。
    var holdFrom: Double = 0

    // 群战
    /// 场上的敌人。
    public internal(set) var foes: [Foe] = []
    /// 还没上场的敌人。
    var foeQueue: [FoeTier] = []
    var nextFoeId = 1
    /// 单挑时的对手血量，群战里各等级的血量按它乘系数。
    var unitHP = 1
    /// 命数：对手丢了一条命正跪着，到这个时刻才站起来（之前不蓄力）。
    var foeDownUntil: Double = 0
    /// 最近一次出招打中了谁、打倒了谁、补上来了谁（界面按这个演）。
    public internal(set) var lastStruck: [Int] = []
    public internal(set) var lastDowned: [Int] = []
    public internal(set) var lastJoined: [Int] = []

    var events: [DuelEvent] = []

    public init(bank: WordBank, tuning: Tuning = .standard, opponent: Opponent, seed: UInt64 = 1,
                features: Features = .all, learned: Set<String>? = nil) {
        self.bank = bank
        self.tuning = tuning
        self.features = features
        self.syllableTable = bank.syllableTable
        self.rng = SeededRandom(seed: seed)
        self.learner = LearnerState(learned: learned ?? Set(bank.learned))
        self.player = PlayerState(hp: tuning.playerMaxHP)
        self.opponent = OpponentState(name: opponent.name, title: opponent.title, maxHP: 1, hp: 1, nextAttackAt: .infinity)
    }

    // MARK: - 接口

    @discardableResult
    public func start(at now: Double) -> [DuelEvent] {
        events = []
        startedAtWall = now
        pausedTotal = 0
        pauseStartedAtWall = nil
        clock = 0
        phase = .fighting
        player = PlayerState(hp: tuning.playerMaxHP)
        startLives()
        let hp = perLifeHP(Self.opponentHP(secondsPerLetter: player.secondsPerLetter, tuning: tuning))
        opponent.maxHP = hp
        opponent.hp = hp
        opponent.incoming = nil
        opponent.stunnedUntil = -1
        opponent.nextAttackAt = features.contains(.incoming) && !singleCard ? nextAttackDelay() : .infinity
        opponent.pressureStart = nil
        wordOrder = bank.plainWords.shuffled(using: &rng)
        wordCursor = 0
        cards = []
        target = .none
        summary = nil
        readyAt = 0
        moveMarks = []
        wordClean = true
        awaitingReveal = false
        foes = []
        foeQueue = []
        emit(.started)
        for _ in 0..<max(1, tuning.cardsOnTable) { cards.append(makeCard(slot: cards.count)); emit(.cardDealt(cards.count - 1)) }
        assignFlaw(excluding: nil)
        if groupMode { startGroup() } else { startPressure() }
        return flush()
    }

    @discardableResult
    public func handle(_ key: KeyEvent, at commitAt: Double) -> [DuelEvent] {
        events = []
        switch phase {
        case .fighting:
            step(to: gameTime(commitAt))
            if case .fighting = phase { process(key, at: clock) }
        default:
            break
        }
        return flush()
    }

    @discardableResult
    public func advance(to now: Double) -> [DuelEvent] {
        events = []
        if case .fighting = phase { step(to: gameTime(now)) }
        return flush()
    }

    @discardableResult
    public func pause(_ reason: PauseReason, at now: Double) -> [DuelEvent] {
        events = []
        if case .fighting = phase {
            step(to: gameTime(now))
            if case .fighting = phase {
                phase = .paused(reason)
                pauseStartedAtWall = now
                emit(.paused(reason))
            }
        }
        return flush()
    }

    @discardableResult
    public func resume(at now: Double) -> [DuelEvent] {
        events = []
        if case .paused(.background) = phase {
            endPause(at: now)
            phase = .fighting
            emit(.resumed)
        }
        return flush()
    }

    /// 新牌露出来了（回顾收掉）：从这一刻开始算上手时间、连招间隔和对手蓄力。只在 holdNewCards 时有用。
    /// 回顾时就按了这张牌的字母（已经开打）的话，计时照旧，只补上对手蓄力。
    @discardableResult
    public func cardRevealed(_ slot: Int, at now: Double) -> [DuelEvent] {
        events = []
        guard holdNewCards, awaitingReveal, case .fighting = phase else { return flush() }
        step(to: gameTime(now))
        guard case .fighting = phase, cards.indices.contains(slot) else { return flush() }
        awaitingReveal = false
        if groupMode { for i in foes.indices { foes[i].pressureStart += clock - holdFrom } }
        if bossMode, let s = opponent.pressureStart { opponent.pressureStart = s + (clock - holdFrom) }
        if target != .card(slot) {
            cards[slot].dealtAt = clock
            readyAt = clock
            if player.lastStrikeAt != nil { player.lastStrikeAt = clock }
        }
        if !groupMode, opponent.pressureStart == nil { startPressure() }
        return flush()
    }

    // MARK: - 只读状态

    public var gameClock: Double { clock }

    /// 当前可接受的下一个字母（给键盘做轻微放宽和「按偏」判断）。
    public var expectedLetters: Set<Character> {
        guard case .fighting = phase else { return [] }
        switch target {
        case .none:
            var set = Set(cards.map(\.word.firstLetter))
            if let inc = opponent.incoming { set.insert(inc.word.firstLetter) }
            return set
        case .card(let i):
            let l = Array(cards[i].word.letters)
            return cards[i].typed.count < l.count ? [l[cards[i].typed.count]] : []
        case .incoming:
            guard let inc = opponent.incoming else { return [] }
            let l = Array(inc.word.letters)
            return inc.typed.count < l.count ? [l[inc.typed.count]] : []
        }
    }

    /// 某张牌当前的蓄势倍数。
    public func storeMultiplier(ofCard i: Int) -> Double {
        guard features.contains(.store), cards.indices.contains(i) else { return 1 }
        return cards[i].frozenStore ?? storeAt(cards[i], clock)
    }

    public var comboWindowRemaining: Double {
        guard player.combo > 0, let last = player.lastStrikeAt, target == .none else { return 0 }
        return max(0, comboWindow - (clock - last))
    }

    // MARK: - 内部

    func emit(_ e: DuelEvent) {
        // 任何一个字母被接受、目标变化或出招，都熄灭当前提示
        switch e {
        case .letterAccepted, .targetCleared, .strike, .blocked, .parried, .hitByIncoming, .won, .lost:
            if currentHint != nil {
                currentHint = nil
                events.append(e)
                events.append(.hintCleared)
                return
            }
        default: break
        }
        events.append(e)
    }

    func flush() -> [DuelEvent] {
        let out = events
        events = []
        return out
    }

    func gameTime(_ wall: Double) -> Double {
        var paused = pausedTotal
        if let p = pauseStartedAtWall { paused += wall - p }
        return max(clock, wall - startedAtWall - paused)
    }

    func wallTime(_ game: Double) -> Double { game + startedAtWall + pausedTotal }

    func endPause(at wall: Double) {
        if let p = pauseStartedAtWall { pausedTotal += max(0, wall - p) }
        pauseStartedAtWall = nil
    }

    /// 推进到游戏时间 g：连招超时、卡住自动拆招、来招到时。
    func step(to g: Double) {
        guard g >= clock else { return }
        clock = g
        checkComboTimeout()
        checkHint()
        guard case .fighting = phase else { return }
        stepIncoming()
        if groupMode { stepGroup() } else { stepPressure() }
    }

    func finish(won: Bool) {
        phase = won ? .won : .lost
        target = .none
        opponent.incoming = nil
        summary = DuelSummary(charactersTyped: charactersTyped, maxCombo: player.maxCombo, parries: parries,
                              newMoves: newMoves, durationSeconds: clock, won: won,
                              movesDone: moveMarks.count, goldMoves: moveMarks.filter { $0 }.count)
        emit(won ? .won : .lost)
    }

    func syllable(_ s: String) -> Syllable {
        syllableTable[s] ?? Syllable(spelling: s, volume: "base", isHard: false, parts: .init(initial: "", medial: "", final: s))
    }
}

public extension DuelEngine {
    /// 只给 UI 测试用：把对手血量设得很低，打一招就赢。
    func debugSetOpponentHP(_ hp: Int) {
        opponent.hp = hp
        opponent.maxHP = max(hp, 1)
    }
}
