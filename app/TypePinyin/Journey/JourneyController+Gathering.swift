import DuelCore
import Foundation
import LearningCore
import ProgressStore

/// 武林大会（山顶，最后一关）：请帖 → 碑 → 第一场十位掌门（群战，一次上三位）→ 当选武林盟主 → 第二场妙笔书生 → 收尾。
/// 进度存在地区进度表的 wuLinDaHui 一行：stationIndex 是该打第几场（0 十位掌门、1 妙笔书生），打通了 phase 是 cleared（再来一次也不回退）。
extension JourneyController {
    static let gatheringId = "wuLinDaHui"
    static let invitationKey = "gatheringInvitation"

    var gatheringState: RegionState? { progress.regions[Self.gatheringId] }
    var gatheringWon: Bool { gatheringState?.phase == .cleared }
    /// 该打第几场：0 十位掌门，1 妙笔书生。
    var gatheringStep: Int { gatheringState?.stationIndex ?? 0 }
    /// 当选了武林盟主（第一场打赢过）；之后输给妙笔书生、再来一次都不会丢。
    var crowned: Bool { gatheringWon || gatheringStep >= 1 }

    /// 开放：走完最后一座岛（或拿到它那一卷）；进去过的照样开着。
    var gatheringOpen: Bool {
        guard content.gathering != nil else { return false }
        if gatheringState != nil { return true }
        guard let last = content.regions.filter(\.playable).last else { return false }
        return progress.regions[last.id]?.phase == .cleared || progress.volumes[last.volume]?.obtained == true
    }

    /// 地图上要不要弹请帖：开放了、还没看过、还没打通。
    var invitationPending: Bool { gatheringOpen && !gatheringWon && !progress.journey.tipsSeen.contains(Self.invitationKey) }

    func markInvitationSeen() {
        showInvitation = false
        guard !progress.journey.tipsSeen.contains(Self.invitationKey) else { return }
        var jn = progress.journey
        jn.tipsSeen.insert(Self.invitationKey)
        var ch = ProgressChange()
        ch.journey = jn
        save(ch)
    }

    func saveGathering(phase: RegionPhase, step: Int) {
        var ch = ProgressChange()
        ch.regions[Self.gatheringId] = RegionState(phase: max(phase, gatheringState?.phase ?? .untouched), stationIndex: step, route: nil)
        save(ch)
    }

    /// 上山：第一次先打武林大会碑，以后直接到擂台。
    func enterGathering() {
        guard content.gathering != nil else { return }
        markInvitationSeen()
        duelToken += 1
        if gatheringState == nil && duel.tuning.openingStyle == 1 && !ProcessInfo.processInfo.arguments.contains("-noStele") {
            gatheringStage = .stele
        } else {
            if gatheringState == nil { saveGathering(phase: .inProgress, step: 0) }
            gatheringStage = .hall
        }
        screen = .gathering
    }

    func gatheringSteleDone(_ t: TextController) {
        recordText(t)
        autoAdvance { j in j.leaveGatheringStele() }
    }

    /// 打完碑：存下「来过」，到擂台。
    func leaveGatheringStele() {
        guard screen == .gathering, gatheringStage == .stele else { return }
        if gatheringState == nil { saveGathering(phase: .inProgress, step: 0) }
        inkTransition { [weak self] in self?.gatheringStage = .hall }
    }

    /// 碑上的概况：十关的字都在，两场比武。
    var gatheringBrief: SteleBrief {
        SteleBrief(focus: "十关的字", note: "十位掌门轮番上台，最后和妙笔书生比快",
                   facts: ["\(content.syllables.count) 个音节", "\(content.words.count) 张词卡", "2 场比武"])
    }

    /// 擂台上的「挑战」：打该打的那一场。
    func startGatheringFight() {
        duelToken += 1
        gatheringStage = .duel(gatheringStep)
    }

    /// 打通以后的「再来一次」：从十位掌门重新打，称号不变，看看又快了多少。
    func replayGathering() {
        saveGathering(phase: .cleared, step: 0)
        startGatheringFight()
    }

    /// 比武画面出现时：排这一场。
    func startGatheringDuel(_ k: Int) {
        guard let g = content.gathering else { return }
        let masters = content.regions.filter(\.playable)
        guard let first = masters.first else { return }
        let seed = UInt64(Date().timeIntervalSince1970 * 1000) & 0xFFFF_FFFF
        if k == 0 {
            // 十位掌门：群战一次上三位，按闯关的顺序轮着上，每位十几秒；台上是哪几位，就出他们那几关的词
            let lengths = LearningTuning.lengthMap(learner.tuning.middleLengths)
            let collected = Set(cards.map(\.text))
            let vols = masters.map(\.volume)
            var dealers: [String: Dealer] = [:]
            for (i, v) in vols.enumerated() {
                dealers[v] = Dealer(content: content, learner: learner,
                                    context: DealContext(volume: v, today: today, newToday: newTodaySoFar, lengths: lengths,
                                                         allowedSyllables: content.syllables(upTo: v), collected: collected),
                                    seed: seed &+ UInt64(i))
            }
            let content = self.content
            planDuel(volume: nil, foe: first.boss, backdrop: ("dream", 0, 1), lengths: lengths,
                     group: true, groupTotal: masters.count, groupHP: Array(repeating: 0.15, count: masters.count),
                     groupNames: masters.map(\.boss.name), groupLines: masters.map { g.praise[$0.id] ?? "" },
                     makeSource: { [weak self] onCard in
                         GatheringCardSource(content: content, volumes: vols, dealers: dealers,
                                             onStage: { self?.duel.groupOnStage ?? [] },
                                             rankOf: { self?.rank(of: $0) ?? 0 }, onCard: onCard)
                     }) { [weak self] summary, change in
                self?.gatheringDuelDone(0, summary: summary, change: change)
            }
        } else {
            // 妙笔书生：五条命、蓄力打不断，出十关里三到五个字的词，必杀出成语
            let pool = content.words.filter { $0.text.count >= 3 }
            planDuel(volume: nil, foe: g.boss, lives: 5, boss: true, backdrop: ("dream", 0, 1), lengths: [3: 0.3, 4: 0.4, 5: 0.3],
                     pool: pool) { [weak self] summary, change in
                self?.gatheringDuelDone(1, summary: summary, change: change)
            }
        }
    }

    /// 一场打完：赢了往下走（第一场赢了当选盟主），输了回擂台重打这一场；称号、打通都不会丢。
    func gatheringDuelDone(_ k: Int, summary: DuelSummary, change: LearnerChange) {
        let won = summary.won
        let wasCrowned = crowned
        if won {
            if k == 0 { saveGathering(phase: .inProgress, step: 1) }
            else { saveGathering(phase: .cleared, step: 0) }
        }
        var g = gains(change)
        if won, let faster = GatheringSpeedNote.record(fight: k, cpm: summary.charsPerMinute) {
            g.insert("比上次快了 \(Int(faster.rounded())) 字/分", at: 0)
        }
        if won && k == 1 { lastGatheringCPM = summary.charsPerMinute }
        duel.summaryGains = g
        let go: @MainActor () -> Void = { [weak self] in
            guard let self else { return }
            self.checkRankUps()
            if !won { self.gatheringStage = .hall }
            else if k == 0 { self.gatheringStage = wasCrowned ? .hall : .crowned }
            else { self.gatheringStage = .finale }
        }
        duel.summaryActions = [.init(label: "继续", primary: true, action: go)]
        autoAdvance(after: 5) { _ in go() }
    }

    /// 收尾的几个数：只报收获。
    var finaleLines: [String] {
        var out: [String] = []
        let n = learnedSyllables
        if n > 0 { out.append("学会了 \(n) 个音节") }
        let chars = typedCommonChars
        if chars > 0 { out.append("能打出 \(chars) 个常用字") }
        let now = lastGatheringCPM ?? TypingSpeedNote.last
        if let now, let first = TypingSpeedNote.first, now - first >= 1 {
            out.append("打字速度从 \(Int(first.rounded())) 到 \(Int(now.rounded())) 字/分")
        } else if let now {
            out.append("打字速度 \(Int(now.rounded())) 字/分")
        }
        if !cards.isEmpty { out.append("收了 \(cards.count) 张词卡") }
        return out
    }
}

/// 武林大会每一场上次打赢时的速度（字/分），再来一次时比一比；按设备存在本机。
enum GatheringSpeedNote {
    /// 记下这一次；比上次快了就返回快了多少。
    static func record(fight: Int, cpm: Double) -> Double? {
        guard cpm >= 1 else { return nil }
        let key = "gathering.cpm.\(fight)"
        let d = UserDefaults.standard
        let old = d.object(forKey: key) as? Double
        d.set(cpm, forKey: key)
        guard let old, cpm - old >= 1 else { return nil }
        return cpm - old
    }
}

/// 武林大会第一场的出牌：台上站着哪几位掌门，就从他们那几关里挑一关出词（每关一个出字器，各自避开刚出过的）。
final class GatheringCardSource: CardSource {
    let content: LearningContent
    let volumes: [String]
    let dealers: [String: Dealer]
    let onStage: () -> [Int]
    let rankOf: (String) -> Int
    let onCard: (Word, Bool, Double) -> Void

    init(content: LearningContent, volumes: [String], dealers: [String: Dealer], onStage: @escaping () -> [Int],
         rankOf: @escaping (String) -> Int, onCard: @escaping (Word, Bool, Double) -> Void) {
        self.content = content
        self.volumes = volumes
        self.dealers = dealers
        self.onStage = onStage
        self.rankOf = rankOf
        self.onCard = onCard
    }

    private func dealer() -> Dealer {
        let on = onStage().filter { volumes.indices.contains($0) }
        return dealers[volumes[on.randomElement() ?? 0]]!
    }

    func nextCard(avoidingFirstLetters: Set<Character>, avoidingTexts: Set<String>) -> (word: Word, rank: Int) {
        let d = dealer().next(avoidingFirstLetters: avoidingFirstLetters, avoidingTexts: avoidingTexts)
        return (JourneyCardSource.word(d.word), rankOf(d.word.volume))
    }

    func nextIdiom() -> (word: Word, rank: Int)? {
        let w = dealer().nextIdiom()
        return (JourneyCardSource.word(w), rankOf(w.volume))
    }

    func cardDone(_ word: Word, clean: Bool) {
        for d in dealers.values { d.note(JourneyCardSource.content(word), clean: clean) }
    }

    func cardDone(_ word: Word, clean: Bool, secondsPerLetter: Double) {
        for d in dealers.values { d.note(JourneyCardSource.content(word), clean: clean, secondsPerLetter: secondsPerLetter) }
        onCard(word, clean, secondsPerLetter)
    }

    func newMove(_ spelling: String, in word: Word) {
        dealers[content.owner(of: word.syllables)]?.newMove(spelling, word: word.text)
    }
}
