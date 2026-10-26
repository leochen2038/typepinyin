import Foundation

/// 十卷秘籍：编号、显示的名字、所属的秘籍。
public enum Volumes {
    public static let all = ["base", "liangzi-shang", "liangzi-xia", "biyin-shang", "biyin-xia",
                             "yw", "shengzi", "lv", "sanpin-shang", "sanpin-xia"]

    /// 卷名，如「鼻音掌·上卷」。
    public static func name(_ v: String) -> String {
        switch v {
        case "base": return "基本功"
        case "liangzi-shang": return "两字诀·上卷"
        case "liangzi-xia": return "两字诀·下卷"
        case "biyin-shang": return "鼻音掌·上卷"
        case "biyin-xia": return "鼻音掌·下卷"
        case "yw": return "yw 身法"
        case "shengzi": return "省字诀"
        case "lv": return "ü 步"
        case "sanpin-shang": return "三拼剑谱·上卷"
        case "sanpin-xia": return "三拼剑谱·下卷"
        default: return v
        }
    }

    /// 所属的秘籍（上下卷合在一起），秘籍页分组用。
    public static func book(_ v: String) -> String {
        switch v {
        case "liangzi-shang", "liangzi-xia": return "两字诀"
        case "biyin-shang", "biyin-xia": return "鼻音掌"
        case "sanpin-shang", "sanpin-xia": return "三拼剑谱"
        default: return name(v)
        }
    }

    static let initials = ["zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "r", "z", "c", "s", "y", "w"]

    /// 按拼写规则归卷：yw 身法 → ü 步 → 省字诀 → 三拼剑谱 → 鼻音掌 → 两字诀，都不是的归基本功。
    public static func classify(_ s: String) -> String {
        guard let first = s.first else { return "base" }
        let ini = initials.first { s.hasPrefix($0) && s.count > $0.count } ?? ""
        let rest = String(s.dropFirst(ini.count))
        if first == "y" || first == "w" { return "yw" }
        if s.contains("v") || (["j", "q", "x"].contains(ini) && rest.hasPrefix("u")) { return "lv" }
        if ["iu", "ui", "un"].contains(rest) { return "shengzi" }
        if !ini.isEmpty, ["iang", "iong", "iao", "ian", "ia", "ie"].contains(rest) { return "sanpin-shang" }
        if !ini.isEmpty, ["uang", "uai", "uan", "ua", "uo"].contains(rest) { return "sanpin-xia" }
        if ["an", "en", "in"].contains(rest) { return "biyin-shang" }
        if ["ang", "eng", "ing", "ong"].contains(rest) { return "biyin-xia" }
        if ["ai", "ei"].contains(rest) { return "liangzi-shang" }
        if ["ao", "ou"].contains(rest) { return "liangzi-xia" }
        return "base"
    }
}

public struct SyllableParts: Codable, Sendable, Hashable {
    public var initial: String
    public var medial: String
    public var final: String
}

/// 内容包里的一个音节。
public struct ContentSyllable: Codable, Sendable, Hashable {
    public var spelling: String
    public var volume: String
    public var family: String
    public var parts: SyllableParts
    /// 对应的常用字，按字频排。
    public var commonChars: String
    /// 对应常用字够多，计入重数的分母。
    public var isCommon: Bool
    public var hardReason: String?
}

public struct CommonChar: Codable, Sendable, Hashable {
    public var char: String
    public var spellings: [String]
    public var rank: Int
}

public struct ContentWord: Codable, Sendable, Hashable {
    public var text: String
    public var syllables: [String]
    public var volume: String
    public var isIdiom: Bool
    /// 词频序，越小越常用。
    public var freq: Int

    public init(text: String, syllables: [String], volume: String, isIdiom: Bool, freq: Int) {
        self.text = text
        self.syllables = syllables
        self.volume = volume
        self.isIdiom = isIdiom
        self.freq = freq
    }
}

public struct Look: Codable, Sendable, Hashable {
    public var robe: String
    public var hat: String
}

/// 掌门或路上的对手。
public struct Fighter: Codable, Sendable, Hashable {
    public var name: String
    public var title: String
    public var look: Look
    public var intro: String?
    public var lifeLines: [String]?
}

public struct MapSpot: Codable, Sendable, Hashable {
    public var tier: Int
    public var side: Double
    public var icon: String?
    public var links: [String]
}

public struct RegionExample: Codable, Sendable, Hashable {
    public var char: String
    public var pinyin: String
}

public struct Region: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var pinyin: String
    public var volume: String
    public var scene: String
    public var hint: String
    public var difficulty: String
    public var examples: [RegionExample]
    public var boss: Fighter
    public var foes: [Fighter]
    public var stationLines: [String]
    public var map: MapSpot
    public var playable: Bool
}

/// 总地图上不是地区的地点：初入江湖、武林大会。
public struct Place: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var map: MapSpot
    public var intro: String?
    public var foes: [Fighter]?
}

public struct Encounter: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var kind: String
    public var regions: [String]
    public var intro: String
    public var title: String
    public var source: String
    public var text: String
    public var syllables: [String]
    public var reply: String
}

/// 一段只打不比的文字：键盘对比页、试玩的文章。
public struct TextPassage: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var text: String
    public var syllables: [String]
    public var title: String?
    public var intro: String?
    public var source: String?
}

/// 打包的内容（content.json）加上查找表。
public struct LearningContent: Sendable {
    public var version: Int
    public var syllables: [ContentSyllable]
    public var commonChars: [CommonChar]
    public var words: [ContentWord]
    public var regions: [Region]
    public var places: [Place]
    public var encounters: [Encounter]
    /// 键盘对比页的文字。
    public var comparisonPassages: [TextPassage]
    /// 试玩的文章（下一篇）。
    public var articles: [TextPassage]

    public let syllableTable: [String: ContentSyllable]
    /// 每个音节在哪些词里（下标指向 `words`，按词频排）。
    public let wordsBySyllable: [String: [Int]]

    struct Raw: Codable {
        var version: Int
        var syllables: [ContentSyllable]
        var commonChars: [CommonChar]
        var words: [ContentWord]
        var regions: [Region]
        var places: [Place]
        var encounters: [Encounter]
        var comparisonPassages: [TextPassage]?
        var articles: [TextPassage]?
    }

    public static func load(from data: Data) throws -> LearningContent {
        let raw = try JSONDecoder().decode(Raw.self, from: data)
        return LearningContent(raw)
    }

    init(_ raw: Raw) {
        version = raw.version
        syllables = raw.syllables
        commonChars = raw.commonChars
        words = raw.words
        regions = raw.regions
        places = raw.places
        encounters = raw.encounters
        comparisonPassages = raw.comparisonPassages ?? []
        articles = raw.articles ?? []
        syllableTable = Dictionary(raw.syllables.map { ($0.spelling, $0) }, uniquingKeysWith: { a, _ in a })
        var by: [String: [Int]] = [:]
        for (i, w) in raw.words.enumerated() where !w.isIdiom {
            for s in Set(w.syllables) { by[s, default: []].append(i) }
        }
        wordsBySyllable = by.mapValues { $0.sorted { raw.words[$0].freq < raw.words[$1].freq } }
    }

    /// 任何音节都能归卷：内容包里有就用它的，没有（诗文里的少见读音）就按规则现算。
    public func volume(of spelling: String) -> String {
        syllableTable[spelling]?.volume ?? Volumes.classify(spelling)
    }

    public func commonChars(of spelling: String) -> [Character] {
        Array(syllableTable[spelling]?.commonChars ?? "")
    }

    public func isCommon(_ spelling: String) -> Bool { syllableTable[spelling]?.isCommon ?? false }

    /// 一卷的全部音节、其中算常用的。
    public func syllables(in volume: String) -> [ContentSyllable] { syllables.filter { $0.volume == volume } }
    public func commonSyllables(in volume: String) -> [ContentSyllable] { syllables(in: volume).filter(\.isCommon) }

    public func region(_ id: String) -> Region? { regions.first { $0.id == id } }
    public func place(_ id: String) -> Place? { places.first { $0.id == id } }
    public var idioms: [ContentWord] { words.filter(\.isIdiom) }
}
