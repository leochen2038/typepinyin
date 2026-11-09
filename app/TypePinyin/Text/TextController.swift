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
    /// 打完一句怎么换下一句（3、4、5 三种动效；最后一句都是原位翻回顾牌、重重一击收尾）：
    /// 边打边爆（fly）：打完的这句往上翻走、一路爆字母，下一句同时升上来、马上能打；
    /// 同行边爆边出（sweep）：打完的这句留在原位，一道刀光从左往右扫过，扫过的地方旧句子一个字一个字爆开、新的一句跟着露出来，马上能打。
    enum Outro { case fly, sweep }
    var burstMode: Bool { (3...5).contains(c.tuning.textStyle) }
    /// 第 i 句打完用哪一种：3 都飞走，4 都扫掉，5 交替（第一句飞走、第二句扫掉……）。
    func outro(_ i: Int) -> Outro {
        switch c.tuning.textStyle {
        case 4: return .sweep
        case 5: return i % 2 == 0 ? .fly : .sweep
        default: return .fly
        }
    }
    /// 这一句是从下面升上来的（上一句飞走了；第一句除了「都扫掉」也升上来），还是原位露出来的（上一句被扫掉）。
    var rollsIn: Bool { index == 0 ? c.tuning.textStyle != 4 : outro(index - 1) == .fly }
    /// 同行边爆边出的一次扫：旧的这句、刀光开始扫的时刻（Date 的钟，和 TimelineView 一致）、扫多久。
    struct Sweep: Equatable, Identifiable {
        let id: Int
        let old: DuelController.CardVM
        let start: Double
        let duration: Double
        /// 扫到哪儿了（0 = 左边、1 = 右边），匀速，像引线烧过去。
        func progress(at now: Double) -> Double { min(1, max(0, (now - start) / duration)) }
    }
    /// 同行边爆边出：正在扫的（扫完了粒子还要飞一会儿，留到粒子落完）。
    private(set) var sweeps: [Sweep] = []
    /// 边打边爆：正往上飞的句子（和比武的回顾牌同一种画法）。
    private(set) var bursts: [DuelController.Review] = []
    /// 边打边爆：这一句升上来的时刻。
    private(set) var enterAt: Double = -10
    /// 边打边爆：全篇最后一个字母落下的时刻（冲击帧、震屏按它演；-10 = 没有）。
    private(set) var impactAt: Double = -10
    /// 边打边爆：打完最后一个字母的时刻。用时和速度算到这里，收尾的动效不算进去。
    private var typingDoneAt: Double?
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
    /// 练习场的文章：和最好的你比。每篇记下打完时最好的速度（字/分，按设备存）；没打完过的篇目不比，打完一次下次就有。
    @ObservationIgnored var raceBest = false
    /// 这一篇以前打完时最好的速度（nil = 还没打完过）。
    private(set) var bestCPM: Double?
    /// 打完这一次时：以前最好的（nil = 第一次打完）、这次是不是新纪录。
    private(set) var previousBest: Double?
    private(set) var newBest = false
    static func bestKey(_ id: String) -> String { "bestCPM.\(id)" }
    /// 练习场列表上写的：这一篇最好的速度。
    static func best(of id: String) -> Double? { UserDefaults.standard.object(forKey: bestKey(id)) as? Double }
    var current: Sentence? { sentences.indices.contains(index) ? sentences[index] : nil }
    var totalChars: Int { sentences.reduce(0) { $0 + $1.chars.count } }
    var charsDone: Int {
        let before = sentences.prefix(index).reduce(0) { $0 + $1.chars.count }
        guard let s = current else { return before }
        var left = typed, n = 0
        for syl in s.syllables { if left >= syl.count { n += 1; left -= syl.count } else { break } }
        return before + n
    }
    var elapsed: Double { guard let s = startedAt else { return 0 }; return (finishedAt ?? typingDoneAt ?? now) - s }
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
    /// 教学：键盘一直亮着下一个该按的键（新开场的镇口木牌）；亮着的不算看过提示。
    @ObservationIgnored var guided = false
    /// 只在这些音节上亮着下一个键（碑文里还没碰到过的音节）；别的照常（卡住或打错才亮）。
    @ObservationIgnored var guideSyllables: Set<String> = []

    /// 现在这个字要不要一直亮着下一个键。
    private func guiding(_ s: Sentence) -> Bool {
        if guided { return true }
        let k = charIndex(in: s)
        return k < s.syllables.count && guideSyllables.contains(s.syllables[k])
    }

    // MARK: 开始

    func start(mode: Int) {
        let kind = mode == 2 ? "article" : "encounter"
        passage = given ?? Self.passages.first { $0.kind == kind }
        sentenceClean = []
        sentences = passage.map(Self.sentences(of:)) ?? []
        index = 0; typed = 0; perfects = 0; reviews = []; flipFrom = nil
        bursts = []; sweeps = []; enterAt = CACurrentMediaTime(); impactAt = -10; typingDoneAt = nil
        startedAt = nil; finishedAt = nil
        lockedUntil = 0; sentenceMistakes = 0; sentenceHinted = false; hintShown = false
        if let id = passage?.id, let v = UserDefaults.standard.object(forKey: "ghostCPM.\(id)") as? Double { ghostCPM = v } else { ghostCPM = 20 }
        bestCPM = raceBest ? passage.flatMap { Self.best(of: $0.id) } : nil
        previousBest = nil; newBest = false
        if raceBest, let b = bestCPM { ghostCPM = b }
        keyboard?.showHint(nil)
        if ProcessInfo.processInfo.arguments.contains("-autoplay") { autoplay() }
        startPerfLink()
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                self?.tick()
            }
        }
    }

    func stop() { ticker?.cancel(); ticker = nil; auto?.cancel(); auto = nil; perfLink?.invalidate(); perfLink = nil }

    /// 测卡顿（-perflog）：每帧记一下隔了多久，飞句子、回顾的时候单算。
    @ObservationIgnored private var perfLink: CADisplayLink?
    private func startPerfLink() {
        guard PerfLog.on, perfLink == nil else { return }
        let l = CADisplayLink(target: DisplayLinkProxy { [weak self] l in
            guard let self else { return }
            PerfLog.frame(at: l.timestamp, expected: l.targetTimestamp - l.timestamp, inReview: !self.bursts.isEmpty || !self.reviews.isEmpty)
        }, selector: #selector(DisplayLinkProxy.fire(_:)))
        l.add(to: .main, forMode: .common)
        perfLink = l
    }

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
        if !finished, !hintShown, let s = current, typed < s.letters.count, guiding(s) {
            hintShown = true
            keyboard?.showHint(s.letters[typed])
            return
        }
        if guided { return }
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
                if typed < s.letters.count, guiding(s) {      // 教学：马上亮下一个键，不等下一次走表
                    keyboard?.showHint(s.letters[typed])
                    hintShown = true
                }
                c.sounds.tick(min(7, letterInSyllable(s)))
                if typed == s.letters.count {
                    finishSentence(at: t)
                } else if c.tuning.textCharHit && charIndex(in: s) > charIndex(before: typed - 1, in: s) {
                    c.sounds.play(.hitLight)                 // 打完一个字（不是这句最后一个）：和最后一个字一样一声命中、震一下
                    c.sounds.hitHaptic(heavy: false)
                }
            } else {
                sentenceMistakes += 1
                shake += 1
                c.sounds.play(.mistake)
                keyboard?.showHint(s.letters[typed])     // 打错马上亮出下一个键
                hintShown = true
                if !guiding(s) { sentenceHinted = true }
            }
        }
    }

    private func charIndex(in s: Sentence) -> Int { charIndex(before: typed, in: s) }

    /// 打了 n 个字母时，正在打第几个字。
    private func charIndex(before n: Int, in s: Sentence) -> Int {
        var left = n
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
        if burstMode {
            if last {
                typingDoneAt = t
                review(s, perfect: flashPerfect, last: true, at: t, heavy: true)
            } else {
                if outro(index) == .fly { fly(s, perfect: flashPerfect) } else { sweepOut(s, perfect: flashPerfect) }
                next(last: false, at: t)
            }
            return
        }
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
            if raceBest, let id = passage?.id, cpm >= 1 {   // 练习场：比以前最好的快就记下
                previousBest = bestCPM
                if bestCPM.map({ cpm.rounded() > $0.rounded() }) ?? true {   // 按显示的整数比：别出现「速度 126、最好 126」还说快了
                    newBest = bestCPM != nil
                    UserDefaults.standard.set(cpm, forKey: Self.bestKey(id))
                }
            }
            onFinish?(self)
            return
        }
        if burstMode {
            enterAt = CACurrentMediaTime()                // 不翻页：飞走的话下一句从下面升上来，扫掉的话下一句就在原位、刀光扫过去才露出来
        } else {
            flipFrom = index                              // 翻页钟：刚打完的这句从这一刻翻下去
            flipAt = CACurrentMediaTime()
        }
        index += 1
        typed = 0
        sentenceMistakes = 0
        sentenceHinted = false
        sentenceStart = CACurrentMediaTime()
        lastAcceptedAt = sentenceStart
    }

    /// 战斗动效：和比武打完一张牌一样——先定格，翻成回顾牌，一个字母一个字母爆开（节奏同主角出刀），完美的盖印，停一会儿收掉。
    /// heavy（边打边爆的最后一句）：最后一个字母落下时和比武最后一刀一样——必杀那一声、重震，冲击帧加震屏；用时按打完的那一刻算。
    private func review(_ s: Sentence, perfect: Bool, last: Bool, at t: Double, heavy: Bool = false) {
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
                    if k == n - 1 && heavy {
                        self.c.sounds.play(.finisher)
                        self.c.sounds.finisherHaptic()
                        self.impactAt = CACurrentMediaTime()
                    } else if k == n - 1 {
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
            self.next(last: last, at: heavy ? t : CACurrentMediaTime())
        }
    }

    /// 同行边爆边出的一句：先顿一下（同边打边爆，新牌在这一帧建好），刀光再用 0.4 秒从左扫到右；
    /// 扫到一个字，这个字连拼音一起爆开（一圈白光、放大淡掉、迸彩纸），一声，音一个比一个高。完美的扫完重重一声、牌角弹「完美」。
    static let sweepDuration = 0.4
    private func sweepOut(_ s: Sentence, perfect: Bool) {
        guard let full = card(typed: s.letters.count) else { return }
        reviewSeq += 1
        let id = reviewSeq
        let d = Self.sweepDuration
        sweeps.append(Sweep(id: id, old: full, start: Date().timeIntervalSinceReferenceDate + Self.popDelay, duration: d))
        c.sounds.play(.hitLight)
        c.sounds.hitHaptic(heavy: false)
        let n = s.chars.count
        for k in 0..<n {                                  // 字大致等宽：第 k 个字在 (k + 0.5) / n 处被扫到
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Self.popDelay + d * (Double(k) + 0.5) / Double(n)))
                self.c.sounds.tick(min(7, k))
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.popDelay + d))
            if perfect {
                self.perfectAt = CACurrentMediaTime()
                self.c.sounds.play(.hitHeavy)
                self.c.sounds.hitHaptic(heavy: true)
            }
            try? await Task.sleep(for: .seconds(1.2))      // 彩纸落完再收
            self.sweeps.removeAll { $0.id == id }
        }
    }

    // Motion Prompt #156 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#156
    /// 边打边爆的一句（参考 Motion Prompt #156 テキストロール）：打完的这句往上翻出去，同时下一句从下面升上来；
    /// 翻走的这句一个字母接一个字母爆开（原版每个字母错开 0.035 秒，这里整句最多 0.35 秒爆完），每爆完一个字一声，音一个比一个高。
    /// 完美的这句爆完盖「完美」印、再重重一声，多停一会儿；然后放大散去。
    static let popGap = 0.035
    static let popSpan = 0.35
    static let popDelay = 0.08
    private func fly(_ s: Sentence, perfect: Bool) { PerfLog.measure("飞句子（排）") { flyNow(s, perfect: perfect) } }
    private func flyNow(_ s: Sentence, perfect: Bool) {
        guard let full = card(typed: s.letters.count) else { return }
        reviewSeq += 1
        let rid = reviewSeq
        var r = DuelController.Review(id: rid, slot: 0, card: full, intro: full)
        r.phase = 1
        r.gold = perfect
        let n = s.letters.count
        let gap = n > 1 ? min(Self.popGap, Self.popSpan / Double(n - 1)) : 0
        let times = (0..<n).map { Self.popDelay + Double($0) * gap }
        let base = Date().timeIntervalSinceReferenceDate
        r.popAt = times.map { base + $0 }
        bursts.append(r)
        c.sounds.play(.hitLight)
        c.sounds.hitHaptic(heavy: false)
        var end = 0
        for (k, syl) in s.syllables.enumerated() {        // 每个字的最后一个字母爆开时一声
            end += syl.count
            let at = times[min(n - 1, end - 1)]
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(at))
                self.c.sounds.tick(min(7, k))
            }
        }
        let done = times.last ?? 0
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(done))
            if perfect {
                self.c.sounds.play(.hitHeavy)
                self.c.sounds.hitHaptic(heavy: true)
            }
            try? await Task.sleep(for: .seconds(perfect ? 0.45 : 0.2))
            if let k = self.bursts.firstIndex(where: { $0.id == rid }) { self.bursts[k].leaving = true }
            try? await Task.sleep(for: .seconds(0.2))
            self.bursts.removeAll { $0.id == rid }
        }
    }
}
