import Foundation

/// 一张词卡（练功房里的一个词）：比武里第一次打完就收。记着在哪儿打过（梦里、地区里都算）、打过几次、
/// 最近几次干不干净、平均每个字母多快，以及累计几场打对（熟练、精通按它算）。
public struct PracticeWord: Codable, Sendable, Equatable {
    public var text: String
    public var syllables: [String]
    public var volume: String
    /// 一共打完过几次。
    public var seen: Int
    /// 其中没打错、没看提示的次数。
    public var clean: Int
    /// 最近几次干不干净（最多 5 次，旧的在前）。
    public var recent: [Bool]
    /// 每个字母平均用时（秒，按次数滑动）。
    public var secondsPerLetter: Double
    public var lastSeen: Double
    /// 累计几场打对：一场里打这个词每次都没错、没看提示算一场（一场只算一次）。
    public var cleanDuels: Int

    public init(text: String, syllables: [String], volume: String, seen: Int = 0, clean: Int = 0, recent: [Bool] = [],
                secondsPerLetter: Double = 0, lastSeen: Double = 0, cleanDuels: Int = 0) {
        self.cleanDuels = cleanDuels
        self.text = text
        self.syllables = syllables
        self.volume = volume
        self.seen = seen
        self.clean = clean
        self.recent = recent
        self.secondsPerLetter = secondsPerLetter
        self.lastSeen = lastSeen
    }

    /// 又打完一次。
    public mutating func note(clean ok: Bool, secondsPerLetter spl: Double, at time: Double) {
        seen += 1
        if ok { clean += 1 }
        recent = Array((recent + [ok]).suffix(5))
        let s = min(max(spl, 0.05), 5)                       // 掐掉离谱的值（挂机、粘贴之类）
        secondsPerLetter = seen == 1 || secondsPerLetter <= 0 ? s : secondsPerLetter * 0.7 + s * 0.3
        lastSeen = time
    }

    /// 这张词卡练到哪：见过（收到就是）、熟练、精通。
    public func level(_ t: LearningTuning) -> CardLevel {
        cleanDuels >= t.masterDuels ? .master : cleanDuels >= t.fluentDuels ? .fluent : .met
    }

    public var asContentWord: ContentWord {
        ContentWord(text: text, syllables: syllables, volume: volume, isIdiom: false, freq: 0)
    }
}

/// 练功房出牌的比重：打得不顺、常打错的多出，练熟的少出但不会不出。
public enum PracticeWeights {
    /// 练熟了的词最低也有这么多（跟最生的词差十倍左右）。
    public static let floor = 0.3

    /// - Parameter typical: 玩家平时每个字母的用时（跨场记住的手速）；这个词比平时慢就算不顺。
    public static func weight(_ w: PracticeWord, typical: Double) -> Double {
        let misses = Double(w.recent.filter { !$0 }.count)
        let missRate = (misses + 0.5) / (Double(w.recent.count) + 1)        // 打得少的先当一半生
        let slow = typical > 0 && w.secondsPerLetter > 0 ? min(max(w.secondsPerLetter / typical - 1, 0), 2) : 0.5
        let fresh = w.seen < 3 ? 0.6 : 0                                    // 刚碰到的几次多出一点
        return floor + 3 * missRate + 1.5 * slow + fresh
    }

    public static func weights(_ words: [PracticeWord], typical: Double) -> [String: Double] {
        Dictionary(words.map { ($0.text, weight($0, typical: typical)) }, uniquingKeysWith: max)
    }
}

/// 词卡的三级：见过（第一次打完就收）、熟练（累计 fluentDuels 场打对）、精通（累计 masterDuels 场打对）。只升不降。
public enum CardLevel: Int, Sendable, Comparable, CaseIterable {
    case met = 1, fluent, master
    public static func < (a: CardLevel, b: CardLevel) -> Bool { a.rawValue < b.rawValue }
    public var name: String { ["", "见过", "熟练", "精通"][rawValue] }
}

/// 秘籍重数按词卡算，音节是桥梁：这一卷的每个音节（词表里有词的），看收过的词卡里含它的最好的一张。
/// 一重 = 拿到；二重 = 一半音节各有一张熟练的；三重 = 全部；四重 = 一半音节各有一张精通的；五重 = 全部。
/// 一张词卡可以同时算几卷（「他们」ta 属基本功、men 属鼻音掌，两卷都算）。
public enum CardRank {
    /// 算进重数的音节：这一卷里词表中至少有一个词的。
    public static func syllables(in volume: String, content: LearningContent) -> [String] {
        content.syllables(in: volume).map(\.spelling).filter { !(content.wordsBySyllable[$0] ?? []).isEmpty }
    }

    /// 每个音节最好的词卡等级（没有词卡含它的不在里面）。
    public static func best(_ cards: [PracticeWord], tuning: LearningTuning) -> [String: CardLevel] {
        var out: [String: CardLevel] = [:]
        for c in cards {
            let lv = c.level(tuning)
            for s in Set(c.syllables) where (out[s] ?? .met) <= lv { out[s] = lv }
        }
        return out
    }

    /// 达到 level 的音节有几个 / 一共几个。
    static func count(_ volume: String, _ best: [String: CardLevel], _ level: CardLevel, content: LearningContent) -> (have: Int, all: Int) {
        let syl = syllables(in: volume, content: content)
        return (syl.filter { (best[$0] ?? .met) >= level && best[$0] != nil }.count, syl.count)
    }

    public static func rank(of volume: String, obtained: Bool, previous: Int, best: [String: CardLevel], content: LearningContent) -> Int {
        guard obtained else { return previous }
        let f = count(volume, best, .fluent, content: content), m = count(volume, best, .master, content: content)
        guard f.all > 0 else { return max(previous, 1) }
        let half = Double(f.all) / 2
        var r = 1
        if Double(f.have) >= half { r = 2 }
        if f.have >= f.all { r = 3 }
        if Double(m.have) >= half { r = 4 }
        if m.have >= m.all { r = 5 }
        return max(previous, r)
    }

    /// 离下一重有多远（0…1）：顶栏的进度环、秘籍页的进度条用。
    public static func progress(of volume: String, rank: Int, best: [String: CardLevel], content: LearningContent) -> Double {
        guard rank >= 1, rank < 5 else { return rank >= 5 ? 1 : 0 }
        let f = count(volume, best, .fluent, content: content), m = count(volume, best, .master, content: content)
        guard f.all > 0 else { return 0 }
        let n = Double(f.all), half = n / 2
        let (have, need): (Double, Double)
        switch rank {
        case 1: (have, need) = (Double(f.have), half)
        case 2: (have, need) = (Double(f.have) - half, half)
        case 3: (have, need) = (Double(m.have), half)
        default: (have, need) = (Double(m.have) - half, half)
        }
        return min(1, max(0, have / max(1, need)))
    }
}
