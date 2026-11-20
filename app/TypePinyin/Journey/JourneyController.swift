import DuelCore
import Foundation
import LearningCore
import Observation
import ProgressStore
import UIKit

/// 旅程：一打开去哪、画面之间怎么走、什么时候存档。规则交给 LearningCore，存档交给 ProgressStore。
@Observable
@MainActor
final class JourneyController {
    enum Screen: Equatable {
        case opening(battle: Int)
        case region(String)
        case map
        case codex
        case harvest
        /// 梦醒：一句话，然后到江湖地图。
        case wake
        /// 新开场：一句开场白，然后到江湖地图（进葫芦集先打葫芦集碑）。
        case gate
        /// 练功房：只出打过的词，一场一场随机（单挑、群战、掌门）。
        case practice
        /// 武林大会（山顶，最后一关）。
        case gathering
    }

    var screen: Screen = .map
    /// 每开一场新比武加一（比武画面按它重建、重新开打）。
    var duelToken = 0
    /// 这次打开已经演过开场白。
    var openingLineShown = false
    @ObservationIgnored var tipQueue: [String] = []

    // 地区
    enum RegionStage: Equatable { case scroll, duel, encounter, stele }
    /// 调参面板「看一块碑」：打完回江湖，不进长卷。
    var previewingStele = false
    /// 打碑文时就排好的这一趟路线（碑上写一路几场比武），打完碑进长卷就用它。
    @ObservationIgnored var steleRoute: Route?
    // 武林大会
    enum GatheringStage: Equatable { case hall, stele, duel(Int), crowned, finale }
    var gatheringStage: GatheringStage = .hall
    /// 地图上弹请帖（走完最后一座岛、还没看过时）。
    var showInvitation = false
    /// 这次打赢妙笔书生那一场的速度（收尾写「打字速度从 N 到 M」）。
    @ObservationIgnored var lastGatheringCPM: Double?
    var regionStage: RegionStage = .scroll
    var route: Route?
    var stationIndex = 0
    /// 第一次进这片地区：先演镜头从掌门摇到山脚。
    var introPending = false
    /// 新的一趟刚排好：进地区时主角从山脚（第 -1 站）走到第一站。
    private var walkIn = false
    /// 走完这片地区（打赢掌门）或通关后随机一场打完：回到长卷上显示的小结卡片。
    var pendingCard: PendingCard?
    /// 上一站的结果：走到下一站（输了就是原地）问「挑战还是返回」时，卡片上方带一句。
    var lastResult: PendingCard?
    /// 接着走：小人从这一站走到下一站。
    var walkFrom: Int?
    /// 调试跳站的次数：长卷画面看到它变了，就把小人和镜头摆到新的一站。
    var debugJumpTick = 0
    /// 刚拿到的秘籍（演出用）。
    var obtained: String?
    /// obtained 这一次是掌门盖印（打赢掌门），不是刚拿到秘籍。
    var obtainedIsSeal = false
    /// 这一场每本秘籍得的经验（打一张牌记一次，结算时存）。
    @ObservationIgnored var duelXP: [String: Int] = [:]
    /// 上一场结算：哪几本秘籍涨了经验（结算页画进度条用）。
    var lastBookGains: [BookGain] = []
    struct BookGain: Equatable, Identifiable {
        var volume: String
        var before: Int
        var after: Int
        var id: String { volume }
        var gain: Int { after - before }
        var leveledUp: Bool { BookXP.level(after) > BookXP.level(before) }
    }
    /// 这一场新收的词卡（按收到的先后；收集词卡勋章记「第 N 张是哪个词」用）。
    @ObservationIgnored var duelNewOrder: [String] = []
    /// 旧存档补发的勋章：回到地图时出一张卡片（只一次）。
    var backfillCard: [BadgeRecord]?
    /// 每天第一次回到地图展开的小卷轴（本周七格、勋章、下一枚）。
    var showDailyScroll = false
    /// 这一次卷轴要演的（展开时定下来）。
    var scrollShow: ScrollShow?
    /// 卷轴收起、飞进「收获」按钮时加一：按钮弹一下、扩一圈波纹。
    var harvestPing = 0
    /// 地图「收获」按钮在屏幕上的位置（卷轴收起后飞过去）。
    @ObservationIgnored var harvestButtonFrame: CGRect?
    /// 进收获页时直接打开哪一页（「calendar」「badges」），补发卡片的「去看看」用。
    @ObservationIgnored var openHarvestPage: String?
    /// 刚升重（演出用）。
    var rankUp: RankUp?
    struct RankUp: Equatable { var volume: String; var rank: Int }

    struct PendingCard {
        var summary: DuelSummary?
        var title: String
        var gains: [String]
        var won: Bool
        var finished: Bool          // 走完了这片地区（打赢掌门）
    }

    // 这次打开的收获（「收功」用）
    @ObservationIgnored var sessionStartChars = 0
    var sessionLearned: Set<String> = []
    var sessionRankUps: [String] = []
    private(set) var progress = Progress()
    var learner: Learner
    /// 存档读不出、从头开始了：提示一次。
    var showRecoveredNotice = false
    /// 调参面板（地图、长卷、秘籍页的标题连点三下）。
    var showPanel = false
    /// 这一场打完的牌（练功房记打过的词），打完一场一起存。
    @ObservationIgnored var practicePending: [String: PracticeWord] = [:]
    /// 这一场每张词卡打得干不干净（一场里打这个词每次都没错、没看提示才算这一场打对）。
    @ObservationIgnored var duelClean: [String: Bool] = [:]
    /// 这一场词卡的收获（新收了几张、练到熟练 / 精通的），结算卡片用。
    @ObservationIgnored var lastCardGains: [String] = []
    // 练功房
    enum PracticeStage: Equatable { case card, duel, text(String) }
    /// 练习场上次停在哪个选项：0 词语，1 文章。
    var practiceTab = 0
    var practiceStage: PracticeStage = .card
    var practiceStation: Station?
    /// 这一场练功房的对手来自哪片地区（背景用）。
    var practiceRegion = "huluji"

    let content: LearningContent
    let duel: DuelController
    @ObservationIgnored private var store: ProgressStore?

    init(duel: DuelController) {
        self.duel = duel
        self.content = AppResources.content
        self.learner = Learner(tuning: duel.tuning.learning)
        do {
            let s = try ProgressStore()
            store = s
            showRecoveredNotice = s.recovered
            progress = s.load()
        } catch {
            store = nil                                // 存储打不开：照常能玩，只是不存
        }
        if ProcessInfo.processInfo.arguments.contains("-resetJourney") {      // UI 测试：从第一次打开开始
            try? store?.resetAll()
            progress = store?.load() ?? Progress()
            DayClock.resetOffset()
            ScrollReveal.resetAll()
        }
        let args = ProcessInfo.processInfo.arguments
        if let k = args.firstIndex(of: "-obtain"), k + 1 < args.count {      // 开发用：-obtain all / -obtain liangzi-shang,lv
            let list = args[k + 1] == "all" ? RankFx.order : args[k + 1].split(separator: ",").map(String.init)
            debugObtain(list)
        }
        learner.records = progress.records
        BookXP.thresholds = duel.tuning.learning.bookXPThresholds
        migrateBooks()
        if args.contains("-sampleCalendar") { seedSampleCalendar() }   // 开发用：写进样例数据看日历、勋章
        backfillBadges()                                        // 旧存档：按已有的词卡、掌门印、秘籍等级补发勋章（只一次）
        startScrollReveal()                                     // 第一次用地图卷轴：已有的印和勋章算演过
        if let k = args.firstIndex(of: "-scrollPendingDays"), k + 1 < args.count, let n = Int(args[k + 1]) {   // 开发用：最近 n 天的印和勋章算没演过
            ScrollReveal.clearFirst()
            ScrollReveal.days = ScrollReveal.days.filter { $0 <= today - n }
            ScrollReveal.badges = Set(progress.badges.values.filter { $0.day <= today - n }.map(\.key))
        }
        duel.cardLabel = { [weak self] w in                     // 词牌下面写这张牌归哪本秘籍、几级
            guard let self, self.xpLevels else { return nil }
            let v = self.content.owner(of: JourneyCardSource.content(w).syllables)
            return self.bookName(v) + " · " + self.levelText(max(1, self.rank(of: v)))
        }
        sessionStartChars = typedCommonChars
        screen = startScreen()
        if case .region(let id) = screen { enterRegion(id) }
        if ProcessInfo.processInfo.arguments.contains("-codex") { screen = .codex }   // 开发用：直接打开秘籍页
        if ProcessInfo.processInfo.arguments.contains("-map") { screen = .map }       // 开发用：直接到江湖地图
        if ProcessInfo.processInfo.arguments.contains("-practice") { enterPractice() }   // 开发用：直接进练功房
        if let k = args.firstIndex(of: "-stele"), k + 1 < args.count { previewStele(args[k + 1]) }   // 开发用：直接看一块碑
        if let k = args.firstIndex(of: "-practiceText"), k + 1 < args.count {   // 开发用：直接打练习场的一篇
            enterPractice()
            startPracticeText(args[k + 1])
        }
        if let k = args.firstIndex(of: "-gathering") {                      // 开发用：直接上武林大会（-gathering crowned / finale 直接看那一屏）
            enterGathering()
            switch k + 1 < args.count ? args[k + 1] : "" {
            case "crowned": gatheringStage = .crowned
            case "finale": gatheringStage = .finale
            default: break
            }
        }
        duel.journey = self
        SceneRenderer.prewarm(regionIds: content.regions.map(\.id), width: UIScreen.main.bounds.width)   // 后台先把场景图画好
    }

    /// 一打开去哪：没打完初入江湖就接着打，没拿到《基本功》就去葫芦集，否则回江湖。
    func startScreen() -> Screen {
        if !progress.journey.openingDone {
            if duel.tuning.openingStyle == 1 && content.dream?.prologue != nil { return .gate }
            return .opening(battle: progress.journey.openingBattle)
        }
        if !cleared("huluji") && !needsMapGuide { return .region("huluji") }
        return .map
    }

    static let mapGuideKey = "mapGuide"
    /// 梦醒后第一次到江湖地图：引导点葫芦集（只出现一次，点进去就算看过）。
    /// 水墨转场（见 InkCurtain）：0 没有，1 墨从上往下盖满，2 换好画面、墨往下退。
    var inkPhase = 0
    /// 这一段（盖或退）开始的时刻；转场画面按它算进度，不靠视图自己记（换画面时视图可能重建）。
    var inkSince = Date()

    /// 墨盖满时换画面，再退掉。UI 测试和「减少动态效果」时直接换。
    func inkTransition(_ change: @escaping @MainActor () -> Void) {
        guard !AppResources.isUITest, !UIAccessibility.isReduceMotionEnabled, inkPhase == 0 else { change(); return }
        inkPhase = 1
        inkSince = Date()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(InkCurtain.cover + 0.05))
            change()
            try? await Task.sleep(for: .seconds(0.15))        // 新画面第一次画要一会儿：在墨底下先画好再退，不然退的动画被卡掉
            self.inkSince = Date()
            self.inkPhase = 2
            try? await Task.sleep(for: .seconds(InkCurtain.reveal + 0.05))
            self.inkPhase = 0
        }
    }

    var needsMapGuide: Bool { !progress.journey.tipsSeen.contains(Self.mapGuideKey) }

    func markMapGuideSeen() {
        guard needsMapGuide else { return }
        var j = progress.journey
        j.tipsSeen.insert(Self.mapGuideKey)
        var ch = ProgressChange()
        ch.journey = j
        save(ch)
    }

    var today: DayIndex { DayClock.today() }

    // MARK: 存档

    func save(_ change: ProgressChange) {
        try? store?.save(change)
        if let j = change.journey { progress.journey = j }
        for (k, v) in change.volumes { progress.volumes[k] = v }
        for (k, v) in change.regions { progress.regions[k] = v }
        for r in change.records { progress.records[r.spelling] = r }
        if let s = change.speed { progress.speed = s }
        for w in change.practice { progress.practice[w.text] = w }
        for d in change.days {
            var logs = progress.days[d.day] ?? []
            logs.removeAll { $0.deviceId == d.deviceId }
            logs.append(d)
            progress.days[d.day] = logs
        }
        for b in change.badges where (progress.badges[b.key]?.day ?? .max) > b.day { progress.badges[b.key] = b }
    }

    /// 这台设备的编号（日历按设备分开记）。
    var deviceId: String { store?.deviceId ?? "local" }

    /// 调参「清空勋章」：删掉这台设备的勋章、看过的记号和补发记号，下次结算（或「重新补发」）再按现有的进度发。
    func resetBadges() {
        try? store?.resetBadges()
        progress = store?.load() ?? progress
        var j = progress.journey
        j.tipsSeen = j.tipsSeen.filter { !$0.hasPrefix("badge:") && $0 != Self.backfillKey }
        ScrollReveal.badges = []
        var ch = ProgressChange()
        ch.journey = j
        save(ch)
    }

    /// 调参「清空进度」：清掉本设备的全部记录，回到第一次打开。
    func resetProgress() {
        duel.music.stop()
        try? store?.resetAll()                                 // 连日历（每天的记录）和勋章一起删
        progress = store?.load() ?? Progress()
        learner = Learner(tuning: duel.tuning.learning)
        DayClock.resetOffset()
        ScrollReveal.resetAll()                                // 卷轴演过什么也清掉，重新拿到的照样落下来
        backfillCard = nil
        showDailyScroll = false
        scrollShow = nil
        route = nil
        openingLineShown = false
        screen = startScreen()
    }
}

/// 旅程的开关（不进调参配置）：跳过动画（UI 测试也用，启动参数 -fastJourney）。
enum JourneyFlags {
    static var fast: Bool {
        get { ProcessInfo.processInfo.arguments.contains("-fastJourney") || UserDefaults.standard.bool(forKey: "journey.fast") }
        set { UserDefaults.standard.set(newValue, forKey: "journey.fast") }
    }
}

// MARK: - 比武（初入江湖、地区里的站都走这里）

extension JourneyController {
    /// 已学会的音节（拼错要罚的）：熟练及以上。没碰过的第一次错算新招。
    var learnedSet: Set<String> { Set(learner.records.values.filter { $0.proficiency >= .fluent }.map(\.spelling)) }

    func rank(of volume: String) -> Int { progress.volumes[volume]?.rank ?? 0 }

    /// 收过的词卡（梦里、地区里打完过的词；没有音节的旧条目不算）。
    var cards: [PracticeWord] { progress.practice.values.filter { !$0.syllables.isEmpty } }

    /// 每个音节最好的词卡等级（重数、秘籍页格子的颜色按它）。
    var cardBest: [String: CardLevel] { CardRank.best(cards, tuning: learner.tuning) }

    /// 离下一重有多远（0…1）。
    func cardProgress(of volume: String) -> Double {
        CardRank.progress(of: volume, rank: rank(of: volume), best: cardBest, content: content)
    }

    /// 新课程：一个词只归一关（调参「课程」，重开 App 生效）。
    var oneLevelPerWord: Bool { !Volumes.legacyCurriculum }

    /// 这一关的词一共几个（点开地区卡片上写「已集 N / 总数」）：新课程按一个词只归一关数；原来的含这一卷音节的都算。
    func cardTotal(in volume: String) -> Int {
        if oneLevelPerWord { return content.ownedCount[volume] ?? 0 }
        return content.words.filter { $0.syllables.contains { content.volume(of: $0) == volume } }.count
    }

    /// 这一关收了几张词卡：新课程只算归这一关的；原来的含这一卷音节的都算（一张词卡可以算几卷）。
    func cardCount(in volume: String) -> Int {
        if oneLevelPerWord { return cards.filter { content.owner(of: $0.syllables) == volume }.count }
        return cards.filter { $0.syllables.contains { content.volume(of: $0) == volume } }.count
    }

    var newTodaySoFar: Int { progress.journey.newTodayDay == today ? progress.journey.newToday : 0 }

    /// 排一场比武：出字器、单场设置、对手；打完回调 done（交回小结和学习变化）。
    func planDuel(volume: String?, foe: Fighter, minHP: Int = 0, targetSeconds: Double? = nil, lives: Int? = nil,
                  boss: Bool = false, backdrop: (region: String, station: Int, count: Int)? = nil,
                  lengths: [Int: Double] = [2: 1], group: Bool = false, groupTotal: Int? = nil, groupHP: [Double]? = nil, allowed: Set<String>? = nil, focus: Set<String>? = nil,
                  pool: [ContentWord]? = nil, weights: [String: Double]? = nil, guided: Bool = false, firstWord: ContentWord? = nil,
                  groupNames: [String]? = nil, groupLines: [String]? = nil,
                  makeSource: ((@escaping (Word, Bool, Double) -> Void) -> CardSource)? = nil,
                  done: @escaping (DuelSummary, LearnerChange) -> Void) {
        let dealer = Dealer(content: content, learner: learner,
                            context: DealContext(volume: volume, today: today, newToday: newTodaySoFar, lengths: lengths,
                                                 allowedSyllables: allowed, focus: focus, pool: pool, firstWord: firstWord, weights: weights,
                                                 collected: Set(cards.map(\.text))),
                            seed: UInt64(Date().timeIntervalSince1970 * 1000) & 0xFFFF_FFFF)
        practicePending = [:]
        duelClean = [:]
        duelXP = [:]
        duelNewOrder = []
        let onCard: (Word, Bool, Double) -> Void = { [weak self] word, clean, spl in
            guard let self, !word.syllables.isEmpty else { return }
            // 秘籍经验：这张牌归哪一关，就给哪本秘籍；打干净、打得快多给，第一次收到这张词卡再多给
            let isNew = self.practicePending[word.text] == nil && (self.progress.practice[word.text]?.syllables.isEmpty ?? true)
            if isNew { self.duelNewOrder.append(word.text) }
            let perfect = spl <= self.duel.tuning.goldSecondsPerLetter
            self.duelXP[self.content.owner(of: word.syllables), default: 0] += BookXP.gain(clean: clean, perfect: perfect, new: isNew)
            self.duelClean[word.text] = (self.duelClean[word.text] ?? true) && clean
            var w = self.practicePending[word.text] ?? self.progress.practice[word.text]
                ?? PracticeWord(text: word.text, syllables: word.syllables, volume: word.volume)
            w.note(clean: clean, secondsPerLetter: spl, at: Date().timeIntervalSinceReferenceDate)
            self.practicePending[word.text] = w
        }
        let source = makeSource?(onCard) ?? JourneyCardSource(dealer: dealer, rankOf: { [weak self] v in self?.rank(of: v) ?? 0 }, onCard: onCard)
        // 爆字母按每个音节那一卷的重数（没拿到 = 零重 = 彩纸）；在这一卷的地区里，这一卷的音节至少按一重爆（没拿到也先看到这里的粒子）
        var ranks = progress.volumes.filter { $0.value.obtained }.mapValues(\.rank)
        if let volume { ranks[volume] = max(1, ranks[volume] ?? 0) }
        duel.volumeRanks = ranks
        var setup = DuelSetup()
        setup.learned = learnedSet
        setup.secondsPerLetter = progress.speed?.secondsPerLetter
        setup.targetSeconds = targetSeconds
        setup.minHP = minHP
        setup.hpFactor = foe.hpFactor ?? 1
        setup.lives = lives ?? 1
        setup.bossPressure = boss
        setup.groupFight = group
        setup.groupTotal = groupTotal
        setup.groupHP = groupHP
        setup.firstCardFree = guided
        setup.day = today
        duel.plan = DuelController.DuelPlan(
            bank: AppResources.journeyBank, setup: setup, source: source,
            foeName: foe.name, foeTitle: foe.title, robe: UIColor(hexString: foe.look.robe), guided: guided, lifeLines: foe.lifeLines ?? [],
            groupNames: groupNames, groupLines: groupLines,
            backdrop: backdrop,
            backdropBoss: boss,
            onEvent: { [weak self] e in self?.handleTipEvent(e) },
            onFinish: { [weak self] summary, attempts, spl in
                guard let self else { return }
                let before = self.settleBefore()
                let note = self.fightNote(place: self.settlePlace, foe: foe, won: summary.won,
                                          group: group ? (groupTotal ?? self.duel.tuning.groupTotal) : nil)
                let change = self.learner.record(attempts)
                self.sessionLearned.formUnion(change.newlyMet.filter { self.content.volume(of: $0) != "base" })
                var j = self.progress.journey
                j.newToday = dealer.context.newToday
                j.newTodayDay = self.today
                for w in self.practicePending.values { j.typedChars.formUnion(w.text.map(String.init)) }   // 打出过的字
                var ch = ProgressChange()
                ch.journey = j
                ch.records = Set(attempts.map(\.spelling)).compactMap { self.learner.records[$0] }
                ch.practice = self.settleCards()                            // 打过的词收成词卡（进练习场）
                for (k, v) in self.settleBooks() { ch.volumes[k] = v }      // 秘籍经验
                if !JourneyFlags.fast { TypingSpeedNote.record(summary.charsPerMinute) }   // 收获页的打字速度
                self.practicePending = [:]
                // 手速跨场记住（按设备）：每场结束按权重滑动一次
                if !attempts.isEmpty, !JourneyFlags.fast {
                    let start = attempts.map(\.startSeconds).reduce(0, +) / Double(attempts.count)
                    let old = self.progress.speed.map { PlayerSpeed(secondsPerLetter: $0.secondsPerLetter, startSeconds: $0.startSeconds, samples: $0.samples) }
                    let s = PlayerSpeed.updated(old, secondsPerLetter: spl, startSeconds: start, weight: self.learner.tuning.speedWeight)
                    ch.speed = SpeedState(secondsPerLetter: s.secondsPerLetter, startSeconds: s.startSeconds, samples: s.samples)
                }
                self.save(ch)
                done(summary, change)
                // 日历、勋章：结算（连掌门盖印、当选盟主）都存好了再记；盖印、落勋章在回到地图的卷轴上演
                self.logSettle(before, SettleInfo(
                    text: false,
                    newCards: self.duelNewOrder, books: self.lastBookGains, cpm: summary.charsPerMinute,
                    region: backdrop?.region, note: note))
            })
    }

    /// 一场打完：这一场打对的词卡累计场数加一；记下新收的、练到熟练 / 精通的（结算卡片写）。
    func settleCards() -> [PracticeWord] {
        let t = learner.tuning
        var fresh: [String] = [], fluent: [String] = [], master: [String] = []
        var out: [PracticeWord] = []
        for var w in practicePending.values {
            let old = progress.practice[w.text]
            let before = old.map { $0.syllables.isEmpty ? nil : $0.level(t) } ?? nil
            if duelClean[w.text] == true { w.cleanDuels += 1 }
            let after = w.level(t)
            if before == nil { fresh.append(w.text) }
            if after == .master && (before ?? .met) < .master { master.append(w.text) }
            else if after == .fluent && (before ?? .met) < .fluent { fluent.append(w.text) }
            out.append(w)
        }
        func list(_ a: [String]) -> String { a.prefix(4).joined(separator: "、") + (a.count > 4 ? " 等" : "") }
        var g: [String] = []
        if !fresh.isEmpty { g.append("收了 \(fresh.count) 张新词卡") }
        if !xpLevels {                                     // 按经验升级时不再说熟练、精通（只剩练习场挑词用）
            if !fluent.isEmpty { g.append("\(fluent.count) 张词卡练到熟练：\(list(fluent))") }
            if !master.isEmpty { g.append("\(master.count) 张词卡练到精通：\(list(master))") }
        }
        lastCardGains = g
        duelClean = [:]
        return out
    }

    /// 打出过的常用字有几个：按真打出过的字数（打完的牌、奇遇的句子），不按音节推算。
    /// 练功房的词也并进来，这样记「打过的字」之前的旧进度也算得上。
    var typedCommonChars: Int {
        var typed = Set(progress.journey.typedChars.compactMap(\.first))
        for w in progress.practice.keys { typed.formUnion(w) }
        return content.commonCharCount(in: typed)
    }

    /// 小结卡片多出来的收获：能打出多少个常用字、这一场学会了几个音节、词卡的收获。
    func gains(_ change: LearnerChange) -> [String] {
        var g: [String] = []
        let n = typedCommonChars
        if n > 0 { g.append("你已经能打出 \(n.formatted()) 个常用字") }
        // 学会的音节：基本功大多数人本来就会，不算进来
        let learned = change.newlyMet.filter { content.volume(of: $0) != "base" }
        if !learned.isEmpty { g.append("这一场学会了 \(learned.count) 个音节") }
        duel.summaryBooks = summaryBooks()                    // 秘籍进度跟着收获一起给结算页
        if xpLevels { return (learned.isEmpty ? [] : [g.last!]) + lastCardGains }   // 累计常用字挪到收获页
        return g + lastCardGains
    }

    /// 结算页的秘籍进度：这一场涨了经验的每本一行。
    func summaryBooks() -> [DuelController.SummaryBook] {
        let pieces = [0, 9, 16, 24, 30, 36]
        return lastBookGains.map { g in
            let lv = BookXP.level(g.after)
            let theme = RankFx.theme(g.volume).name
            return DuelController.SummaryBook(
                id: g.volume, name: bookName(g.volume), level: lv,
                from: BookXP.progress(g.before), to: BookXP.progress(g.after),
                gain: g.gain, leveledUp: g.leveledUp,
                note: g.leveledUp ? "打中时，\(theme)从 \(pieces[lv - 1]) 片变成 \(pieces[lv]) 片\(lv == 4 ? "，还会往上冲" : "")" : "")
        }
    }

    // MARK: 入门提示

    func handleTipEvent(_ e: DuelEvent) {
        let tip: JourneyTip?
        switch e {
        case .started: tip = duel.plan?.guided == true ? nil : .firstCard
            if duel.plan?.guided == true { markTipSeen(.firstCard) }
        case .strike:                                         // 教学那张牌打完了才算学过
            tip = nil
            if duel.plan?.guided == true { markTipSeen(.guide) }
        case .pressureStarted: tip = .firstPressure
        case .newMove: tip = .firstNewMove
        default: tip = nil
        }
        guard let tip, !progress.journey.tipsSeen.contains(tip.rawValue) else { return }
        var j = progress.journey
        j.tipsSeen.insert(tip.rawValue)
        var ch = ProgressChange()
        ch.journey = j
        save(ch)
        tipQueue.append(tip.text)
        if duel.tip == nil { showNextTip() }
    }

    func markTipSeen(_ t: JourneyTip) {
        guard !progress.journey.tipsSeen.contains(t.rawValue) else { return }
        var j = progress.journey
        j.tipsSeen.insert(t.rawValue)
        var ch = ProgressChange()
        ch.journey = j
        save(ch)
    }

    /// 提示一条一条来，每条停 4 秒（第一张牌和第一次蓄力几乎同时到，不能互相盖掉）。
    func showNextTip() {
        guard !tipQueue.isEmpty else { duel.tip = nil; return }
        let text = tipQueue.removeFirst()
        duel.tip = text
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, self.duel.tip == text else { return }
            self.showNextTip()
        }
    }

    // MARK: 初入江湖

    /// 开场白看完：开场就算走完了，到江湖地图（第一次会引导点葫芦集）。
    func finishPrologue() {
        if !progress.journey.openingDone {
            var j = progress.journey
            j.openingDone = true
            var ch = ProgressChange()
            ch.journey = j
            save(ch)
        }
        inkTransition { [weak self] in self?.screen = .map }
    }

    /// 调参面板：再看一遍开场，不清进度（梦里比武那种会再记一次打到第几场，没有别的影响）。
    func previewOpening() {
        openingLineShown = false
        duelToken += 1
        screen = duel.tuning.openingStyle == 1 && content.dream?.prologue != nil ? .gate : .opening(battle: 0)
    }


    /// 初入江湖：一场梦。梦里和妙笔书生过招（两条命、打不输），牌是专门挑的好打的常用词。
    func startOpening(_ n: Int) {
        guard let dream = content.dream else { return }
        let t = duel.tuning.learning
        planDuel(volume: nil, foe: dream.boss, minHP: t.openingMinHP, targetSeconds: t.openingTargetSeconds, lives: 2,
                 backdrop: ("dream", 0, 1), lengths: [2: 0.75, 3: 0.25], pool: dream.words,
                 guided: !progress.journey.openingDone,                               // 梦没打完，每次开打都先教一遍
                 firstWord: progress.journey.openingDone ? nil : dream.tutorial) { [weak self] _, change in
            guard let self else { return }
            var j = self.progress.journey
            j.openingBattle = n + 1
            let last = n + 1 >= t.openingBattles
            if last { j.openingDone = true }
            var ch = ProgressChange()
            ch.journey = j
            self.save(ch)
            self.duel.summaryGains = self.gains(change)
            let go: @MainActor () -> Void = { [weak self] in
                guard let self else { return }
                guard last else { self.duelToken += 1; self.screen = .opening(battle: n + 1); return }
                self.inkTransition { [weak self] in self?.duelToken += 1; self?.screen = .wake }   // 醒来：墨盖下来再退开，像从梦里醒过来
            }
            self.duel.summaryActions = [.init(label: last ? "醒来" : "继续", primary: true, action: go)]
            self.autoAdvance { _ in go() }
        }
    }
}

// MARK: - 地区

extension JourneyController {
    var currentRegion: Region? {
        if case .region(let id) = screen { return content.region(id) }
        return nil
    }

    /// 进一片地区：这一趟没走完就接着走（第一次挑战和通关后再去一趟都一样记进度），否则从头排一条新路线。
    /// 通关后再去一趟是完整的一趟（2026-11-01 改，原来是随机一场），打赢掌门不再给秘籍。
    func enterRegion(_ id: String, skipStele: Bool = false) {
        guard let region = content.region(id) else { return }
        if progress.journey.lastRegion != id {                // 地图上最近一次挑战的岛（红边圆章、一圈光）
            var j = progress.journey
            j.lastRegion = id
            var ch = ProgressChange()
            ch.journey = j
            save(ch)
        }
        if !skipStele && needsStele(region) {              // 第一次进这座岛：门口先打碑文，打完再进长卷
            previewingStele = false
            steleRoute = planRoute(region)                 // 先排好路线，碑上写一路几场比武
            duelToken += 1
            regionStage = .stele
            screen = .region(id)
            markMapGuideSeen()
            return
        }
        let state = progress.regions[id]
        if let s = state, s.phase != .untouched, let data = s.route,
           let r = try? JSONDecoder().decode(Route.self, from: data), r.stations.count > 1, s.stationIndex < r.stations.count {
            route = r
            stationIndex = s.stationIndex
            introPending = false
        } else {
            let cleared = state?.phase == .cleared
            route = steleRoute.flatMap { $0.regionId == id ? $0 : nil } ?? planRoute(region)
            steleRoute = nil
            stationIndex = 0
            introPending = !cleared                            // 镜头从掌门摇到山脚、地名横幅：只在第一次
            saveRegion(id, phase: cleared ? .cleared : .inProgress)
            walkIn = true                                      // 新的一趟：主角从山脚走到第一站
        }
        pendingCard = nil
        lastResult = nil
        walkFrom = walkIn ? -1 : nil
        walkIn = false
        obtained = nil
        regionStage = .scroll
        screen = .region(id)
        markMapGuideSeen()
        if obtainAtStele, progress.volumes[region.volume]?.obtained != true { obtainVolume(region.volume) }   // 进岛（打完碑）就拿到这本秘籍
    }

    func planRoute(_ region: Region) -> Route {
        RoutePlanner.plan(region: region, content: content, seed: UInt64(Date().timeIntervalSince1970 * 1000) & 0xFFFF_FFFF,
                          shortFirstLevel: !oneLevelPerWord)
    }

    /// 调试（调参面板）：直接跳到这一趟长卷的第 i 站，站前照常问挑战。进度会存下来。
    func debugJump(to i: Int) {
        guard let id = currentRegion?.id, let r = route, r.stations.indices.contains(i) else { return }
        pendingCard = nil
        lastResult = nil
        walkFrom = nil
        introPending = false
        stationIndex = i
        saveRegion(id, phase: progress.regions[id]?.phase ?? .inProgress)
        debugJumpTick += 1
    }

    /// 存这一趟的进度；keepRoute = false 表示这一趟走完了，下次进来从头排新路线。
    func saveRegion(_ id: String, phase: RegionPhase, keepRoute: Bool = true) {
        var ch = ProgressChange()
        ch.regions[id] = RegionState(phase: phase, stationIndex: keepRoute ? stationIndex : 0,
                                     route: keepRoute ? route.flatMap { try? JSONEncoder().encode($0) } : nil)
        save(ch)
    }

    var currentStation: Station? {
        guard let r = route, stationIndex < r.stations.count else { return nil }
        return r.stations[stationIndex]
    }

    func encounter(_ id: String?) -> Encounter? { content.encounters.first { $0.id == id } }

    /// 过场说完：进这一站（比武或奇遇）。
    func enterStation() {
        guard let st = currentStation else { return }
        duelToken += 1
        regionStage = st.kind == .encounter ? .encounter : .duel
    }

    /// 群战一共几个人：按岛的顺序往上加，前面的岛人少（掌门前那场 5 5 6 6 7 7 8 8 9 9，路上那场少两个）。
    /// 调参关掉时返回 nil，按调参面板的「一共几个人」。
    func groupTotal(in region: Region) -> Int? {
        guard duel.tuning.groupByLevel else { return nil }
        let k = content.regions.filter(\.playable).firstIndex { $0.id == region.id } ?? 0
        let beforeBoss = [5, 5, 6, 6, 7, 7, 8, 8, 9, 9][min(k, 9)]
        let next = route?.stations.indices.contains(stationIndex + 1) == true ? route?.stations[stationIndex + 1].kind : nil
        return next == .boss ? beforeBoss : beforeBoss - 2
    }

    /// 比武画面出现时：排这一站的比武。
    func startStationDuel() {
        guard let region = currentRegion, let st = currentStation, let foe = st.foe else { return }
        let boss = st.kind == .boss
        // 由短到长：前两站二字为主，中间二到四字，掌门三到五字
        let t = learner.tuning
        let lengths = LearningTuning.lengthMap(boss ? t.bossLengths : stationIndex < 2 ? t.earlyLengths : t.middleLengths)
        // 新课程：一个词只归一关，只出这一关和前面几关的音节组成的词；葫芦集的主题牌只挑带 zh ch sh 这类三个字母的音节的词
        // 原来的课程：第一关的牌只许用那 30 个音节（不管奇遇里碰到过什么）
        let allowed: Set<String>?
        var focus: Set<String>?
        if oneLevelPerWord {
            allowed = content.syllables(upTo: region.volume)
            if region.volume == "base" { focus = Set(content.syllables(in: "base").map(\.spelling).filter { $0.count >= 3 }) }
        } else {
            allowed = region.volume == "base" ? Volumes.baseCore : nil
        }
        planDuel(volume: region.volume, foe: foe, lives: boss ? 3 : 1, boss: boss,
                 backdrop: (region.id, stationIndex, route?.stations.count ?? 1), lengths: lengths, group: st.kind == .group,
                 groupTotal: st.groupSize ?? groupTotal(in: region), groupHP: region.groupHP, allowed: allowed, focus: focus) { [weak self] summary, change in
            self?.stationDone(won: summary.won, summary: summary, change: change)
        }
    }

    /// 奇遇打完：每个字按这一句干不干净记学习；不会失败。
    func encounterDone(_ t: TextController) {
        recordText(t)
        autoAdvance { j in j.leaveEncounter() }
    }

    /// 打完一篇（奇遇或练习场的文章）：每个音节记一次，打出的字也算进常用字。
    func recordText(_ t: TextController) {
        let before = settleBefore()
        var attempts: [Attempt] = []
        let now = Date().timeIntervalSinceReferenceDate
        for (k, s) in t.sentences.enumerated() {
            let clean = k < t.sentenceClean.count ? t.sentenceClean[k] : true
            for sp in s.syllables where !sp.isEmpty {
                attempts.append(Attempt(spelling: sp, at: now, day: today, correct: clean, usedHint: false, startSeconds: 1.5))
            }
        }
        let change = learner.record(attempts)
        sessionLearned.formUnion(change.newlyMet.filter { content.volume(of: $0) != "base" })
        var ch = ProgressChange()
        ch.records = Set(attempts.map(\.spelling)).compactMap { learner.records[$0] }
        var jj = progress.journey
        for s in t.sentences { jj.typedChars.formUnion(s.chars.map(String.init)) }     // 奇遇里打出的字也算
        ch.journey = jj
        save(ch)
        // 日历、勋章：一篇文字算一场
        let id = t.given?.id ?? ""
        let title = t.given?.title ?? ""
        let regionId = currentRegion?.id ?? encounter(id)?.regions.first
        let place = settlePlace
        let note = id.hasPrefix("stele-") ? "打完\(title)" : place.isEmpty ? "打完《\(title)》" : "\(place)，打完《\(title)》"
        logSettle(before, SettleInfo(
            text: true,
            newCards: [], books: [], cpm: t.cpm, region: regionId, note: note))
    }

    /// 奇遇的「接着走」。
    func leaveEncounter() {
        guard let region = currentRegion else { return }
        stationIndex += 1
        saveRegion(region.id, phase: progress.regions[region.id]?.phase == .cleared ? .cleared : .inProgress)
        lastResult = PendingCard(summary: nil, title: "奇遇打完了", gains: [], won: true, finished: false)
        walkFrom = stationIndex - 1
        regionStage = .scroll
    }

    /// 一站比武打完：赢了往前走一站（掌门打赢就拿到这一卷），输了重打这一站。
    func stationDone(won: Bool, summary: DuelSummary, change: LearnerChange) {
        guard let region = currentRegion, let st = currentStation else { return }
        var finished = false
        if won {
            stationIndex += 1
            if st.kind == .boss {
                finished = true
                let firstClear = progress.regions[region.id]?.phase != .cleared
                stationIndex = 0
                saveRegion(region.id, phase: .cleared, keepRoute: false)   // 这一趟走完了，再去一趟从头开始
                if firstClear {
                    if obtainAtStele { obtainedIsSeal = true; obtained = region.volume }   // 秘籍进岛时就拿到了：掌门在上面盖印
                    else { obtainVolume(region.volume) }
                }
            } else {
                saveRegion(region.id, phase: progress.regions[region.id]?.phase == .cleared ? .cleared : .inProgress)
            }
        }
        // 进度先存好（结算卡片上退出也不丢），再出结算；点「继续」才回长卷
        let card = PendingCard(summary: summary, title: won ? "打赢了\(st.foe?.name ?? "")" : "差一点",
                               gains: gains(change), won: won, finished: finished)
        duel.summaryGains = gains(change)
        let go: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            self.checkRankUps()
            self.regionStage = .scroll
            if finished {                                      // 走完了：拿到秘籍的演出之后，一张小卡片回江湖（数字刚才结算里看过了）
                self.pendingCard = PendingCard(summary: nil, title: "走完了\(region.name)", gains: [], won: true, finished: true)
                self.autoAdvance(after: 5) { j in
                    j.obtained = nil
                    j.rankUp = nil
                    j.continueRoute()
                }
            } else if won {                                    // 赢了走到下一站再问，结果刚才看过了，站前不再重复
                self.lastResult = nil
                self.walkFrom = self.stationIndex - 1
            } else {                                           // 输了留在原地问，顶上写「差一点」
                self.lastResult = card
            }
        }
        duel.summaryActions = [.init(label: "继续", primary: true, action: go)]
        autoAdvance(after: 5) { _ in go() }                    // 演示：结算要先等倒地 1.3 秒，多停一会儿才看得到
    }

    /// 站前的「挑战」。
    func challenge() {
        lastResult = nil
        enterStation()
    }

    /// 站前的「返回」：回江湖，进度留着，下次从这一站接着来。
    func leaveRegion() {
        lastResult = nil
        pendingCard = nil
        screen = .map
    }

    /// 拿到一卷：存下来，按词卡直接升到对应的重数。
    func obtainVolume(_ v: String, show: Bool = true) {
        let xp = progress.volumes[v]?.xp ?? 0
        let r = xpLevels ? BookXP.level(xp) : CardRank.rank(of: v, obtained: true, previous: 0, best: cardBest, content: content)
        var ch = ProgressChange()
        ch.volumes[v] = VolumeState(obtained: true, rank: max(r, progress.volumes[v]?.rank ?? 0), xp: xp)
        save(ch)
        obtainedIsSeal = false
        if show { obtained = v }
    }

    /// 秘籍按经验升级（调参「秘籍怎么升级」；关掉是原来按词卡算重数、打赢掌门才拿到）。
    var xpLevels: Bool { learner.tuning.bookLevels == 1 }
    /// 进岛（打完碑）就拿到秘籍；原来是打赢掌门才拿到。
    var obtainAtStele: Bool { xpLevels }
    /// 这座岛打通了（打赢过掌门）。解锁下一座、山顶十方印、武林大会开放都看它，不看有没有秘籍。
    func cleared(_ regionId: String) -> Bool { progress.regions[regionId]?.phase == .cleared }

    /// 这一场的经验结到秘籍上：只涨不扣，够了就升级。返回要存的卷。
    func settleBooks() -> [String: VolumeState] {
        defer { duelXP = [:] }
        BookXP.thresholds = duel.tuning.learning.bookXPThresholds   // 调参面板改了门槛，下一场结算就按新的
        guard xpLevels else { lastBookGains = []; return [:] }
        var out: [String: VolumeState] = [:]
        var gains: [BookGain] = []
        for (v, g) in duelXP where g > 0 {
            let old = progress.volumes[v] ?? VolumeState(obtained: false, rank: 0)
            let xp = old.xp + g
            let rank = old.obtained ? max(old.rank, BookXP.level(xp)) : old.rank
            out[v] = VolumeState(obtained: old.obtained, rank: rank, xp: xp)
            if old.obtained {
                gains.append(BookGain(volume: v, before: old.xp, after: xp))
                if rank > old.rank { sessionRankUps.append("\(bookName(v))升到 \(rank) 级") }
            }
        }
        let order = Volumes.all
        func key(_ g: BookGain) -> (Int, Int, Int) { (g.leveledUp ? 1 : 0, g.gain, -(order.firstIndex(of: g.volume) ?? 99)) }
        lastBookGains = gains.sorted { key($0) < key($1) }      // 涨得少的在上，升级的排最后（挨着按钮）
        return out
    }

    /// 旧存档接到经验升级：已有的等级补上那一级起步的经验；进去过的岛还没秘籍的，补上秘籍。
    func migrateBooks() {
        guard xpLevels else { return }
        var ch = ProgressChange()
        for (v, s) in progress.volumes where s.obtained && s.xp == 0 && s.rank > 1 {
            ch.volumes[v] = VolumeState(obtained: true, rank: s.rank, xp: BookXP.seed(rank: s.rank))
        }
        for r in content.regions where r.playable && (progress.regions[r.id]?.phase ?? .untouched) != .untouched
            && progress.volumes[r.volume]?.obtained != true {
            let xp = progress.volumes[r.volume]?.xp ?? 0
            ch.volumes[r.volume] = VolumeState(obtained: true, rank: BookXP.level(xp), xp: xp)
        }
        if !ch.volumes.isEmpty { save(ch) }
    }

    /// 开发用（调参「标为拿到」、启动参数 -obtain）：把这几卷标为拿到，对应的地区算打通，不演出。
    /// 顺带当作梦打完、云雾散过、看过地图引导，好直接看地图。
    func debugObtain(_ volumes: [String]) {
        var ch = ProgressChange()
        var jn = progress.journey
        jn.openingDone = true
        jn.fogCleared = true
        jn.tipsSeen.insert(Self.mapGuideKey)
        ch.journey = jn
        for v in volumes where RankFx.order.contains(v) {
            let r = CardRank.rank(of: v, obtained: true, previous: progress.volumes[v]?.rank ?? 0, best: cardBest, content: content)
            ch.volumes[v] = VolumeState(obtained: true, rank: max(1, r), xp: progress.volumes[v]?.xp ?? 0)
            for region in content.regions where region.volume == v {
                ch.regions[region.id] = RegionState(phase: .cleared, stationIndex: 0, route: nil)
            }
        }
        save(ch)
    }

    /// 已拿到的卷，词卡够了就升重。
    func checkRankUps() {
        guard !xpLevels else { return }                       // 按经验升级时，升级在结算里就结了
        let best = cardBest
        for (v, s) in progress.volumes where s.obtained {
            let r = CardRank.rank(of: v, obtained: true, previous: s.rank, best: best, content: content)
            if r > s.rank {
                var ch = ProgressChange()
                ch.volumes[v] = VolumeState(obtained: true, rank: r, xp: s.xp)
                save(ch)
                sessionRankUps.append("《\(Volumes.name(v))》练到第\(["", "一", "二", "三", "四", "五"][r])重")
                if obtained == nil { rankUp = RankUp(volume: v, rank: r) }
            }
        }
    }

    /// 小结卡片的「接着走」。
    func continueRoute() {
        guard let card = pendingCard else { return }
        pendingCard = nil
        if !card.won { enterStation(); return }               // 再来一次：重打这一站
        if card.finished { screen = .map; return }            // 走完了：回江湖
        walkFrom = stationIndex - 1
    }

    /// 「收功」：收获总结。
    func harvest() {
        pendingCard = nil
        screen = .harvest
    }

    var harvestLines: [String] {
        var out: [String] = []
        let d = typedCommonChars - sessionStartChars
        if d > 0 { out.append("今天多打出了 \(d) 个常用字") }
        out += sessionRankUps
        if !sessionLearned.isEmpty {
            out.append("今天学会了：\(sessionLearned.sorted().prefix(8).joined(separator: "、"))\(sessionLearned.count > 8 ? " 等 \(sessionLearned.count) 招" : "")")
        }
        if out.isEmpty { out.append("今天练了一会儿，手更熟了") }
        return out
    }
}

// MARK: - 演示（-autoplay）：自动点下一步，模拟器上能一路看下去

extension JourneyController {
    static var autoplay: Bool { ProcessInfo.processInfo.arguments.contains("-autoplay") }

    func autoAdvance(after seconds: Double = 2.5, _ step: @escaping @MainActor (JourneyController) -> Void) {
        guard Self.autoplay else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            if let self { step(self) }
        }
    }
}

// MARK: - 碑

extension JourneyController {
    /// 第一次进这座岛（还没有进度）时要先打碑文；梦里比武那种开场没有碑；-noStele（UI 测试）跳过。
    func needsStele(_ r: Region) -> Bool {
        duel.tuning.openingStyle == 1 && r.stele != nil && progress.regions[r.id] == nil
            && !ProcessInfo.processInfo.arguments.contains("-noStele")
    }

    /// 碑文里这次要亮键的音节：只有葫芦集（整个游戏第一次打碑文）全程亮（返回 nil，整句都亮）；
    /// 别的岛不亮（2026-11-18：原来亮还没碰到过的音节，碑文多是这一关的新音节，几乎整句都亮，像又教了一遍）。
    func steleGuide(_ r: Region) -> Set<String>? {
        r.id == "huluji" ? nil : []
    }

    /// 碑上写的这一关的概况：练什么、几个音节、几张词卡、一路几场比武。
    func steleBrief(_ r: Region) -> SteleBrief {
        let syllables = content.syllables(in: r.volume).count
        let route = steleRoute.flatMap { $0.regionId == r.id ? $0 : nil } ?? planRoute(r)
        let fights = route.stations.filter { $0.kind != .encounter }.count
        let first = content.level(of: r.volume) == 0
        return SteleBrief(focus: r.hint, note: r.difficulty,
                          facts: ["\(syllables) 个\(first ? "" : "新")音节", "\(cardTotal(in: r.volume)) 张词卡", "\(fights) 场比武"])
    }

    /// 碑文打完：记音节和打出的字。
    func steleDone(_ t: TextController) {
        recordText(t)
        autoAdvance { j in j.leaveStele() }
    }

    /// 打完碑文：进长卷（调参面板看碑时回江湖）。
    func leaveStele() {
        guard case .region(let id) = screen, regionStage == .stele else { return }
        if previewingStele {
            previewingStele = false
            screen = .map
            return
        }
        inkTransition { [weak self] in self?.enterRegion(id, skipStele: true) }
    }

    /// 碑文打到一半点「返回」：回江湖，下次进来还从碑开始。
    func steleBack() {
        previewingStele = false
        screen = .map
    }

    /// 调参面板：看一块碑，不清进度，打完回江湖。
    func previewStele(_ id: String) {
        guard let r = content.region(id), r.stele != nil else { return }
        steleRoute = planRoute(r)
        previewingStele = true
        duelToken += 1
        regionStage = .stele
        screen = .region(id)
    }
}
