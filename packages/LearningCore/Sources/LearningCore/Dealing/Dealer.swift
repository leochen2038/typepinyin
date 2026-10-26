import Foundation

/// 出字时的上下文：在哪片地区（nil = 初入江湖）、这一场已经出了什么、今天新学了几个。
public struct DealContext: Codable, Sendable, Equatable {
    public var volume: String?
    public var today: DayIndex
    /// 今天已经新学了几个音节（跨场累计，由调用方存档）。
    public var newToday = 0

    public init(volume: String?, today: DayIndex, newToday: Int = 0) {
        self.volume = volume
        self.today = today
        self.newToday = newToday
    }
}

/// 一张牌为什么出现。
public enum DealReason: String, Sendable {
    case replay, review, probe, newInVolume, knownInVolume, filler
}

public struct DealtWord: Sendable {
    public var word: ContentWord
    public var reason: DealReason
    /// 这张牌带进来的新音节（没碰过、不是基本功的）。
    public var newSyllables: [String]
}

/// 出字器：一场比武里一张一张决定出什么牌（待复现、复习、本卷已会/没会、垫底，加上新音节的护栏和打对率反馈）。
public final class Dealer: @unchecked Sendable {
    public private(set) var learner: Learner
    public private(set) var probe: ProbeState
    public private(set) var context: DealContext
    let content: LearningContent
    var tuning: LearningTuning { learner.tuning }
    var rng: SplitMix

    // 这一场的状态
    var dealt = 0
    var newThisDuel = 0
    var sinceNew = 99
    var afterMissLeft = 0
    var recentWords: [String] = []
    var recentResults: [Bool] = []
    var replay: [(due: Int, spelling: String)] = []
    /// 这一场出过的新音节（第一次出现时记一次「今天新学」）。
    var introduced: Set<String> = []

    public init(content: LearningContent, learner: Learner, probe: ProbeState, context: DealContext, seed: UInt64) {
        self.content = content
        self.learner = learner
        self.probe = probe
        self.context = context
        self.rng = SplitMix(seed: seed)
    }

    // MARK: 音节分类

    /// 新音节：还没碰过、也不是基本功（基本功大多数人已经会，按会的算）。
    public func isNew(_ s: String) -> Bool {
        learner.proficiency(s) == .locked && content.volume(of: s) != "base" && !introduced.contains(s)
    }

    func wordIsEasy(_ w: ContentWord) -> Bool { !w.syllables.contains(where: isNew) }

    var successRate: Double {
        let last = recentResults.suffix(tuning.successWindow)
        guard !last.isEmpty else { return 1 }
        return Double(last.filter { $0 }.count) / Double(last.count)
    }

    /// 这一张能不能带新音节进来（护栏）。
    var newAllowed: Bool {
        newThisDuel < tuning.newPerDuel
            && sinceNew > tuning.newGap
            && context.newToday < tuning.newPerDay
            && afterMissLeft == 0
            && (recentResults.count < 4 || successRate >= tuning.successTarget - 0.05)
    }

    // MARK: 出牌

    public func next(avoidingFirstLetters: Set<Character> = [], avoidingTexts: Set<String> = []) -> DealtWord {
        defer { dealt += 1 }
        let avoid: (ContentWord) -> Bool = { w in
            avoidingTexts.contains(w.text) || self.recentWords.suffix(self.tuning.recentWords).contains(w.text)
                || avoidingFirstLetters.contains(w.syllables.first?.first ?? " ")
        }
        // 1. 待复现
        if let k = replay.firstIndex(where: { $0.due <= dealt }) {
            let s = replay.remove(at: k).spelling
            if let w = pickWord(containing: s, avoid: avoid) { return finish(w, .replay) }
        }
        // 2. 到期复习（地区里按配比，初入江湖没有）
        if context.volume != nil {
            return dealInRegion(avoid: avoid)
        }
        return dealInOpening(avoid: avoid)
    }

    /// 初入江湖：高频的会的字为主，隔几张插一个摸底音节。
    func dealInOpening(avoid: (ContentWord) -> Bool) -> DealtWord {
        if newAllowed && dealt >= 2 {
            let cands = probe.candidates(learner: learner, content: content, tuning: tuning)
            for s in cands.shuffled(using: &rng) {
                if let w = pickWord(containing: s, avoid: avoid, allowNew: s) { return finish(w, .probe) }
            }
        }
        return finish(pickEasy(avoid: avoid, topN: 400), .filler)
    }

    /// 地区里：本卷已会 / 本卷没会 / 复习 / 垫底，按配比抽。
    func dealInRegion(avoid: (ContentWord) -> Bool) -> DealtWord {
        guard let vol = context.volume else { return finish(pickEasy(avoid: avoid, topN: 400), .filler) }
        let t = tuning
        var roll = Double(rng.next() % 10_000) / 10_000
        let due = learner.due(on: context.today)
        if !due.isEmpty, roll < t.mixReview {
            for s in due.shuffled(using: &rng) {
                if let w = pickWord(containing: s, avoid: avoid) { return finish(w, .review) }
            }
        }
        roll = due.isEmpty ? roll * (1 - t.mixReview) : roll       // 没有要复习的，复习那一份分给其他三类
        let inVol = content.syllables(in: vol).map(\.spelling)
        let newOnes = inVol.filter(isNew)
        let knownOnes = inVol.filter { !isNew($0) }
        let pNew = t.mixNew / (t.mixKnown + t.mixNew + t.mixFiller)
        let pKnown = t.mixKnown / (t.mixKnown + t.mixNew + t.mixFiller)
        let r2 = Double(rng.next() % 10_000) / 10_000
        if r2 < pNew, newAllowed, !newOnes.isEmpty {
            for s in newOnes.sorted(by: { content.commonChars(of: $0).count > content.commonChars(of: $1).count }).prefix(6).shuffled(using: &rng) {
                if let w = pickWord(containing: s, avoid: avoid, allowNew: s) { return finish(w, .newInVolume) }
            }
        }
        if r2 < pNew + pKnown || (r2 < pNew + pKnown + 0.01) {
            for s in knownOnes.shuffled(using: &rng) {
                if let w = pickWord(containing: s, avoid: avoid) { return finish(w, .knownInVolume) }
            }
        }
        return finish(pickEasy(avoid: avoid, topN: 600), .filler)
    }

    /// 含这个音节的常用词：其余音节都不能是新的（allowNew 指定的那个除外），从最常用的几个里随机挑。
    func pickWord(containing s: String, avoid: (ContentWord) -> Bool, allowNew: String? = nil) -> ContentWord? {
        let idx = content.wordsBySyllable[s] ?? []
        let ok = idx.map { content.words[$0] }.filter { w in
            !avoid(w) && w.syllables.allSatisfy { $0 == allowNew || !isNew($0) }
        }
        return ok.prefix(8).randomElement(using: &rng)
    }

    /// 垫底：全是会的音节的高频词。
    func pickEasy(avoid: (ContentWord) -> Bool, topN: Int) -> ContentWord {
        let pool = content.words.filter { !$0.isIdiom && $0.freq <= topN && wordIsEasy($0) && !avoid($0) }
        if let w = pool.randomElement(using: &rng) { return w }
        return content.words.first { !$0.isIdiom && wordIsEasy($0) } ?? content.words[0]
    }

    func finish(_ w: ContentWord, _ reason: DealReason) -> DealtWord {
        let news = Array(Set(w.syllables.filter(isNew))).sorted()
        if news.isEmpty {
            sinceNew += 1
        } else {
            newThisDuel += news.count
            sinceNew = 0
            context.newToday += news.count
            introduced.formUnion(news)
        }
        if afterMissLeft > 0 { afterMissLeft -= 1 }
        recentWords.append(w.text)
        if recentWords.count > 40 { recentWords.removeFirst() }
        return DealtWord(word: w, reason: reason, newSyllables: news)
    }

    /// 必杀用的成语：优先全由会的音节组成的。
    public func nextIdiom() -> ContentWord {
        let idioms = content.idioms
        let easy = idioms.filter(wordIsEasy).prefix(40)
        return (easy.isEmpty ? Array(idioms.prefix(40)) : Array(easy)).randomElement(using: &rng) ?? idioms[0]
    }

    // MARK: 回报

    /// 一张牌打完：有没有打错或看提示。摸底的音节记下结果。
    public func note(_ w: ContentWord, clean: Bool) {
        recentResults.append(clean)
        if recentResults.count > 60 { recentResults.removeFirst() }
        if !clean { afterMissLeft = tuning.afterMissKnown }
        for s in Set(w.syllables) where introduced.contains(s) {
            probe.note(s, correct: clean, content: content, tuning: tuning)
        }
    }

    /// 一个音节成了新招：接下来第几张复现它。
    public func newMove(_ s: String) {
        for k in tuning.replayOffsets { replay.append((due: dealt + k - 1, spelling: s)) }
    }

    /// 比武结束后把学习记录换成最新的（下一场用）。
    public func update(learner: Learner) { self.learner = learner }
}

/// 可复现的随机数（同一个种子同样的牌）。
struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
