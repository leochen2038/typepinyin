import Foundation

/// 比武用的词表（App 里由内容包转成；测试用 Fixtures/test-words.json）。
public struct WordBank: Codable, Sendable {
    public struct Passage: Codable, Sendable, Hashable {
        public var id: String
        public var text: String
        public var syllables: [String]

        public init(id: String, text: String, syllables: [String]) {
            self.id = id
            self.text = text
            self.syllables = syllables
        }
    }

    public var syllables: [Syllable]
    public var words: [Word]
    public var learned: [String]
    public var comparisonPassages: [Passage]

    public init(syllables: [Syllable], words: [Word], learned: [String], comparisonPassages: [Passage] = []) {
        self.syllables = syllables
        self.words = words
        self.learned = learned
        self.comparisonPassages = comparisonPassages
    }

    enum CodingKeys: String, CodingKey { case syllables, words, learned, comparisonPassages }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        syllables = try c.decode([Syllable].self, forKey: .syllables)
        words = try c.decode([Word].self, forKey: .words)
        learned = try c.decode([String].self, forKey: .learned)
        comparisonPassages = try c.decodeIfPresent([Passage].self, forKey: .comparisonPassages) ?? []
    }

    public static func load(from data: Data) throws -> WordBank {
        let bank = try JSONDecoder().decode(WordBank.self, from: data)
        try bank.validate()
        return bank
    }

    public func validate() throws {
        let known = Set(syllables.map(\.spelling))
        for w in words { try w.validate(knownSpellings: known) }
    }

    public var syllableTable: [String: Syllable] {
        Dictionary(syllables.map { ($0.spelling, $0) }, uniquingKeysWith: { a, _ in a })
    }

    public var plainWords: [Word] { words.filter { !$0.isIdiom } }
    public var idioms: [Word] { words.filter(\.isIdiom) }
}
