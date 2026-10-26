import DuelCore
import Foundation
import Observation
import QuartzCore

/// 打文字的试玩版：内容是古诗、古文、散文和好文章的节选（不再用家书这类生活短文）。
/// 短句（奇遇，比如亭子墙上的题壁诗）和文章（下一篇，和之前的你比速度）用同一套打法：一句一张牌，只有上面不一样。
/// 和比武共用键盘、拨弦声、读音键、亮下一个键、打完一个字迸粒子；没有血条、蓄力、气和必杀。
@MainActor
@Observable
final class TextController: KeyTarget {
    struct Passage: Decodable {
        let id: String
        let kind: String            // "encounter" 奇遇短句，"article" 下一篇文章
        let title: String
        let intro: String
        /// 出处：作者和篇名，如「李白《静夜思》」。
        let source: String?
        let reply: String
        let text: String
        let syllables: [String]
    }

    /// 按标点切出来的一句：每个字、它的拼音、句末的标点。
    struct Sentence: Equatable {
        let chars: [Character]
        let syllables: [String]
        let punct: String
        var text: String { String(chars) + punct }
        var letters: [Character] { Array(syllables.joined()) }
    }

    /// 试玩用的篇目：短句是内容包里的第一段奇遇，文章是内容包里的「下一篇」。
    @MainActor static let passages: [Passage] = {
        let c = AppResources.content
        var out: [Passage] = []
        if let e = c.encounters.first {
            out.append(Passage(id: e.id, kind: "encounter", title: "奇遇 · \(e.title)", intro: e.intro, source: e.source,
                               reply: e.reply, text: e.text, syllables: e.syllables))
        }
        if let a = c.articles.first {
            out.append(Passage(id: a.id, kind: "article", title: a.title ?? "下一篇", intro: a.intro ?? "", source: a.source,
                               reply: "", text: a.text, syllables: a.syllables))
        }
        return out
    }()

    static let punctuation: Set<Character> = ["，", "。", "！", "？", "、", "；", "："]

    static func sentences(of p: Passage) -> [Sentence] {
        var out: [Sentence] = []
        var chars: [Character] = [], syl: [String] = []
        var k = 0
        for ch in p.text {
            if punctuation.contains(ch) {
                if !chars.isEmpty { out.append(Sentence(chars: chars, syllables: syl, punct: String(ch))) }
                chars = []; syl = []
            } else {
                chars.append(ch)
                syl.append(k < p.syllables.count ? p.syllables[k] : "")
                k += 1
            }
        }
        if !chars.isEmpty { out.append(Sentence(chars: chars, syllables: syl, punct: "")) }
        return out
    }

    // MARK: 状态

    let c: DuelController
    private(set) var passage: Passage?
    private(set) var sentences: [Sentence] = []
    /// 正在打第几句、这一句打到第几个字母。
    private(set) var index = 0
    private(set) var typed = 0
    /// 打完一句的那一下（短句：半秒的原位快爆；文章：一闪）。
    private(set) var flash = 0
    private(set) var flashPerfect = false
    /// 打错时词牌抖一下。
    private(set) var shake = 0
    private(set) var startedAt: Double?
    private(set) var finishedAt: Double?
    private(set) var perfects = 0
    /// 不要回顾时，打完一句等最后一个字的动效（变红、弹一下、迸粒子）演完再换下一句。
    static let lastCharBeat = 0.35
    /// 翻页钟：刚打完的是第几句、从什么时候开始翻（界面按它画上下两半翻页）。
    private(set) var flipFrom: Int?
    private(set) var flipAt: Double = -10
    /// 打完一句后，演完（快爆或回顾）之前不收字。
    private var lockedUntil: Double = 0
    /// 战斗动效：打完一句的回顾牌（和比武同一个回顾层画）。
    private(set) var reviews: [DuelController.Review] = []
    @ObservationIgnored private var reviewSeq = 0
    /// 回顾牌盖着这句牌的时候，这句牌藏起来。
    var covered: Bool { reviews.contains { !$0.leaving } }
    /// 用比武的字和拼音列（下划线、打完一个字变红迸粒子）。
    var battleStyle: Bool { c.tuning.textStyle >= 1 }
    /// 打完一句翻回顾牌。
    var withReview: Bool { c.tuning.textStyle == 1 }
    /// 不要回顾时，打完一句在牌角弹一下「完美」（记下时刻，界面按它淡出）。
    private(set) var perfectAt: Double = -10

    /// 当前这句做成比武的词牌数据（下划线、变红、回顾都用它）。
    func card(typed n: Int? = nil) -> DuelController.CardVM? {
        guard let s = current else { return nil }
        return DuelController.CardVM(id: index, text: String(s.chars), syllables: s.syllables,
                                     typed: String(s.letters.prefix(n ?? typed)), weight: "", volumeLabel: "",
                                     store: 1, flaw: false, finisher: false, locked: true, inactive: false)
    }
    private var sentenceStart: Double = 0
    private var sentenceMistakes = 0
    private var sentenceHinted = false
    private var lastAcceptedAt: Double = 0
    private var hintShown = false
    @ObservationIgnored private weak var keyboard: KeyboardView?
    @ObservationIgnored private let speaker = Speaker()
    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// 之前的你：上一次打这一篇的速度（字/分），第一次用 20。
    private(set) var ghostCPM: Double = 20
    private(set) var now: Double = 0

    var isArticle: Bool { passage?.kind == "article" }
    var current: Sentence? { sentences.indices.contains(index) ? sentences[index] : nil }
    var totalChars: Int { sentences.reduce(0) { $0 + $1.chars.count } }
    var charsDone: Int {
        let before = sentences.prefix(index).reduce(0) { $0 + $1.chars.count }
        guard let s = current else { return before }
        var left = typed, n = 0
        for syl in s.syllables { if left >= syl.count { n += 1; left -= syl.count } else { break } }
        return before + n
    }
    var elapsed: Double { guard let s = startedAt else { return 0 }; return (finishedAt ?? now) - s }
    var cpm: Double { elapsed > 1 ? Double(charsDone) / (elapsed / 60) : 0 }
    var ghostChars: Double { min(Double(totalChars), elapsed / 60 * ghostCPM) }
    var finished: Bool { finishedAt != nil }

    init(c: DuelController) { self.c = c }

    /// 旅程的奇遇：打完回调（交回每句干不干净，用来记学习）。
    @ObservationIgnored var onFinish: ((TextController) -> Void)?
    /// 每句打完时：没打错、没看提示。
    private(set) var sentenceClean: [Bool] = []
    /// 旅程给的篇目（nil = 按「打什么」从内容包取）。
    @ObservationIgnored var given: Passage?

    // MARK: 开始

    func start(mode: Int) {
        let kind = mode == 2 ? "article" : "encounter"
        passage = given ?? Self.passages.first { $0.kind == kind }
        sentenceClean = []
        sentences = passage.map(Self.sentences(of:)) ?? []
        index = 0; typed = 0; perfects = 0; reviews = []; flipFrom = nil
        startedAt = nil; finishedAt = nil
        lockedUntil = 0; sentenceMistakes = 0; sentenceHinted = false; hintShown = false
        if let id = passage?.id, let v = UserDefaults.standard.object(forKey: "ghostCPM.\(id)") as? Double { ghostCPM = v } else { ghostCPM = 20 }
        keyboard?.showHint(nil)
        if ProcessInfo.processInfo.arguments.contains("-autoplay") { autoplay() }
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                self?.tick()
            }
        }
    }

    func stop() { ticker?.cancel(); ticker = nil; auto?.cancel(); auto = nil }

    @ObservationIgnored private var auto: Task<Void, Never>?

    /// 演示用（-autoplay 启动参数）：一个字母一个字母照着打，每句之间停一下。
    func autoplay() {
        auto?.cancel()
        auto = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.0))
            while !Task.isCancelled, let self, !self.finished {
                guard let s = self.current, self.typed < s.letters.count else {
                    try? await Task.sleep(for: .milliseconds(120)); continue
                }
                let ch = s.letters[self.typed]
                let now = CACurrentMediaTime()
                self.key(KeyEvent(kind: .letter(ch), downAt: now, upAt: now, commitAt: now))
                try? await Task.sleep(for: .milliseconds(self.typed == 0 ? 500 : 150))
            }
        }
    }

    /// 每 0.1 秒：走表；卡住 2 秒亮出下一个键。
    private func tick() {
        now = CACurrentMediaTime()
        guard startedAt != nil, !finished, !hintShown, now - lastAcceptedAt >= c.tuning.hintSeconds, c.tuning.hintSeconds > 0,
              let s = current, typed < s.letters.count, typed > 0 || index > 0 else { return }
        hintShown = true
        sentenceHinted = true
        keyboard?.showHint(s.letters[typed])
    }

    // MARK: 键盘

    func attach(keyboard: KeyboardView) {
        self.keyboard = keyboard
        keyboard.onKey = { [weak self] ev in self?.key(ev) }
        keyboard.expectedLetters = { [weak self] in
            guard let self, let s = self.current, self.typed < s.letters.count else { return [] }
            return [s.letters[self.typed]]
        }
        keyboard.tuning = { [weak self] in self?.c.tuning ?? .standard }
    }

    func key(_ ev: KeyEvent) {
        guard !finished, let s = current else { return }
        let t = CACurrentMediaTime()
        now = t
        switch ev.kind {
        case .teach:                                     // 读音：读这一句，再读正在打的字
            let k = charIndex(in: s)
            speaker.say(word: String(s.chars), character: k < s.chars.count ? String(s.chars[k]) : "")
        case .backspace:
            break
        case .letter(let raw):
            guard t >= lockedUntil else { return }
            let ch = Character(raw.lowercased())
            if startedAt == nil { startedAt = t; sentenceStart = t; lastAcceptedAt = t }
            if ch == s.letters[typed] {
                typed += 1
                lastAcceptedAt = t
                hintShown = false
                keyboard?.showHint(nil)
                c.sounds.tick(min(7, letterInSyllable(s)))
                if typed == s.letters.count { finishSentence(at: t) }
            } else {
                sentenceMistakes += 1
                shake += 1
                c.sounds.play(.mistake)
                keyboard?.showHint(s.letters[typed])     // 打错马上亮出下一个键
                hintShown = true
                sentenceHinted = true
            }
        }
    }

    private func charIndex(in s: Sentence) -> Int {
        var left = typed
        for (k, syl) in s.syllables.enumerated() { if left < syl.count { return k }; left -= syl.count }
        return s.chars.count
    }

    /// 刚打的这个字母是这个音节里的第几个（音高按它往上走，换一个字重新起）。
    private func letterInSyllable(_ s: Sentence) -> Int {
        var left = typed
        for syl in s.syllables { if left <= syl.count { return left - 1 }; left -= syl.count }
        return 0
    }

    private func finishSentence(at t: Double) {
        guard let s = current else { return }
        let perLetter = (t - sentenceStart) / Double(max(1, s.letters.count))
        flashPerfect = sentenceMistakes == 0 && !sentenceHinted && perLetter <= c.tuning.goldSecondsPerLetter
        sentenceClean.append(sentenceMistakes == 0 && !sentenceHinted)
        if flashPerfect { perfects += 1 }
        let last = index == sentences.count - 1
        if withReview { review(s, perfect: flashPerfect, last: last, at: t); return }
        if battleStyle {                                  // 不要回顾：一声命中，等最后一个字变红、弹一下、迸粒子演完再出下一句
            if flashPerfect { perfectAt = t }
            c.sounds.play(last ? .hitHeavy : .hitLight)
            c.sounds.hitHaptic(heavy: last)
            lockedUntil = t + Self.lastCharBeat
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.lastCharBeat))
                self.lockedUntil = 0
                self.next(last: last, at: t)
            }
            return
        }
        flash += 1
        c.sounds.play(last ? .hitHeavy : .hitLight)
        c.sounds.hitHaptic(heavy: last)
        lockedUntil = t + 0.45                           // 半秒的原位快爆演完再出下一句（短句、文章一样）
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.45))
            self.next(last: last, at: t)
        }
    }

    /// 下一句（或者打完了）。
    private func next(last: Bool, at t: Double) {
        if last {
            finishedAt = t
            c.sounds.play(.win)
            if isArticle, let id = passage?.id { UserDefaults.standard.set(cpm, forKey: "ghostCPM.\(id)") }
            onFinish?(self)
            return
        }
        flipFrom = index                                  // 翻页钟：刚打完的这句从这一刻翻下去
        flipAt = CACurrentMediaTime()
        index += 1
        typed = 0
        sentenceMistakes = 0
        sentenceHinted = false
        sentenceStart = CACurrentMediaTime()
        lastAcceptedAt = sentenceStart
    }

    /// 战斗动效：和比武打完一张牌一样——先定格，翻成回顾牌，一个字母一个字母爆开（节奏同主角出刀），完美的盖印，停一会儿收掉。
    private func review(_ s: Sentence, perfect: Bool, last: Bool, at t: Double) {
        guard let full = card(typed: s.letters.count), let before = card(typed: s.letters.count - 1) else { return }
        lockedUntil = .infinity
        reviewSeq += 1
        let rid = reviewSeq
        var r = DuelController.Review(id: rid, slot: 0, card: full, intro: before)
        r.gold = perfect
        reviews = [r]
        let n = s.letters.count
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.02))
            if let k = self.reviews.firstIndex(where: { $0.id == rid }) { self.reviews[k].intro = full }
            self.c.sounds.hitHaptic(heavy: false)
            try? await Task.sleep(for: .seconds(DuelController.finishBeat))
            let per = n <= 5 ? 0.1 : max(self.c.tuning.slashMinGap, 0.6 / Double(n))
            let times = FigureNode.slashTimes(slashes: n, per: per)
            let base = Date().timeIntervalSinceReferenceDate
            if let k = self.reviews.firstIndex(where: { $0.id == rid }) { self.reviews[k].popAt = times.map { base + $0 } }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(max(0, times[0] - 0.2)))
                if let k = self.reviews.firstIndex(where: { $0.id == rid }) { self.reviews[k].phase = 1 }
            }
            for (k, at) in times.enumerated() {           // 每爆一个字母一声，最后一个重重落下
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(at))
                    if k == n - 1 {
                        self.c.sounds.play(.hitHeavy)
                        self.c.sounds.hitHaptic(heavy: true)
                    } else {
                        self.c.sounds.play(.hitLight)
                        self.c.sounds.tick(min(7, k))
                        self.c.sounds.hitHaptic(heavy: false)
                    }
                }
            }
            try? await Task.sleep(for: .seconds((times.last ?? 0) + DuelController.reviewHold))
            if let k = self.reviews.firstIndex(where: { $0.id == rid }) { self.reviews[k].leaving = true }
            try? await Task.sleep(for: .seconds(0.2))
            self.reviews.removeAll { $0.id == rid }
            self.lockedUntil = 0
            self.next(last: last, at: CACurrentMediaTime())
        }
    }
}
