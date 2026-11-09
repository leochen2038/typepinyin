import Foundation

/// 十卷秘籍：编号、显示的名字、所属的秘籍。
public enum Volumes {
    /// 按闯关顺序（2026-11-09 改：基本功 → 鼻音掌 → 两字诀 → yw → ü → 省字诀 → 三拼），秘籍页按它排。
    public static let current = ["base", "biyin-shang", "biyin-xia", "liangzi-shang", "liangzi-xia",
                                 "yw", "lv", "shengzi", "sanpin-shang", "sanpin-xia"]
    /// 原来的秘籍顺序（调参「课程」选「原来」时用）。
    public static let legacyAll = ["base", "liangzi-shang", "liangzi-xia", "biyin-shang", "biyin-xia",
                                   "yw", "shengzi", "lv", "sanpin-shang", "sanpin-xia"]
    /// 原来的闯关顺序（地区的卷）。
    public static let legacyRegionOrder = ["base", "liangzi-shang", "liangzi-xia", "yw", "shengzi", "lv",
                                           "biyin-shang", "biyin-xia", "sanpin-shang", "sanpin-xia"]
    /// App 启动读内容包时按调参定下来，之后不再变。
    nonisolated(unsafe) public static var legacyCurriculum = false
    public static var all: [String] { legacyCurriculum ? legacyAll : current }

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

    /// 原来的第一关（基本功）只练这 30 个：单个字母的声母加单韵母、没有翘舌，按字的常用程度挑的。
    public static let baseCore: Set<String> = Set("ba bi bu ci da de di du er fa fu ge gu he hu ji ke le li lu mo na ni qi ru si ta ti xi zi".split(separator: " ").map(String.init))

    /// 按韵母归卷（2026-11-09 改，和生成内容包的脚本一致）：声母加一个韵母 a o e i u（含 zh ch sh、整体认读、er）都是基本功；
    /// 两字诀只剩 ai ei / ao ou，省字诀只剩 iu ui un；其余照拼写规则。
    public static func classify(_ s: String) -> String {
        legacyCurriculum ? classifyLegacy(s) : classifyByFinal(s)
    }

    public static func classifyByFinal(_ s: String) -> String {
        let v = classifyBySpelling(s)
        return v == "base" && s == "hng" ? "biyin-xia" : v
    }

    /// 原来的归卷：基本功只留 baseCore 那 30 个，其余的按韵母挂到最像的一卷。
    public static func classifyLegacy(_ s: String) -> String {
        let v = classifyBySpelling(s)
        guard v == "base", !baseCore.contains(s), let last = s.last else { return v }
        if "ae".contains(last) { return "liangzi-shang" }       // a、e 结尾 → 两字诀上卷（ai ei）
        if "ou".contains(last) { return "liangzi-xia" }         // o、u 结尾 → 两字诀下卷（ao ou）
        if last == "i" { return "shengzi" }                     // i 结尾 → 省字诀（iu ui）
        return "biyin-xia"                                     // hng
    }

    static func classifyBySpelling(_ s: String) -> String {
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
    /// 以下是正式美术用的外形，没写用默认。
    public var build: String?
    public var weapon: String?
    public var face: String?
    public var trim: String?
    public var back: String?

    public init(robe: String, hat: String, build: String? = nil, weapon: String? = nil, face: String? = nil, trim: String? = nil, back: String? = nil) {
        self.robe = robe; self.hat = hat; self.build = build; self.weapon = weapon; self.face = face; self.trim = trim; self.back = back
    }
}

/// 掌门或路上的对手。
public struct Fighter: Codable, Sendable, Hashable {
    public var name: String
    public var title: String
    public var look: Look
    public var intro: String?
    public var lifeLines: [String]?
    /// 血量倍数：这个对手一条命的血是按手速算出的标准血量的几倍（同一类对手之间可以不一样）；nil = 1。
    public var hpFactor: Double?
    /// 掌门被打赢后夸玩家的一句话（拿到秘籍时显示）；没写不显示。
    public var defeatLine: String?
}

/// 地区长卷的配色（六位十六进制，如 "#E4EEE6"）。
public struct RegionThemeSpec: Codable, Sendable, Hashable {
    public var sky: String
    public var farHill: String
    public var nearHill: String
    public var road: String
    public var accent: String
}

/// 旧路网地图的位置（云海群岛按 3×3 的固定顺序排，已经不用；留着只为读旧数据）。
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
    public var map: MapSpot?
    public var playable: Bool
    /// 群战每个人（按出场顺序）的血是标准血量的几倍；nil 或不够长 = 按等级的默认（喽啰 0.15、镖师 0.3、头目 0.5）。
    public var groupHP: [Double]?
    /// 长卷配色；nil = App 里写死的兜底。
    public var theme: RegionThemeSpec?
    /// 门口的碑；nil = 没有（直接进长卷）。
    public var stele: Stele?
}

/// 总地图上不是地区的地点：初入江湖、武林大会。
public struct Place: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var map: MapSpot?
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

/// 初入江湖的梦：开场白、醒来的话、梦里的对手、专门挑的好打的词。
public struct Dream: Codable, Sendable, Hashable {
    public var intro: String
    public var outro: String
    public var boss: Fighter
    public var words: [ContentWord]
    /// 第一张牌（教学）固定打的词。
    public var tutorial: ContentWord?
    /// 新开场：不做梦，一句开场白，然后到江湖地图（进葫芦集先打葫芦集碑）。
    public var prologue: String?
}

/// 每座岛门口的碑：第一次进这座岛时先照着打一遍，再进长卷。
public struct Stele: Codable, Sendable, Hashable {
    public var intro: String
    public var text: String
    public var syllables: [String]
}

/// 武林大会（山顶，最后一关）：请帖、碑、十位掌门下台的话、妙笔书生、收尾的话。
public struct Gathering: Codable, Sendable, Hashable {
    /// 走完最后一座岛收到的请帖，落款 signature。
    public var invitation: String
    public var signature: String
    public var stele: Stele
    /// 第一场：每位掌门（按地区 id）被打下台时说的一句。
    public var praise: [String: String]
    /// 第一场打赢、当选武林盟主时的一句和下面的小字。
    public var crowned: String
    public var crownedNote: String
    /// 第二场的对手。
    public var boss: Fighter
    /// 打赢以后妙笔书生最后说的一句。
    public var farewell: String
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
    public var dream: Dream?
    public var gathering: Gathering?

    public let syllableTable: [String: ContentSyllable]
    /// 每个音节在哪些词里（下标指向 `words`，按词频排）。
    public let wordsBySyllable: [String: [Int]]
    /// 一个词只归一关：每个词（下标同 `words`）归它里面最后才学到的那一卷（按地区的顺序）。
    public let owner: [String]
    /// 每一卷（关）归它的词有几个（含成语），地图卡片的「N 张 / 总数」用。
    public let ownedCount: [String: Int]
    /// 卷 → 第几关（0 起，按地区的顺序）。
    public let levelIndex: [String: Int]

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
        var dream: Dream?
        var gathering: Gathering?
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
        dream = raw.dream
        gathering = raw.gathering
        syllableTable = Dictionary(raw.syllables.map { ($0.spelling, $0) }, uniquingKeysWith: { a, _ in a })
        var by: [String: [Int]] = [:]
        for (i, w) in raw.words.enumerated() where !w.isIdiom {
            for s in Set(w.syllables) { by[s, default: []].append(i) }
        }
        wordsBySyllable = by.mapValues { $0.sorted { raw.words[$0].freq < raw.words[$1].freq } }
        let table = syllableTable
        let level = Dictionary(raw.regions.enumerated().map { ($0.element.volume, $0.offset) }, uniquingKeysWith: { a, _ in a })
        levelIndex = level
        let own = raw.words.map { w in
            w.syllables.map { table[$0]?.volume ?? Volumes.classify($0) }.max { (level[$0] ?? -1) < (level[$1] ?? -1) } ?? "base"
        }
        owner = own
        ownedCount = own.reduce(into: [:]) { $0[$1, default: 0] += 1 }
    }

    /// 原来的课程：音节按旧规则归卷，地区按旧顺序排（调参「课程」选「原来」，重开 App 生效）。
    public func legacyCurriculum() -> LearningContent {
        var raw = Raw(version: version, syllables: syllables, commonChars: commonChars, words: words, regions: regions,
                      places: places, encounters: encounters, comparisonPassages: comparisonPassages, articles: articles, dream: dream,
                      gathering: gathering)
        raw.syllables = syllables.map { s in
            var t = s
            t.volume = Volumes.classifyLegacy(s.spelling)
            t.family = t.volume
            return t
        }
        raw.regions = regions.sorted {
            (Volumes.legacyRegionOrder.firstIndex(of: $0.volume) ?? 99) < (Volumes.legacyRegionOrder.firstIndex(of: $1.volume) ?? 99)
        }
        return LearningContent(raw)
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

    /// 计入重数的音节：这一卷的全部常用音节。
    public func rankSyllables(in volume: String, tuning: LearningTuning) -> [ContentSyllable] { commonSyllables(in: volume) }

    /// 这些字里有几个是常用字（「你已经能打出多少个常用字」：按玩家真打出过的字数，不按音节推算）。
    public func commonCharCount(in typed: Set<Character>) -> Int {
        commonChars.filter { $0.char.first.map(typed.contains) ?? false }.count
    }

    /// 第几关（0 起，按地区的顺序）；不是地区的卷返回 nil。
    public func level(of volume: String) -> Int? { levelIndex[volume] }

    /// 到这一关为止学过的全部音节（这一关和前面几关的卷）：一个词只归一关，第 k 关只出归前 k 关的词。
    public func syllables(upTo volume: String) -> Set<String> {
        guard let k = level(of: volume) else { return Set(syllables.map(\.spelling)) }
        let vols = Set(regions.prefix(k + 1).map(\.volume))
        return Set(syllables.filter { vols.contains($0.volume) }.map(\.spelling))
    }

    /// 这些音节组成的词归哪一关的卷。
    public func owner(of syllables: [String]) -> String {
        syllables.map(volume(of:)).max { (levelIndex[$0] ?? -1) < (levelIndex[$1] ?? -1) } ?? "base"
    }

    public func region(_ id: String) -> Region? { regions.first { $0.id == id } }
    public func place(_ id: String) -> Place? { places.first { $0.id == id } }
    public var idioms: [ContentWord] { words.filter(\.isIdiom) }
}
