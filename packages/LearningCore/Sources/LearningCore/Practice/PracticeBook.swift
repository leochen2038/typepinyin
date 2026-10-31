import Foundation

/// 练功房里的一个词：玩家在哪儿打过（梦里、地区里都算），打过几次、最近几次干不干净、平均每个字母多快。
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

    public init(text: String, syllables: [String], volume: String, seen: Int = 0, clean: Int = 0, recent: [Bool] = [],
                secondsPerLetter: Double = 0, lastSeen: Double = 0) {
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
