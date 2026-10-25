import DuelCore
import Observation
import QuartzCore
import SpriteKit
import UIKit

/// 驱动一场比武：按键一到就交给引擎（触摸都在主线程，按时间先后到达），
/// 每帧推进时间，把引擎事件变成画面、声音和震动。
@Observable
@MainActor
final class DuelController {
    struct CardVM: Equatable, Identifiable {
        var id: Int
        var text: String
        var syllables: [String]
        var typed: String
        var weight: String
        var volumeLabel: String
        var store: Double
        var flaw: Bool
        var finisher: Bool
        var locked: Bool
        var inactive: Bool
    }

    struct IncomingVM: Equatable {
        var text: String
        var typed: String
        var locked: Bool
    }

    private(set) var cards: [CardVM] = []
    private(set) var playerHP = 100
    private(set) var playerMaxHP = 100
    private(set) var qi = 0
    private(set) var combo = 0
    private(set) var foeHP = 1
    private(set) var foeMaxHP = 1
    /// 命数：界面上显示的还剩几条（最后一刀落下时才减）、开场几条。
    private(set) var foeLives = 1
    private(set) var foeMaxLives = 1
    /// 丢了一条命、对手还跪着：血条停在空的，站起来再满上。
    private(set) var knockdownHold = false
    private(set) var foeName = "林大"
    private(set) var foeTitle = "镇上的镖师"
    private(set) var incoming: IncomingVM?
    private(set) var incomingProgress: Double = 0
    private(set) var hint = ""
    private(set) var summary: DuelSummary?
    private(set) var pausedForBackground = false
    private(set) var elapsed: Double = 0
    private(set) var newMoveToast: String?
    private(set) var mistakeFlash = 0
    private(set) var stunned = false
    /// 气势档位 0–3：连招到 3、8、15 各升一档。
    private(set) var heat = 0
    /// 这一场每招是否金色（状态栏的小圆点）。
    private(set) var moveMarks: [Bool] = []
    /// 哪几招是必杀（第几招，从 0 数）。
    private(set) var finisherMoves: Set<Int> = []
    private(set) var movesPerDuel = 10
    private(set) var nearMissToast = 0
    private(set) var finaleBanner = false
    /// 打空对手血条的那一刀落下时，屏幕上打出「绝杀！」。
    private(set) var killBanner = false
    /// 上一场用时（打赢的那场），没有就是 nil。
    private(set) var lastDuelSeconds: Double?
    /// 这一场比上一场快了几秒（只在更快时有值，只报收获）。
    private(set) var fasterBy: Double?
    @ObservationIgnored private var grabSeq = 0
    /// 取字：主角用空着的后手把刚按的字母从键上取回来（剑气或绳镖，界面层负责画）。时间都用 Date 的钟，和 TimelineView 一致。
    /// 每个字母一次（Grab）：扬手 ropeWind 秒；出去 ropeOut 秒（镖飞到键上 / 气线连到字母）；停 ropeHold 秒；拽回 ropeBack 秒。
    /// bend 是剑气拽回时随机的弯（-1…1，正负是往哪边弯）。
    struct Grab: Equatable, Identifiable { let id: Int; let letter: Character; let start: TimeInterval; let bend: Double }
    private(set) var grabs: [Grab] = []
    /// 一个音节一次（Chain）：pressed 是按下的时刻（剑气：字母这时被震出键）；第一个字母从手出去、后面每个从上一个字母接过去（from → at）；
    /// 音节打完在 yankAt 一把拽回。
    struct Hook: Equatable { let letter: Character; let pressed: TimeInterval; let from: TimeInterval; let at: TimeInterval; let bend: Double }
    struct Chain: Equatable, Identifiable { let id: Int; let slot: Int; var hooks: [Hook]; var yankAt: TimeInterval? }
    private(set) var chains: [Chain] = []
    /// 演示用（-slowfx 启动参数）：取字放慢 5 倍，方便在模拟器上逐帧截图。
    static let fxSlow = ProcessInfo.processInfo.arguments.contains("-slowfx") ? 5.0 : 1.0
    /// 绳镖各段时长（秒，没放慢）。场景动画用这个，因为场景自己按 fxSlow 放慢。
    private static let rope = (wind: 0.03, out: 0.08, hold: 0.03, back: 0.12, hop: 0.06, reel: 0.18)
    static let ropeWind = rope.wind * fxSlow
    static let ropeOut = rope.out * fxSlow
    static let ropeHold = rope.hold * fxSlow
    static let ropeBack = rope.back * fxSlow
    static let ropeHop = rope.hop * fxSlow
    static let chainBack = rope.reel * fxSlow
    static let grabFlight = ropeWind + ropeOut + ropeHold + ropeBack
    /// 剑气：字母在键上聚气 qiCharge 秒，再化成一道剑气飞 qiFly 秒打进主角身上。
    /// 一个音节一次时，音节打完先花 qiMerge 秒聚成一团，再整团飞进主角身上。
    static let qiCharge = 0.05 * fxSlow
    static let qiFly = 0.2 * fxSlow
    static let qiMerge = 0.08 * fxSlow
    /// 对手蓄力条（一张牌模式），0–1。
    private(set) var pressure: Double = 0
    /// 回顾牌在最后一刀后停留的秒数（期间一按下一个词的字母就提前收掉）。
    static let reviewHold = 1.0
    /// 打完最后一个字母后先定格这么久（最后一个字变红弹一下、牌放大），再翻成回顾牌、主角出刀。
    static let finishBeat = 0.35
    @ObservationIgnored private var strikesInFlight = 0
    @ObservationIgnored private var pendingWin = false
    /// 打完的牌浮起来回顾：拼音放大，主角每斩一刀，一个字母放大、爆开；最后一刀后飘走。
    struct Review: Equatable, Identifiable {
        let id: Int
        let slot: Int
        let card: CardVM
        var popAt: [Double] = []   // 每个字母爆开的时刻（出刀时按刀的时间表算好；Date 的钟，和 TimelineView 一致）
        var gold = false           // 这一招是金色（收尾时盖「金」字印）
        var intro: CardVM          // 定格时显示的牌（原样的词牌，最后一个字刚打完）
        var phase = 0              // 0 = 定格，1 = 翻成回顾牌
        var leaving = false
        let born = Date().timeIntervalSinceReferenceDate   // 出现的时刻（必杀蓄力时词牌的动效按它算）
    }
    private(set) var reviews: [Review] = [] {
        didSet {
            let s = Set(reviews.filter { !$0.leaving }.map(\.slot))
            guard s != coveredSlots else { return }
            let opened = coveredSlots.subtracting(s)
            coveredSlots = s
            for slot in opened { revealed(slot) }
        }
    }
    /// 正被回顾牌盖住的牌位。单独存一份：回顾每爆一个字母都会改 reviews，词牌不用跟着重算。
    private(set) var coveredSlots: Set<Int> = []

    /// 回顾收掉、新牌露出来：告诉引擎从这一刻开始算上手时间、连招间隔和对手蓄力。
    private func revealed(_ slot: Int) {
        apply(engine.cardRevealed(slot, at: CACurrentMediaTime()))
    }
    @ObservationIgnored private var reviewSeq = 0
    @ObservationIgnored private var lastCards: [Int: CardVM] = [:]

    var tuning: Tuning
    let scene: DuelScene
    let latency = LatencyMeter()
    let sounds = SoundFX()
    let music = MusicLayers()
    private let speaker = Speaker()

    @ObservationIgnored private var engine: DuelEngine
    @ObservationIgnored private var link: CADisplayLink?
    @ObservationIgnored private weak var keyboard: KeyboardView?
    @ObservationIgnored private var round = 0
    @ObservationIgnored private var lastStruck: [Int: String] = [:]
    @ObservationIgnored private let robes: [UIColor] = [UIColor(hex: 0xE2432C), UIColor(hex: 0x3A5096), UIColor(hex: 0x2E9A6A)]

    init(tuning: Tuning) {
        self.tuning = tuning
        self.scene = DuelScene(size: CGSize(width: 390, height: 404))
        self.engine = Self.makeEngine(tuning: tuning, round: 0)
    }

    private static func makeEngine(tuning: Tuning, round: Int) -> DuelEngine {
        let names = [("林大", "镇上的镖师"), ("陈二", "镇上的镖师"), ("金三", "守山门的镖师")]
        let n = names[round % names.count]
        let seed: UInt64 = AppResources.isUITest ? 7 : UInt64(Date().timeIntervalSince1970 * 1000)
        var t = tuning
        if AppResources.isUITest { t.movesPerDuel = 1 }      // UI 测试：一招就赢
        let e = DuelEngine(bank: AppResources.bank, tuning: t, opponent: Opponent(name: n.0, title: n.1), seed: seed)
        e.holdNewCards = true            // 新牌先被回顾牌盖着：露出来才开始计时（见 reviews 的 didSet）
        return e
    }

    // MARK: - 生命周期

    func attach(keyboard: KeyboardView) {
        self.keyboard = keyboard
        keyboard.onKey = { [weak self] ev in self?.key(ev) }
        keyboard.onTouchDown = { [weak self] t in self?.latency.touchDown(t) }
        keyboard.expectedLetters = { [weak self] in self?.engine.expectedLetters ?? [] }
        keyboard.tuning = { [weak self] in self?.tuning ?? .standard }
    }

    func start() {
        // 演示用（-demoMoves N）：一场只打 N 招，模拟器上很快就能看到最后的必杀
        if UserDefaults.standard.object(forKey: "demoMoves") != nil { tuning.movesPerDuel = UserDefaults.standard.integer(forKey: "demoMoves") }
        engine = Self.makeEngine(tuning: tuning, round: round)
        sounds.hapticsOn = true
        scene.groupEnd()                          // 先换回单挑的对手，再换衣服
        scene.setFoe(robe: robes[round % robes.count])
        scene.speed = 1 / Self.fxSlow            // -slowfx：人物动作也一起放慢
        scene.reset()
        if tuning.groupFight && tuning.cardsOnTable <= 1 { scene.groupBegin() }
        summary = nil
        heat = 0
        moveMarks = []
        finisherMoves = []
        fasterBy = nil
        finaleBanner = false
        killBanner = false
        strikesInFlight = 0
        pendingWin = false
        movesPerDuel = tuning.movesPerDuel
        lastDuelSeconds = UserDefaults.standard.object(forKey: "lastDuelSeconds") as? Double
        music.setLevel(0)
        keyboard?.showHint(nil)
        scene.setCharge(0)
        let ev = engine.start(at: CACurrentMediaTime())
        if AppResources.isUITest { setUITestOpponent() }
        apply(ev)
        sync()
        startLink()
        if !AppResources.isUITest { music.start() }
        if ProcessInfo.processInfo.arguments.contains("-autoplay") { autoplay() }
    }

    /// 切去打文字时：比武停表、音乐停掉（回来时 DuelScreen 会重新开一场）。
    func suspend() {
        link?.invalidate()
        link = nil
        music.stop()
    }

    func restart() {
        round += 1
        sounds.play(.retry)
        start()
    }

    private func startLink() {
        link?.invalidate()
        let proxy = DisplayLinkProxy { [weak self] l in self?.tick(l) }
        let l = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.fire(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
    }

    func pauseForBackground() {
        guard summary == nil else { return }
        apply(engine.pause(.background, at: CACurrentMediaTime()))
        if case .paused(.background) = engine.phase { pausedForBackground = true }
        sync()
    }

    func resumeFromBackground() {
        pausedForBackground = false
        apply(engine.resume(at: CACurrentMediaTime()))
        sync()
    }

    /// 演示用（-autoplay 启动参数）：自动按正确的字母打，每招之间停一下，方便在模拟器上截图看动效。
    /// 加 -autostall：每张牌打完第一个字母后停 3 秒，看卡壳提示；加 -demoGrabStyle 0/1：剑气/绳镖，-demoGrabMode 1：一个音节取一次。
    private func autoplay() {
        let stall = ProcessInfo.processInfo.arguments.contains("-autostall")
        if UserDefaults.standard.object(forKey: "demoGrabStyle") != nil { tuning.grabStyle = UserDefaults.standard.integer(forKey: "demoGrabStyle") }
        if UserDefaults.standard.object(forKey: "demoGrabMode") != nil { tuning.grabMode = UserDefaults.standard.integer(forKey: "demoGrabMode") }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            while summary == nil {
                let letter: Character?
                if engine.target == .none {
                    letter = engine.cards.first { !$0.inactive }?.word.firstLetter
                } else {
                    letter = engine.expectedLetters.first
                }
                guard let ch = letter else { try? await Task.sleep(for: .seconds(0.2)); continue }
                let before = engine.moveMarks.count
                let now = CACurrentMediaTime()
                key(KeyEvent(kind: .letter(ch), downAt: now, upAt: now, commitAt: now))
                let pause = engine.moveMarks.count > before ? 2.2 : stall && engine.cards.contains { $0.typed.count == 1 } ? 3.0 : 0.22
                try? await Task.sleep(for: .seconds(pause))
            }
        }
    }

    /// UI 测试：对手血量很低，打完一张牌就赢。
    private func setUITestOpponent() {
        engine.debugSetOpponentHP(1)
    }

    // MARK: - 输入与每帧

    func key(_ ev: KeyEvent) {
        guard summary == nil, !pausedForBackground else { return }
        if case .teach = ev.kind {                  // 左下角是「读音」键：读这个词，再读正在打的字
            sayCurrentWord()
            return
        }
        for (i, c) in engine.cards.enumerated() { lastStruck[i] = c.word.letters }   // 出招后牌会被换掉，先记下是哪个词
        for (i, c) in cards.enumerated() { lastCards[i] = c }
        let out = PerfLog.measure("按键引擎") { engine.handle(ev, at: ev.commitAt) }
        PerfLog.measure("按键事件") { apply(out) }
        PerfLog.measure("同步界面") { sync() }
    }

    var expectedLetters: Set<Character> { engine.expectedLetters }

    /// 回顾提前收掉：放大淡出，露出下一张牌。
    private func dismissReview(slot: Int) {
        guard let r = reviews.firstIndex(where: { $0.slot == slot && !$0.leaving }) else { return }
        let id = reviews[r].id
        reviews[r].leaving = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            self.reviews.removeAll { $0.id == id }
        }
    }

    /// 读当前牌的词，再读正在打的那个字。只是帮忙想起读音：不扣血、不断连招、不影响金色。
    private func sayCurrentWord() {
        let i: Int
        if case .card(let t) = engine.target { i = t } else if let f = engine.cards.firstIndex(where: { !$0.inactive }) { i = f } else { return }
        let card = engine.cards[i]
        var left = card.typed.count, idx = 0
        for (k, s) in card.word.syllables.enumerated() {
            idx = k
            if left < s.count { break }
            left -= s.count
        }
        let chars = Array(card.word.text)
        speaker.say(word: card.word.text, character: String(chars[min(idx, chars.count - 1)]))
    }

    /// 字母键的中心点（键盘自己的坐标），给抓字母的手臂用。
    func keyCenter(_ c: Character) -> CGPoint? { keyboard?.keyCenter(c) }

    /// UI 测试用：第几张牌的完整拼音。
    func letters(ofCard i: Int) -> String { engine.cards.indices.contains(i) ? engine.cards[i].word.letters : "" }

    private func tick(_ l: CADisplayLink) {
        latency.frame(target: l.targetTimestamp, timestamp: l.timestamp)
        PerfLog.frame(at: l.timestamp, expected: l.targetTimestamp - l.timestamp, inReview: !reviews.isEmpty)
        let ev = PerfLog.measure("引擎推进") { engine.advance(to: CACurrentMediaTime()) }
        if !ev.isEmpty { PerfLog.measure("事件处理") { apply(ev) } }
        PerfLog.measure("同步界面") { sync() }
    }

    // MARK: - 取字（剑气 / 绳镖）

    private var isQi: Bool { tuning.grabStyle == 0 }
    private static func bend() -> Double { Double.random(in: 0.35...1) * (Bool.random() ? 1 : -1) }

    /// 每个字母取一次。绳镖：后手甩出去钩回来；剑气：字母自己化成剑气打进主角身上，人不用动。
    private func grabLetter(_ letter: Character, k: CGFloat) {
        grabSeq += 1
        let g = Grab(id: grabSeq, letter: letter, start: Date().timeIntervalSinceReferenceDate, bend: Self.bend())
        grabs.append(g)
        let qi = isQi
        if !qi { scene.throwDart(wind: Self.rope.wind, out: Self.rope.out, hold: Self.rope.hold, back: Self.rope.back) }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(qi ? Self.qiCharge + Self.qiFly : Self.grabFlight))
            self.grabs.removeAll { $0.id == g.id }
            if qi { self.scene.bodyAbsorb(big: false) } else { self.scene.handFlash() }
            if k < 1 { self.scene.setCharge(k) }
        }
    }

    /// 一个音节取一次。绳镖：第一个字母甩出去钉住，后面的串上，音节打完一把拽回。
    /// 剑气：字母一个个被震出来悬在键上，音节打完聚成一团、整团打进主角身上。
    private func hookLetter(_ letter: Character, slot: Int, first: Bool, done: Bool, k: CGFloat) {
        let now = Date().timeIntervalSinceReferenceDate
        var cur = chains.lastIndex { $0.slot == slot && $0.yankAt == nil }
        if first || cur == nil {
            for o in chains.indices where chains[o].yankAt == nil { yankChain(o, k: nil) }     // 上一串还没收：先收
            grabSeq += 1
            let from = now + Self.ropeWind
            let h = Hook(letter: letter, pressed: now, from: from, at: from + Self.ropeOut, bend: Self.bend())
            chains.append(Chain(id: grabSeq, slot: slot, hooks: [h], yankAt: nil))
            cur = chains.count - 1
            if !isQi { scene.throwDart(wind: Self.rope.wind, out: Self.rope.out, hold: 0) }
        } else if let j = cur {
            let from = max(now, chains[j].hooks.last!.at)
            chains[j].hooks.append(Hook(letter: letter, pressed: now, from: from, at: from + Self.ropeHop, bend: Self.bend()))
        }
        guard let j = cur else { return }
        if done { yankChain(j, k: k); return }
        // 停手太久（换了牌、卡住）：自己收回，别一直挂着
        let id = chains[j].id, count = chains[j].hooks.count
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            if let j = self.chains.firstIndex(where: { $0.id == id }), self.chains[j].yankAt == nil, self.chains[j].hooks.count == count {
                self.yankChain(j, k: nil)
            }
        }
    }

    private func yankChain(_ j: Int, k: CGFloat?) {
        let now = Date().timeIntervalSinceReferenceDate
        let at = max(now, chains[j].hooks.last!.at) + Self.ropeHold
        chains[j].yankAt = at
        let id = chains[j].id, qi = isQi
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(at - now))
            if !qi { self.scene.yankDart(back: Self.rope.reel) }
            try? await Task.sleep(for: .seconds(qi ? Self.qiMerge + Self.qiFly : Self.chainBack))
            self.chains.removeAll { $0.id == id }
            if qi { self.scene.bodyAbsorb(big: true) } else { self.scene.handFlash(big: true) }
            if let k, k < 1 { self.scene.setCharge(k) }
        }
    }

    // MARK: - 事件 → 演出

    private func apply(_ events: [DuelEvent]) {
        // 群战：出招时补上来的、被打倒的敌人等最后一刀落下再演（在 .strike 里处理），别的时候马上演
        let inStrike = events.contains { if case .strike = $0 { return true } else { return false } }
        let lifeLost = events.contains { if case .lifeLost = $0 { return true } else { return false } }
        for e in events {
            switch e {
            case .foeJoined(let id, let tier, let slot):
                if !inStrike { scene.groupAdd(id: id, tier: tier.rawValue, slot: slot, walkIn: false) }
            case .foeDefeated(let id):
                if !inStrike { scene.groupDown(id) }
            case .foeAttacked(let id, _):
                scene.groupAttack(id)
                sounds.play(.hurt)
                sounds.hitHaptic(heavy: true)
            case .letterAccepted(let target, let letter):
                let typed: Int
                switch target {
                case .card(let i): typed = engine.cards.indices.contains(i) ? engine.cards[i].typed.count : 1
                case .incoming: typed = engine.opponent.incoming?.typed.count ?? 1
                case .none: typed = 1
                }
                sounds.tick(typed - 1 + heat)
                scene.letterTick()
                if case .card(let i) = target { dismissReview(slot: i) }      // 开始打下一个词：回顾让位
                if case .card(let i) = target, engine.cards.indices.contains(i) {
                    let word = engine.cards[i].word
                    let k = CGFloat(typed) / CGFloat(max(1, word.letterCount))
                    if tuning.grabMode == 1 {
                        // 音节边界（已打字母数）：打到边界后的第一个字母新出手一次，打到边界就拽回
                        let ends = word.syllables.reduce(into: [0]) { $0.append($0.last! + $1.count) }
                        hookLetter(letter, slot: i, first: ends.contains(typed - 1), done: ends.contains(typed), k: k)
                    } else {
                        grabLetter(letter, k: k)
                    }
                }
            case .nearMiss:
                nearMissToast += 1
                sounds.play(.nearmiss)
            case .moveDone(_, let gold):
                moveMarks = engine.moveMarks
                if gold, let r = reviews.indices.last { reviews[r].gold = true }
                if gold { sounds.hitHaptic(heavy: false) }
            case .finale:
                finaleBanner = true
                sounds.play(.levelup)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.4))
                    self.finaleBanner = false
                }
            case .hint(let ch):
                keyboard?.showHint(ch)
            case .hintCleared:
                keyboard?.showHint(nil)
            case .comboChanged, .comboBroken:
                updateHeat()
            case .strike(let i, let dmg, let flaw, let finisher, let heavy):
                if finisher { finisherMoves.insert(engine.moveMarks.count - 1) }
                scene.setCharge(1)
                let letters = (lastStruck[i] ?? "").map(String.init)
                let n = max(1, letters.count)
                reviewSeq += 1
                let rid = reviewSeq
                if var vm = lastCards[i] {
                    // 先定格：牌上还差最后一个字母，下一帧补上，最后一个字照样变红弹一下
                    let before = vm
                    vm.typed = vm.syllables.joined()
                    reviews.removeAll { $0.slot == i }          // 同一个位置又打完一张，旧的回顾让位
                    reviews.append(Review(id: rid, slot: i, card: vm, intro: before))
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.02))
                        if let r = self.reviews.firstIndex(where: { $0.id == rid }) {
                            self.reviews[r].intro = vm
                            self.sounds.hitHaptic(heavy: false)
                        }
                    }
                }
                strikesInFlight += 1
                let lethal = engine.opponent.hp <= 0            // 这一招打空了对手血条：最后一刀照必杀的冲击来
                // 群战：这一招打的是谁、打倒了谁、补上来谁（最后一刀落下时再演倒下和补位）
                let group = scene.groupMode
                let struckFoe = engine.lastStruck.first
                let downed = engine.lastDowned
                let joined = engine.foes.filter { engine.lastJoined.contains($0.id) }
                let livesLeft = engine.opponent.lives
                if lifeLost { knockdownHold = true }            // 血条先停在空的
                let big = lethal || lifeLost                    // 打空一条血：照绝杀的冲击来，但不出「绝杀！」
                // 定格之后牌翻成回顾牌，主角才出刀：每刀爆一个字母
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(Self.finishBeat))
                    let base = Date().timeIntervalSinceReferenceDate
                    if group, let id = struckFoe { self.scene.groupFocus(id) }
                    let times = self.scene.heroStrike(labels: letters, damage: dmg, heavy: heavy, flaw: flaw, finisher: finisher,
                                                      lethal: big, combo: self.engine.player.combo, minGap: self.tuning.slashMinGap) { [weak self] k in
                        guard let self else { return }
                        let last = k == n - 1
                        if last && (finisher || big) {
                            self.sounds.play(.finisher)
                            self.sounds.finisherHaptic()
                        } else if last {
                            self.sounds.play(.hitHeavy)                 // 最后一刀重重落下
                            self.sounds.hitHaptic(heavy: true)
                        } else {
                            self.sounds.play(.hitLight)
                            self.sounds.tick(k + self.heat)             // 再把打字时那串一个比一个高的音回放一遍
                            self.sounds.hitHaptic(heavy: false)
                        }
                        if last && lethal {
                            self.killBanner = true
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(1.0))
                                self.killBanner = false
                            }
                        }
                        if last && group {
                            for id in downed { self.scene.groupDown(id) }
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(0.4))
                                for f in joined { self.scene.groupAdd(id: f.id, tier: f.tier.rawValue, slot: f.slot, walkIn: true) }
                            }
                        }
                        if last && lifeLost {                           // 丢一条命：熄一块、跪地，站起来说句话、血条换色满上
                            self.foeLives = livesLeft
                            self.scene.foeKneel()
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(0.9))
                                self.scene.foeStandUp(line: Self.standUpLines.randomElement()!)
                                try? await Task.sleep(for: .seconds(0.25))
                                self.knockdownHold = false
                            }
                        }
                        if last { self.strikeLanded() }
                    }
                    // 字母按刀的时间表爆开，不等出刀回调（回调会被 SpriteKit 的帧挤在一起，爆得忽快忽慢）
                    if let r = self.reviews.firstIndex(where: { $0.id == rid }) { self.reviews[r].popAt = times.map { base + $0 } }
                    // 翻牌放在第一刀快落下时（必杀要先蓄力半秒，翻早了牌会空等）
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(max(0, (times.first ?? 0) - 0.2)))
                        if let r = self.reviews.firstIndex(where: { $0.id == rid }) { self.reviews[r].phase = 1 }
                    }
                    // 回顾：最后一刀后再停留一会儿，让人看清刚打的字和拼音，然后收掉
                    try? await Task.sleep(for: .seconds((times.last ?? 0) + Self.reviewHold))
                    if let r = self.reviews.firstIndex(where: { $0.id == rid }) { self.reviews[r].leaving = true }
                    try? await Task.sleep(for: .seconds(0.2))
                    self.reviews.removeAll { $0.id == rid }
                }
            case .parried:
                scene.parry()
                sounds.play(.parry)
                sounds.hitHaptic(heavy: true)
            case .blocked:
                scene.block()
                sounds.play(.block)
            case .hitByIncoming:
                scene.playerHurt()
                sounds.play(.hurt)
                sounds.hitHaptic(heavy: true)
            case .chargeInterrupted:
                scene.block()
            case .newMove(let s):
                newMoveToast = s
                sounds.play(.newmove)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.6))
                    if self.newMoveToast == s { self.newMoveToast = nil }
                }
            case .mistake(_, let dmg):
                mistakeFlash += 1
                sounds.play(.mistake)
                if dmg > 0 { scene.mistake() }
            case .won:
                // 等最后一刀落下再倒地、出结算
                if strikesInFlight > 0 && !AppResources.isUITest { pendingWin = true } else { win() }
            case .lost:
                scene.playerDown()
                finish()
            case .cardDealt(let i):
                // 新牌没被回顾盖住（比如这招没生成回顾牌）：马上算露出来，别让它一直等着不计时
                if !coveredSlots.contains(i) { revealed(i) }
            default:
                break
            }
        }
    }

    /// 丢了一条命站起来时说的话。
    private static let standUpLines = ["还没完！", "有两下子！", "再来！", "好身手！"]

    private func strikeLanded() {
        strikesInFlight = max(0, strikesInFlight - 1)
        guard pendingWin, strikesInFlight == 0 else { return }
        pendingWin = false
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))       // 看完必杀的白闪、击飞和收刀再倒地、出结算
            self.win()
        }
    }

    private func win() {
        scene.foeDown()
        sounds.play(.win)
        finish()
    }

    private func updateHeat() {
        let c = engine.player.combo
        let h = c >= tuning.comboRedAt ? 3 : c >= tuning.comboGoldAt ? 2 : c >= 3 ? 1 : 0
        guard h != heat else { return }
        if h > heat { sounds.play(.levelup) }
        heat = h
        scene.setHeat(h)
        music.setLevel(h)
    }

    private func finish() {
        if let s = engine.summary, s.won {
            if let last = lastDuelSeconds, s.durationSeconds < last - 0.5 {
                fasterBy = last - s.durationSeconds
                sounds.play(.record)
            }
            UserDefaults.standard.set(s.durationSeconds, forKey: "lastDuelSeconds")
        }
        heat = 0
        scene.setHeat(0)
        music.setLevel(0)
        summary = engine.summary
        link?.invalidate()
        link = nil
    }

    /// 把引擎状态同步给界面（只在变化时赋值，避免无谓的重绘）。
    private func sync() {
        let t = tuning
        if scene.groupMode {
            let now = engine.gameClock
            scene.groupPressure(Dictionary(uniqueKeysWithValues: engine.foes.map { ($0.id, $0.pressureProgress(at: now)) }),
                                hp: Dictionary(uniqueKeysWithValues: engine.foes.map { ($0.id, Double(max(0, $0.hp)) / Double(max(1, $0.maxHP))) }))
        }
        let newCards: [CardVM] = engine.cards.enumerated().map { i, c in
            CardVM(id: c.id, text: c.word.text, syllables: c.word.syllables, typed: c.typed, weight: c.weight(t).rawValue,
                   volumeLabel: Self.volumeName(c.word.volume) + " · " + Self.rankName(c.rank),
                   store: (engine.storeMultiplier(ofCard: i) * 10).rounded() / 10, flaw: c.hasFlaw,
                   finisher: c.isFinisher, locked: engine.target == .card(i), inactive: c.inactive)
        }
        if newCards != cards { cards = newCards }
        set(\.playerHP, engine.player.hp)
        set(\.playerMaxHP, t.playerMaxHP)
        set(\.qi, engine.player.qi)
        set(\.combo, engine.player.combo)
        set(\.foeHP, knockdownHold ? 0 : engine.opponent.hp)
        set(\.foeMaxHP, engine.opponent.maxHP)
        set(\.foeMaxLives, engine.opponent.maxLives)
        if !knockdownHold && strikesInFlight == 0 { set(\.foeLives, engine.opponent.lives) }   // 开场、重开：直接对上
        set(\.foeName, engine.opponent.name)
        set(\.foeTitle, engine.opponent.title)
        let st = engine.opponent.isStunned(at: engine.gameClock)
        if st != stunned { stunned = st; if !st { scene.stunEnded() } }
        let pr = (engine.opponent.pressureProgress(at: engine.gameClock) * 200).rounded() / 200
        set(\.pressure, pr)
        if let inc = engine.opponent.incoming {
            let vm = IncomingVM(text: inc.word.text, typed: inc.typed, locked: engine.target == .incoming)
            if vm != incoming { incoming = vm }
            incomingProgress = inc.progress(at: engine.gameClock)
        } else if incoming != nil {
            incoming = nil
            incomingProgress = 0
        }
        let h: String
        switch engine.target {
        case .card(let i): h = engine.cards[i].typed
        case .incoming: h = engine.opponent.incoming?.typed ?? ""
        case .none: h = ""
        }
        set(\.hint, h)
        let e = (engine.gameClock * 10).rounded(.down) / 10
        if e != elapsed { elapsed = e }
    }

    private func set<T: Equatable>(_ kp: ReferenceWritableKeyPath<DuelController, T>, _ v: T) {
        if self[keyPath: kp] != v { self[keyPath: kp] = v }
    }

    static func volumeName(_ v: String) -> String {
        switch v {
        case "biyin-shang": "鼻音掌上卷"
        case "biyin-xia": "鼻音掌下卷"
        case "liangzi-shang": "两字诀上卷"
        case "liangzi-xia": "两字诀下卷"
        case "yw": "yw 身法"
        case "lv": "ü 步"
        case "shengzi": "省字诀"
        case "sanpin": "三拼剑谱"
        default: "基本功"
        }
    }

    static func rankName(_ r: Int) -> String { ["零重", "一重", "二重", "三重", "四重", "五重"][min(5, max(0, r))] }
}

/// CADisplayLink 需要 NSObject 目标。
@MainActor
final class DisplayLinkProxy: NSObject {
    let action: (CADisplayLink) -> Void
    init(_ action: @escaping (CADisplayLink) -> Void) { self.action = action }
    @objc func fire(_ l: CADisplayLink) { action(l) }
}
