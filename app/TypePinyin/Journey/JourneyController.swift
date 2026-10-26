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
    }

    var screen: Screen = .map
    /// 每开一场新比武加一（比武画面按它重建、重新开打）。
    var duelToken = 0
    /// 这次打开已经演过开场白。
    var openingLineShown = false
    @ObservationIgnored var tipQueue: [String] = []

    // 地区
    enum RegionStage: Equatable { case scroll, duel, encounter }
    var regionStage: RegionStage = .scroll
    var route: Route?
    var stationIndex = 0
    /// 第一次进这片地区：先演镜头从掌门摇到山脚。
    var introPending = false
    /// 刚打完一站，回到长卷上要显示的小结卡片。
    var pendingCard: PendingCard?
    /// 接着走：小人从这一站走到下一站。
    var walkFrom: Int?
    /// 刚拿到的秘籍（演出用）。
    var obtained: String?
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
        }
        learner.records = progress.records
        sessionStartChars = learner.typableCommonChars(content)
        screen = startScreen()
        if case .region(let id) = screen { enterRegion(id) }
        if ProcessInfo.processInfo.arguments.contains("-codex") { screen = .codex }   // 开发用：直接打开秘籍页
        duel.journey = self
    }

    /// 一打开去哪：没打完初入江湖就接着打，没拿到《基本功》就去十里坡，否则回江湖。
    func startScreen() -> Screen {
        if !progress.journey.openingDone { return .opening(battle: progress.journey.openingBattle) }
        if progress.volumes["base"]?.obtained != true { return .region("shilipo") }
        return .map
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
    }

    /// 调参「清空进度」：清掉本设备的全部记录，回到第一次打开。
    func resetProgress() {
        try? store?.resetAll()
        progress = store?.load() ?? Progress()
        learner = Learner(tuning: duel.tuning.learning)
        DayClock.resetOffset()
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

    var probeState: ProbeState {
        progress.journey.probe.flatMap { try? JSONDecoder().decode(ProbeState.self, from: $0) } ?? ProbeState()
    }

    var newTodaySoFar: Int { progress.journey.newTodayDay == today ? progress.journey.newToday : 0 }

    /// 排一场比武：出字器、单场设置、对手；打完回调 done（交回小结和学习变化）。
    func planDuel(volume: String?, foe: Fighter, minHP: Int = 0, targetSeconds: Double? = nil, lives: Int? = nil,
                  boss: Bool = false, backdrop: (region: String, station: Int)? = nil,
                  done: @escaping (DuelSummary, LearnerChange) -> Void) {
        let dealer = Dealer(content: content, learner: learner, probe: probeState,
                            context: DealContext(volume: volume, today: today, newToday: newTodaySoFar),
                            seed: UInt64(Date().timeIntervalSince1970 * 1000) & 0xFFFF_FFFF)
        let source = JourneyCardSource(dealer: dealer) { [weak self] v in self?.rank(of: v) ?? 0 }
        var setup = DuelSetup()
        setup.learned = learnedSet
        setup.secondsPerLetter = progress.speed?.secondsPerLetter
        setup.targetSeconds = targetSeconds
        setup.minHP = minHP
        setup.lives = lives ?? 1
        setup.bossPressure = boss
        setup.day = today
        duel.plan = DuelController.DuelPlan(
            bank: AppResources.journeyBank, setup: setup, source: source,
            foeName: foe.name, foeTitle: foe.title, robe: UIColor(hexString: foe.look.robe), backdrop: backdrop,
            onEvent: { [weak self] e in self?.handleTipEvent(e) },
            onFinish: { [weak self] summary, attempts, spl in
                guard let self else { return }
                let change = self.learner.record(attempts)
                self.sessionLearned.formUnion(change.newlyMet.filter { self.content.volume(of: $0) != "base" })
                var j = self.progress.journey
                if let data = try? JSONEncoder().encode(dealer.probe) { j.probe = data }
                j.newToday = dealer.context.newToday
                j.newTodayDay = self.today
                var ch = ProgressChange()
                ch.journey = j
                ch.records = Set(attempts.map(\.spelling)).compactMap { self.learner.records[$0] }
                // 手速跨场记住（按设备）：每场结束按权重滑动一次
                if !attempts.isEmpty, !JourneyFlags.fast {
                    let start = attempts.map(\.startSeconds).reduce(0, +) / Double(attempts.count)
                    let old = self.progress.speed.map { PlayerSpeed(secondsPerLetter: $0.secondsPerLetter, startSeconds: $0.startSeconds, samples: $0.samples) }
                    let s = PlayerSpeed.updated(old, secondsPerLetter: spl, startSeconds: start, weight: self.learner.tuning.speedWeight)
                    ch.speed = SpeedState(secondsPerLetter: s.secondsPerLetter, startSeconds: s.startSeconds, samples: s.samples)
                }
                self.save(ch)
                done(summary, change)
            })
    }

    /// 小结卡片多出来的收获：能打出多少个常用字、这一场学会了几招。
    func gains(_ change: LearnerChange) -> [String] {
        var g: [String] = []
        let n = learner.typableCommonChars(content)
        if n > 0 { g.append("你已经能打出 \(n.formatted()) 个常用字") }
        // 学会的招：基本功大多数人本来就会，不算进来
        let learned = change.newlyMet.filter { content.volume(of: $0) != "base" }
        if !learned.isEmpty { g.append("这一场学会了 \(learned.count) 招") }
        return g
    }

    // MARK: 入门提示

    func handleTipEvent(_ e: DuelEvent) {
        let tip: JourneyTip?
        switch e {
        case .started: tip = .firstCard
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

    /// 开打初入江湖的第 n 场（从 0 起）。
    func startOpening(_ n: Int) {
        let foes = content.place("chuRuJiangHu")?.foes ?? []
        guard !foes.isEmpty else { return }
        let t = duel.tuning.learning
        planDuel(volume: nil, foe: foes[n % foes.count], minHP: t.openingMinHP, targetSeconds: t.openingTargetSeconds) { [weak self] _, change in
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
                self.duelToken += 1
                if last { self.enterRegion("shilipo") } else { self.screen = .opening(battle: n + 1) }
            }
            self.duel.summaryActions = [.init(label: last ? "走向十里坡" : "继续", primary: true, action: go)]
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

    /// 进一片地区：挑战中就接着走，否则排一条新路线（再去一趟也是新路线）。
    func enterRegion(_ id: String) {
        guard let region = content.region(id) else { return }
        let state = progress.regions[id]
        if let s = state, s.phase == .inProgress, let data = s.route,
           let r = try? JSONDecoder().decode(Route.self, from: data), s.stationIndex < r.stations.count {
            route = r
            stationIndex = s.stationIndex
            introPending = false
        } else {
            let r = RoutePlanner.plan(region: region, content: content, seed: UInt64(Date().timeIntervalSince1970 * 1000) & 0xFFFF_FFFF)
            route = r
            stationIndex = 0
            introPending = (state?.phase ?? .untouched) == .untouched
            saveRegion(id, phase: state?.phase == .cleared ? .cleared : .inProgress)
        }
        pendingCard = nil
        walkFrom = nil
        obtained = nil
        regionStage = .scroll
        screen = .region(id)
    }

    func saveRegion(_ id: String, phase: RegionPhase) {
        var ch = ProgressChange()
        ch.regions[id] = RegionState(phase: phase, stationIndex: stationIndex, route: route.flatMap { try? JSONEncoder().encode($0) })
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

    /// 比武画面出现时：排这一站的比武。
    func startStationDuel() {
        guard let region = currentRegion, let st = currentStation, let foe = st.foe else { return }
        let boss = st.kind == .boss
        planDuel(volume: region.volume, foe: foe, lives: boss ? 3 : 1, boss: boss,
                 backdrop: (region.id, stationIndex)) { [weak self] summary, change in
            self?.stationDone(won: summary.won, summary: summary, change: change)
        }
    }

    /// 奇遇打完：每个字按这一句干不干净记学习；不会失败。
    func encounterDone(_ t: TextController) {
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
        save(ch)
        autoAdvance { j in j.leaveEncounter() }
    }

    /// 奇遇的「接着走」。
    func leaveEncounter() {
        guard let region = currentRegion else { return }
        stationIndex += 1
        saveRegion(region.id, phase: progress.regions[region.id]?.phase == .cleared ? .cleared : .inProgress)
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
                saveRegion(region.id, phase: .cleared)
                if firstClear { obtainVolume(region.volume) }
            } else {
                saveRegion(region.id, phase: progress.regions[region.id]?.phase == .cleared ? .cleared : .inProgress)
            }
        }
        checkRankUps()
        pendingCard = PendingCard(summary: summary, title: won ? "打赢了\(st.foe?.name ?? "")" : "再来一次",
                                  gains: gains(change), won: won, finished: finished)
        regionStage = .scroll
        autoAdvance(after: obtained != nil || rankUp != nil ? 5 : 3) { j in
            j.obtained = nil
            j.rankUp = nil
            j.continueRoute()
        }
    }

    /// 拿到一卷：存下来，按熟练度直接升到对应的重数。
    func obtainVolume(_ v: String) {
        let r = learner.rank(of: v, obtained: true, previous: 0, content: content)
        var ch = ProgressChange()
        ch.volumes[v] = VolumeState(obtained: true, rank: r)
        save(ch)
        obtained = v
    }

    /// 已拿到的卷，熟练度够了就升重（演出在 US4 加）。
    func checkRankUps() {
        for (v, s) in progress.volumes where s.obtained {
            let r = learner.rank(of: v, obtained: true, previous: s.rank, content: content)
            if r > s.rank {
                var ch = ProgressChange()
                ch.volumes[v] = VolumeState(obtained: true, rank: r)
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
        let d = learner.typableCommonChars(content) - sessionStartChars
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
