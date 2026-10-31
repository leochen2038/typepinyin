import Foundation
import LearningCore

/// 旅程里一场比武的单场设置（不经调参面板）：初入江湖、路上的比武、掌门各不一样。
public struct DuelSetup: Sendable {
    /// 已学会的音节（拼错要罚的）；nil = 用词表预设的。
    public var learned: Set<String>?
    /// 上次记住的手速（每个字母的平均用时）；nil = 默认。
    public var secondsPerLetter: Double?
    /// 这一场的目标时长（定对手血量）；nil = 调参里的。
    public var targetSeconds: Double?
    /// 玩家血量最低到几（初入江湖不会输 = 1）；0 = 照常。
    public var minHP = 0
    /// 对手几条命、蓄力打不断；nil = 调参里的。
    public var lives: Int?
    public var bossPressure: Bool?
    /// 这一场是群战；nil = 调参里的。
    public var groupFight: Bool?
    /// 群战一共几个人；nil = 调参里的。
    public var groupTotal: Int?
    /// 第一张牌不蓄力（教学：跟着亮起来的键慢慢按）。
    public var firstCardFree = false
    /// 今天是哪一天（交回的打字结果带上）。
    public var day: DayIndex = 0

    public init() {}
}

/// 出牌来源：旅程里由学习系统决定下一张牌出什么。
public protocol CardSource: AnyObject {
    /// 下一张普通牌和它的重数；尽量避开场上已有的首字母和词。
    func nextCard(avoidingFirstLetters: Set<Character>, avoidingTexts: Set<String>) -> (word: Word, rank: Int)
    /// 必杀用的成语；nil = 用词表里的。
    func nextIdiom() -> (word: Word, rank: Int)?
    /// 一张牌打完：有没有打错或看提示。
    func cardDone(_ word: Word, clean: Bool)
    /// 同上，带上这张牌每个字母的用时（练功房按它判断顺不顺）。
    func cardDone(_ word: Word, clean: Bool, secondsPerLetter: Double)
    /// 一个音节成了新招（由出牌来源安排复现）。
    func newMove(_ spelling: String)
}

public extension CardSource {
    func cardDone(_ word: Word, clean: Bool, secondsPerLetter: Double) { cardDone(word, clean: clean) }
}

/// 正在打的这张牌，每个音节的记录（用来交回打字结果）。
struct SyllableTrack {
    var first: [Double?]
    var end: [Double?]
    var wrong: [Bool]
    var hinted: [Bool]
    init(count: Int) {
        first = Array(repeating: nil, count: count)
        end = Array(repeating: nil, count: count)
        wrong = Array(repeating: false, count: count)
        hinted = Array(repeating: false, count: count)
    }
}

extension DuelEngine {
    /// 玩家掉血；返回 true 表示倒下了（单场设置了最低血量时不会倒下）。
    func hurtPlayer(_ dmg: Int) -> Bool {
        player.hp = max(setup.minHP, player.hp - dmg)
        return player.hp <= 0
    }

    func resetTrack(for word: Word) {
        track = SyllableTrack(count: word.syllables.count)
    }

    /// 打对一个字母（第 pos 个）：这个音节第一次打下去时记上手时间，打完最后一个字母时交回一条结果。
    func trackAccepted(word: Word, pos: Int) {
        if track.first.count != word.syllables.count { resetTrack(for: word) }
        let idx = word.syllableIndex(atLetter: pos)
        if track.first[idx] == nil { track.first[idx] = clock }
        let ends = word.syllables.reduce(into: [Int]()) { $0.append(($0.last ?? 0) + $1.count) }
        guard pos + 1 == ends[idx], track.end[idx] == nil else { return }
        track.end[idx] = clock
        let from = idx == 0 ? readyAt : (track.end[idx - 1] ?? readyAt)
        let start = max(0, (track.first[idx] ?? clock) - from)
        attempts.append(Attempt(spelling: word.syllables[idx], at: clock, day: setup.day,
                                correct: !track.wrong[idx], usedHint: track.hinted[idx], startSeconds: start))
    }

    func trackWrong(word: Word, pos: Int) {
        if track.first.count != word.syllables.count { resetTrack(for: word) }
        track.wrong[word.syllableIndex(atLetter: pos)] = true
    }

    /// 键盘亮出提示时：当前要打的音节记为看过提示。
    func trackHint() {
        guard case .card(let i) = target, cards.indices.contains(i) else {
            if target == .none { hintPendingFirst = true }
            return
        }
        let w = cards[i].word
        if track.first.count != w.syllables.count { resetTrack(for: w) }
        let pos = min(cards[i].typed.count, max(0, w.letterCount - 1))
        track.hinted[w.syllableIndex(atLetter: pos)] = true
    }
}
