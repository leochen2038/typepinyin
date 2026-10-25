import Foundation

/// 一个不带声调的音节，拼写里 ü 写作 v。
public struct Syllable: Codable, Sendable, Hashable {
    public struct Parts: Codable, Sendable, Hashable {
        public var initial: String
        public var medial: String
        public var final: String
        public init(initial: String, medial: String, final: String) {
            self.initial = initial
            self.medial = medial
            self.final = final
        }
    }

    public var spelling: String
    public var volume: String
    public var isHard: Bool
    public var parts: Parts
    public var hardReason: String?

    public init(spelling: String, volume: String, isHard: Bool, parts: Parts, hardReason: String? = nil) {
        self.spelling = spelling
        self.volume = volume
        self.isHard = isHard
        self.parts = parts
        self.hardReason = hardReason
    }
}

/// 一个词或成语，逐字给出拼写。
public struct Word: Codable, Sendable, Hashable {
    public var text: String
    public var syllables: [String]
    public var volume: String
    public var isIdiom: Bool

    public init(text: String, syllables: [String], volume: String, isIdiom: Bool = false) {
        self.text = text
        self.syllables = syllables
        self.volume = volume
        self.isIdiom = isIdiom
    }

    enum CodingKeys: String, CodingKey { case text, syllables, volume, isIdiom }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        syllables = try c.decode([String].self, forKey: .syllables)
        volume = try c.decode(String.self, forKey: .volume)
        isIdiom = try c.decodeIfPresent(Bool.self, forKey: .isIdiom) ?? false
    }

    /// 全部拼音字母连在一起，比如「熊猫」→ "xiongmao"。
    public var letters: String { syllables.joined() }
    public var letterCount: Int { letters.count }
    public var firstLetter: Character { letters.first ?? " " }

    /// 第 `typed` 个字母所在的音节下标。
    public func syllableIndex(atLetter typed: Int) -> Int {
        var count = 0
        for (i, s) in syllables.enumerated() {
            count += s.count
            if typed < count { return i }
        }
        return max(0, syllables.count - 1)
    }

    /// 第 `index` 个音节开始前的字母数。
    public func letterOffset(ofSyllable index: Int) -> Int {
        syllables.prefix(index).reduce(0) { $0 + $1.count }
    }
}

public enum WordBankError: Error, Equatable {
    case countMismatch(String)
    case unknownSyllable(String, String)
    case invalidSpelling(String)
}

public extension Word {
    /// 校验：「text 字数 = syllables 个数；每个拼写都在音节表中」。
    func validate(knownSpellings: Set<String>) throws {
        guard text.count == syllables.count else { throw WordBankError.countMismatch(text) }
        for s in syllables {
            guard !s.isEmpty, s.allSatisfy({ $0 >= "a" && $0 <= "z" }) else { throw WordBankError.invalidSpelling(s) }
            guard knownSpellings.contains(s) else { throw WordBankError.unknownSyllable(text, s) }
        }
    }
}
