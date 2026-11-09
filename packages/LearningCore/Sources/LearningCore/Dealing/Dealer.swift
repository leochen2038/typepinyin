import Foundation

/// 出字时的上下文：在哪片地区（nil = 初入江湖）、这一场已经出了什么、今天新学了几个。
public struct DealContext: Codable, Sendable, Equatable {
    public var volume: String?
    public var today: DayIndex
    /// 今天已经新学了几个音节（跨场累计，由调用方存档）。
    public var newToday = 0
    /// 招式牌几个字的比重，比如前面的站 [2: 0.85, 3: 0.15]，掌门 [3: 0.4, 4: 0.35, 5: 0.25]。
    public var lengths: [Int: Double]
    /// 只许用这些音节；nil = 不限。牌、复习、必杀都照这个来。
    /// 一个词只归一关：第 k 关传前 k 关的全部音节（原来的课程只在第一关传那 30 个）。
    public var allowedSyllables: Set<String>?
    /// 本关的主题牌只挑含这些音节的词（葫芦集：带 zh ch sh 这类三个字母的，每张牌都不全是两个字母）；nil = 本卷全部。
    public var focus: Set<String>?
    /// 只从这些词里出（初入江湖的梦）；nil = 按规则从内容包里挑。
    public var pool: [ContentWord]?
    /// 第一张牌固定出这个词（教学）。
    public var firstWord: ContentWord?
    /// 练功房：pool 里每个词的比重（按词的文字）；有它时按比重抽、可以重复穿插，只避开刚出的那张和场上的。
    public var weights: [String: Double]?
    /// 已经收过的词卡（按词的文字）：地区里挑词时没收过的优先。
    public var collected: Set<String>

    public init(volume: String?, today: DayIndex, newToday: Int = 0, lengths: [Int: Double] = [2: 1],
                allowedSyllables: Set<String>? = nil, focus: Set<String>? = nil, pool: [ContentWord]? = nil, firstWord: ContentWord? = nil,
                weights: [String: Double]? = nil, collected: Set<String> = []) {
        self.collected = collected
        self.focus = focus
        self.pool = pool
        self.weights = weights
        self.firstWord = firstWord
        self.volume = volume
        self.today = today
        self.newToday = newToday
        self.lengths = lengths
        self.allowedSyllables = allowedSyllables
    }
}

/// 一张牌为什么出现。
public enum DealReason: String, Sendable {
    case replay, review, newInVolume, knownInVolume, filler
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
    public private(set) var context: DealContext
    let content: LearningContent
    var tuning: LearningTuning { learner.tuning }
    var rng: SplitMix

    // 这一场的状态
    var dealt = 0
    var newThisDuel = 0
    /// 这一张想出几个字的（按 context.lengths 抽）；凑不出就退回别的字数。
    var targetLength = 2
    var sinceNew = 99
    var afterMissLeft = 0
    var recentWords: [String] = []
    var recentResults: [Bool] = []
    /// 待复现：拼错的音节，带上拼错时的那个词（先出原词，出不了再找含这个音节的别的词）。
    var replay: [(due: Int, spelling: String, word: String?)] = []
    /// 这一场出过的新音节（第一次出现时记一次「今天新学」）。
    var introduced: Set<String> = []
    /// 其中第一次就又快又对、已经退回名额的。
    var freedNew: Set<String> = []

    public init(content: LearningContent, learner: Learner, context: DealContext, seed: UInt64) {
        self.content = content
        self.learner = learner
        self.context = context
        self.rng = SplitMix(seed: seed)
    }

    // MARK: 音节分类

    /// 新音节：还没碰过、也不是基本功（基本功大多数人已经会，按会的算）。
    public func isNew(_ s: String) -> Bool {
        learner.proficiency(s) == .locked && content.volume(of: s) != "base" && !introduced.contains(s)
    }

    func wordIsEasy(_ w: ContentWord) -> Bool { !w.syllables.contains(where: isNew) && allowed(w) }

    /// 有没有超出这一场许用的音节。
    func allowed(_ w: ContentWord) -> Bool {
        guard let set = context.allowedSyllables else { return true }
        return w.syllables.allSatisfy { set.contains($0) }
    }

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
        targetLength = rollLength()
        if dealt == 0, let w = context.firstWord { return finish(w, .filler) }   // 教学：第一张牌固定
        if let pool = context.pool, !pool.isEmpty, let weights = context.weights {   // 练功房：按比重抽
            let last = recentWords.last
            var cands = pool.filter { !$0.isIdiom && !avoidingTexts.contains($0.text) && $0.text != last }
            if cands.isEmpty { cands = pool.filter { !avoidingTexts.contains($0.text) } }
            if cands.isEmpty { cands = pool }
            return finish(weightedPick(cands, weights), .review)
        }
        if let pool = context.pool, !pool.isEmpty {              // 梦里：只从专门挑的词里出，不探、不排复习
            let fresh = pool.filter { !$0.isIdiom && $0.text.count == targetLength && !recentWords.suffix(tuning.recentWords).contains($0.text)
                && !avoidingTexts.contains($0.text) }
            let any = pool.filter { !$0.isIdiom && !recentWords.suffix(tuning.recentWords).contains($0.text) && !avoidingTexts.contains($0.text) }
            let w = (fresh.isEmpty ? any : fresh).randomElement(using: &rng) ?? pool[0]
            return finish(w, .filler)
        }
        let avoid: (ContentWord) -> Bool = { w in
            avoidingTexts.contains(w.text) || self.recentWords.suffix(self.tuning.recentWords).contains(w.text)
                || avoidingFirstLetters.contains(w.syllables.first?.first ?? " ")
        }
        // 1. 待复现
        if let k = replay.firstIndex(where: { $0.due <= dealt }) {
            let r = replay.remove(at: k)
            if let t = r.word, let w = content.words.first(where: { $0.text == t }), !avoid(w), allowed(w) { return finish(w, .replay) }
            if let w = pickWord(containing: r.spelling, avoid: avoid) { return finish(w, .replay) }
        }
        // 2. 到期复习（地区里按配比，初入江湖没有）
        if context.volume != nil {
            return dealInRegion(avoid: avoid)
        }
        return dealInOpening(avoid: avoid)
    }

    /// 没指定地区、也没有词池：只出全是会的音节的高频词。
    func dealInOpening(avoid: (ContentWord) -> Bool) -> DealtWord {
        finish(pickEasy(avoid: avoid, topN: 400), .filler)
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
        let inVol = content.syllables(in: vol).map(\.spelling).filter { context.focus?.contains($0) ?? true }
        let newOnes = inVol.filter(isNew)
        let knownOnes = inVol.filter { !isNew($0) }
        let pNew = t.mixNew / (t.mixKnown + t.mixNew + t.mixFiller)
        let pKnown = t.mixKnown / (t.mixKnown + t.mixNew + t.mixFiller)
        let r2 = Double(rng.next() % 10_000) / 10_000
        func dealNew() -> DealtWord? {
            guard newAllowed, !newOnes.isEmpty else { return nil }
            for s in newOnes.sorted(by: { content.commonChars(of: $0).count > content.commonChars(of: $1).count }).prefix(t.newPickTop).shuffled(using: &rng) {
                if let w = pickWord(containing: s, avoid: avoid, allowNew: s) { return finish(w, .newInVolume) }
            }
            return nil
        }
        if r2 < pNew, let w = dealNew() { return w }
        if r2 < pNew + pKnown || (r2 < pNew + pKnown + 0.01) {
            for s in knownOnes.shuffled(using: &rng) {
                if let w = pickWord(containing: s, avoid: avoid) { return finish(w, .knownInVolume) }
            }
            // 本卷还凑不出会的牌（刚进这一关）：护栏允许就先带一个新的进来，不拿垫底凑
            if context.allowedSyllables != nil, let w = dealNew() { return w }
        }
        return finish(pickEasy(avoid: avoid, topN: 600), .filler)
    }

    func weightedPick(_ words: [ContentWord], _ weights: [String: Double]) -> ContentWord {
        let ws = words.map { max(0.01, weights[$0.text] ?? PracticeWeights.floor) }
        var r = Double(rng.next() % 1_000_000) / 1_000_000 * ws.reduce(0, +)
        for (w, x) in zip(words, ws) {
            if r < x { return w }
            r -= x
        }
        return words[words.count - 1]
    }

    func rollLength() -> Int {
        let total = context.lengths.values.reduce(0, +)
        guard total > 0 else { return 2 }
        var r = Double(rng.next() % 10_000) / 10_000 * total
        for (n, w) in context.lengths.sorted(by: { $0.key < $1.key }) {
            if r < w { return n }
            r -= w
        }
        return 2
    }

    /// 含这个音节的常用词：其余音节都不能是新的（allowNew 指定的那个除外）；先按想要的字数挑。
    func pickWord(containing s: String, avoid: (ContentWord) -> Bool, allowNew: String? = nil) -> ContentWord? {
        let idx = content.wordsBySyllable[s] ?? []
        let ok = idx.map { content.words[$0] }.filter { w in
            !avoid(w) && allowed(w) && w.syllables.allSatisfy { $0 == allowNew || !isNew($0) }
        }
        let exact = ok.filter { $0.text.count == targetLength }
        if !exact.isEmpty { return preferFresh(exact) }
        if targetLength > 2 { return nil }                   // 想要长词但这个音节凑不出：让上一级换别的出法
        return preferFresh(ok)
    }

    /// 词卡：候选（已按常用程度排好）里，newCardShare 的机会从没收过的里挑最常用的前 3 个之一；
    /// 其余从收过的里随机挑（升熟练、精通交给练功房，这里不专挑快升级的）。没收过的挑完了就一直出收过的，反过来也一样。
    func preferFresh(_ words: [ContentWord]) -> ContentWord? {
        let fresh = words.filter { !context.collected.contains($0.text) }
        let old = words.filter { context.collected.contains($0.text) }
        let roll = Double(rng.next() % 10_000) / 10_000
        if !fresh.isEmpty && (old.isEmpty || roll < tuning.newCardShare) { return fresh.prefix(3).randomElement(using: &rng) }
        return old.randomElement(using: &rng) ?? fresh.prefix(3).randomElement(using: &rng)
    }

    /// 垫底的候选不按常用程度挑最前面的，在里面随机：没收过的照样优先。
    func preferFreshAmong(_ words: [ContentWord]) -> ContentWord? {
        let fresh = words.filter { !context.collected.contains($0.text) }
        let roll = Double(rng.next() % 10_000) / 10_000
        if !fresh.isEmpty && roll < tuning.newCardShare { return fresh.randomElement(using: &rng) }
        return words.randomElement(using: &rng)
    }

    /// 垫底：全是会的音节的高频词（先按想要的字数挑，凑不出退回二字）。
    func pickEasy(avoid: (ContentWord) -> Bool, topN: Int) -> ContentWord {
        if targetLength > 2 {
            let long = content.words.filter { !$0.isIdiom && $0.text.count == targetLength && wordIsEasy($0) && !avoid($0) }
            if let w = preferFreshAmong(Array(long.prefix(40))) { return w }
        }
        let pool = content.words.filter { !$0.isIdiom && $0.text.count == 2 && $0.freq <= topN && wordIsEasy($0) && !avoid($0) }
        if let w = preferFreshAmong(pool) { return w }
        return content.words.first { !$0.isIdiom && wordIsEasy($0) && !avoid($0) } ?? content.words[0]
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
        if let pool = context.pool, let w = pool.filter(\.isIdiom).randomElement(using: &rng) { return w }
        if let pool = context.pool, context.weights != nil, !pool.isEmpty {   // 练功房没有成语：用打过的最长的几个词
            let longest = pool.sorted { $0.text.count > $1.text.count }
            return Array(longest.prefix(6)).randomElement(using: &rng) ?? pool[0]
        }
        let idioms = content.idioms
        let easy = idioms.filter(wordIsEasy).prefix(40)
        if !easy.isEmpty { return Array(easy).randomElement(using: &rng)! }
        if context.allowedSyllables != nil {
            // 第一关凑不出成语：用许用音节里最长的词当必杀
            let longest = content.words.filter { !$0.isIdiom && allowed($0) }.sorted { $0.text.count != $1.text.count ? $0.text.count > $1.text.count : $0.freq < $1.freq }
            if let w = longest.prefix(6).randomElement(using: &rng) { return w }
        }
        return Array(idioms.prefix(40)).randomElement(using: &rng) ?? idioms[0]
    }

    // MARK: 回报

    /// 一张牌打完：有没有打错或看提示。这一场刚带进来的新音节，第一次就又快又对（每个字母不超过 knownSecondsPerLetter 秒）
    /// 算本来就会：不占这一场和今天的新音节名额（拼音熟的人不被名额卡住）。
    public func note(_ w: ContentWord, clean: Bool, secondsPerLetter: Double? = nil) {
        recentResults.append(clean)
        if recentResults.count > 60 { recentResults.removeFirst() }
        if !clean { afterMissLeft = tuning.afterMissKnown }
        if clean, let spl = secondsPerLetter, spl <= tuning.knownSecondsPerLetter {
            let known = Set(w.syllables).filter { introduced.contains($0) && !freedNew.contains($0) }
            freedNew.formUnion(known)
            newThisDuel = max(0, newThisDuel - known.count)
            context.newToday = max(0, context.newToday - known.count)
        }
    }

    /// 一个音节拼错了（新招）：接下来第几张复现它，先出拼错的那个词。
    public func newMove(_ s: String, word: String? = nil) {
        for k in tuning.replayOffsets { replay.append((due: dealt + k - 1, spelling: s, word: word)) }
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
