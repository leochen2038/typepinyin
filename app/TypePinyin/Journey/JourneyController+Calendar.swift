import DuelCore
import Foundation
import LearningCore
import ProgressStore

/// 日历和勋章（docs/calendar-badges.md）：打完一场的结算时记一次当天的记录，按五条台阶发勋章。
/// 两样都只把已经发生的事记下来，不给经验、不催。
extension JourneyController {
    static let backfillKey = "badges.backfill"
    static func badgeSeenKey(_ key: String) -> String { "badge:\(key)" }

    var calendarOn: Bool { duel.tuning.calendarOn }
    var badgesOn: Bool { duel.tuning.badgesOn }
    var badgeRules: BadgeRules { BadgeRules(tuning: learner.tuning) }
    /// 收集词卡最后一级「全部」：词表里一共几个词。
    var cardsInAll: Int { content.words.count }

    // MARK: 结算前后

    /// 结算前记一下现在的数，结算后比一比，就知道这一场多了什么。
    struct SettleBefore {
        var cards: Int
        var sealed: Set<String>
        var crowned: Bool
        var levels: Int
    }

    /// 一场结算要记的：比武还是文字、新收的词卡（按收到的先后）、秘籍涨的经验、比武速度、在哪座岛、那一场的一句话。
    struct SettleInfo {
        var text: Bool
        var newCards: [String]
        var books: [BookGain]
        var cpm: Double
        var region: String?
        /// 「半山镇，打赢了镇上的镖师林大」。
        var note: String
    }

    func settleBefore() -> SettleBefore {
        SettleBefore(cards: cards.count, sealed: sealedRegions, crowned: crowned, levels: levelUpsSoFar)
    }

    /// 掌门盖过印的岛（按岛的顺序）。
    var sealedRegions: Set<String> { Set(content.regions.filter { $0.playable && cleared($0.id) }.map(\.id)) }

    /// 十本秘籍一共升了几次级：每本从 1 级起，拿到时的 1 级不算。
    var levelUpsSoFar: Int {
        progress.volumes.values.filter(\.obtained).map { max(0, $0.rank - 1) }.reduce(0, +)
    }

    /// 这次结算记不记：梦里（开场教学）、调参面板看碑、自动演示都不算。
    var shouldLogSettle: Bool {
        let recordDemo = ProcessInfo.processInfo.arguments.contains("-recordAutoplay")   // UI 测试：自动演示也照记
        if (Self.autoplay && !recordDemo) || previewingStele { return false }
        if case .opening = screen { return false }
        return true
    }

    /// 打完一场：记进今天这一份，按五条台阶发勋章。返回这一场新拿到的勋章（结算页演）。
    @discardableResult
    func logSettle(_ before: SettleBefore, _ info: SettleInfo) -> [BadgeRecord] {
        guard shouldLogSettle else { return [] }
        let day = today
        let now = Date().timeIntervalSinceReferenceDate
        var log = progress.days[day]?.first { $0.deviceId == deviceId } ?? DayLog(day: day, deviceId: deviceId, device: Self.deviceName)
        if info.text { log.texts += 1 } else { log.duels += 1 }
        log.newCards += max(0, cards.count - before.cards)
        // 升级：这一场每本秘籍从几级升到几级，一级记一次（秘籍等级那条台阶的「那一刻」按这个顺序）
        var ups: [String] = []
        for g in info.books where g.gain > 0 {
            log.xp[g.volume, default: 0] += g.gain
            log.xpAt[g.volume] = now
            let a = BookXP.level(g.before), b = BookXP.level(g.after)
            if b > a { for lv in (a + 1)...b { ups.append("\(g.volume)|\(lv)") } }
        }
        log.levelUps += ups
        let newSeals = content.regions.filter { $0.playable && sealedRegions.contains($0.id) && !before.sealed.contains($0.id) }.map(\.id)
        log.seals += newSeals.filter { !log.seals.contains($0) }
        if crowned && !before.crowned { log.crowned = true }
        if !info.text, info.cpm >= 1 { log.bestCPM = max(log.bestCPM, info.cpm) }
        if let r = info.region, content.region(r) != nil { log.lastRegion = r; log.lastAt = now }

        var ch = ProgressChange()
        ch.days = [log]
        save(ch)                                                       // 先记这一天，「打几场」「来了几天」按记下的数

        let awards = badgesOn ? newBadges(before: before, info: info, ups: ups, day: day) : []
        if !awards.isEmpty {
            log.badges += awards.map(\.key)
            var ch2 = ProgressChange()
            ch2.days = [log]
            ch2.badges = awards
            save(ch2)
        }
        return awards
    }

    /// 设备的叫法（日历点开一天，两台都练了写「iPhone 5 场、Mac 3 场」）。
    static var deviceName: String { ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp ? "Mac" : "iPhone" }

    // MARK: 勋章

    /// 每条台阶现在的数。
    func badgeValue(_ t: BadgeTrack) -> Int {
        switch t {
        case .cards: return cards.count
        case .books: return sealedRegions.count + (crowned ? 1 : 0)
        case .levels: return levelUpsSoFar
        case .fights: return progress.days.values.map { DaySummary($0).fights }.reduce(0, +)
        case .days: return progress.days.values.filter { DaySummary($0).fights > 0 }.count
        }
    }

    /// 到了的级里还没拿到的，都发一枚，日期都是今天；每一枚记下那一刻。
    func newBadges(before: SettleBefore, info: SettleInfo, ups: [String], day: Int) -> [BadgeRecord] {
        let rules = badgeRules
        var out: [BadgeRecord] = []
        for t in BadgeTrack.allCases {
            let value = badgeValue(t)
            for step in 0..<rules.reached(t, value: value, total: cardsInAll) where progress.badges[BadgeRecord.key(t, step)] == nil {
                let n = rules.threshold(t, step, total: cardsInAll)
                var memento = ""
                switch t {
                case .cards:                                              // 第 N 张是这一场收的第几张
                    let k = n - before.cards - 1
                    if info.newCards.indices.contains(k) { memento = info.newCards[k] }
                case .books:
                    memento = bookBadgeRegion(step) ?? ""
                case .levels:
                    let k = n - before.levels - 1
                    if ups.indices.contains(k) { memento = ups[k] }
                case .fights:
                    if value == n { memento = info.note }
                case .days:
                    break
                }
                out.append(BadgeRecord(track: t, step: step, day: day, memento: memento))
            }
        }
        return out
    }

    /// 秘籍收集第 step 级是哪座岛（第 N 本就是第 N 座岛）；最后一级是「盟」。
    func bookBadgeRegion(_ step: Int) -> String? {
        let order = content.regions.filter(\.playable)
        return order.indices.contains(step) ? order[step].id : (step == order.count ? "盟" : nil)
    }

    /// 旧存档补发（3.8）：上线后第一次打开，按已有的词卡、掌门印、秘籍等级一次补上；打几场、来了几天从今天开始数。
    /// 返回补发的枚数（0 = 不出卡片）。只做一次。
    @discardableResult
    func backfillBadges() -> Int {
        guard badgesOn, !progress.journey.tipsSeen.contains(Self.backfillKey) else { return 0 }
        let rules = badgeRules
        var awards: [BadgeRecord] = []
        for t in [BadgeTrack.cards, .books, .levels] {
            for step in 0..<rules.reached(t, value: badgeValue(t), total: cardsInAll) where progress.badges[BadgeRecord.key(t, step)] == nil {
                awards.append(BadgeRecord(track: t, step: step, day: today, memento: t == .books ? bookBadgeRegion(step) ?? "" : ""))
            }
        }
        var j = progress.journey
        j.tipsSeen.insert(Self.backfillKey)
        var ch = ProgressChange()
        ch.journey = j
        ch.badges = awards
        save(ch)
        if !awards.isEmpty { backfillCard = awards }
        if ScrollReveal.started { ScrollReveal.badges.formUnion(awards.map(\.key)) }   // 补发的有自己的卡片，卷轴上不再落
        return awards.count
    }

    /// 调参「重新补发一次」：清掉补发记号再补一次，回地图时出卡片。
    func redoBackfill() {
        var j = progress.journey
        j.tipsSeen.remove(Self.backfillKey)
        var ch = ProgressChange()
        ch.journey = j
        save(ch)
        backfillBadges()
    }

    /// 拿到的勋章（按台阶、级排好）。
    var earnedBadges: [BadgeRecord] {
        progress.badges.values.sorted { (BadgeTrack.allCases.firstIndex(of: $0.track) ?? 0, $0.step) < (BadgeTrack.allCases.firstIndex(of: $1.track) ?? 0, $1.step) }
    }

    /// 最新拿到的几枚：日期晚的在后；同一天按颜色高低、台阶顺序。
    func latestBadges(_ n: Int) -> [BadgeRecord] {
        let rules = badgeRules
        let all = progress.badges.values.sorted {
            ($0.day, rules.band($0.track, $0.step), $0.step) < ($1.day, rules.band($1.track, $1.step), $1.step)
        }
        return Array(all.suffix(n))
    }

    /// 还没看过的新勋章（进过勋章页就不算新了）。
    var unseenBadges: Set<String> {
        Set(progress.badges.keys.filter { !progress.journey.tipsSeen.contains(Self.badgeSeenKey($0)) })
    }

    /// 地图「收获」按钮和收获页勋章卡片上的红点：卷轴上演过的就不算（收集册里那枚角上的「新」照旧，进过勋章页才去掉）。
    var hasNewBadges: Bool { badgesOn && !unseenBadges.subtracting(ScrollReveal.badges).isEmpty }

    func markBadgesSeen() {
        let keys = unseenBadges.map(Self.badgeSeenKey)
        guard !keys.isEmpty else { return }
        var j = progress.journey
        j.tipsSeen.formUnion(keys)
        var ch = ProgressChange()
        ch.journey = j
        save(ch)
    }

    // MARK: 一场的那句话（打几场的「那一刻」）

    /// 「半山镇，打赢了镇上的镖师林大」「葫芦集，5 人群战」「练习场，和胡大叔过招」。
    func fightNote(place: String, foe: Fighter, won: Bool, group: Int?) -> String {
        if let n = group, n > 1 { return "\(place)，\(n) 人群战" }
        return won ? "\(place)，打赢了\(foe.title)\(foe.name)" : "\(place)，和\(foe.title)\(foe.name)过招"
    }

    /// 这一场在哪（打几场那一句的开头）。
    var settlePlace: String {
        switch screen {
        case .practice: return "练习场"
        case .gathering: return "武林大会"
        case .region(let id): return content.region(id)?.name ?? ""
        default: return ""
        }
    }
}

// MARK: - 日历的读法

extension JourneyController {
    func daySummary(_ day: Int) -> DaySummary? {
        guard let logs = progress.days[day] else { return nil }
        let s = DaySummary(logs)
        return s.fights > 0 ? s : nil
    }

    /// 练过的日子（从早到晚）。
    var practicedDays: [Int] { progress.days.keys.filter { daySummary($0) != nil }.sorted() }

    /// 这一天的方块：哪座岛（写第一个字、用那本秘籍的封面色）。经验最多的那本；没涨经验用最后去的岛。
    func stampRegion(_ s: DaySummary) -> Region? {
        if let v = s.topVolume, let r = region(giving: v) { return r }
        return content.region(s.lastRegion) ?? content.regions.first
    }

    /// 方块右下角的小朱红印：那天掌门盖印的岛的第一个字；当选武林盟主那天写「盟」。
    func sealMark(_ s: DaySummary) -> String? {
        if s.crowned { return "盟" }
        return s.seals.last.flatMap { content.region($0) }.map { String($0.name.prefix(1)) }
    }

    /// 这一周（周一到周日）的第几天练过：七个 DaySummary?。
    func week(of day: Int) -> [Int] {
        let monday = day - DayClock.weekday(of: day)
        return (0..<7).map { monday + $0 }
    }

    /// 本周练了几天（到今天为止）。
    var practicedThisWeek: Int { week(of: today).filter { $0 <= today && daySummary($0) != nil }.count }

    /// 点开一天的那几行（2.5），是 0 或没有的那行不出。
    func dayLines(_ s: DaySummary) -> [String] {
        var out: [String] = []
        var fights: [String] = []
        if s.duels > 0 { fights.append("比武 \(s.duels) 场") }
        if s.texts > 0 { fights.append("文字 \(s.texts) 篇") }
        var first = fights.joined(separator: " · ")
        if s.devices.count > 1 { first += "\n" + s.devices.map { "\($0.device) \($0.fights) 场" }.joined(separator: "、") }
        out.append(first)
        if s.newCards > 0 { out.append("收了 \(s.newCards) 张新词卡") }
        let books = s.xp.filter { $0.value > 0 }.sorted { ($0.value, s.xpAt[$0.key] ?? 0) > ($1.value, s.xpAt[$1.key] ?? 0) }
        if !books.isEmpty {
            let lv = s.levelReached
            let shown = books.prefix(3).map { v, n in
                (region(giving: v)?.name ?? Volumes.name(v)) + " +\(n)" + (lv[v].map { "（升到 \($0) 级）" } ?? "")
            }
            out.append(shown.joined(separator: " · ") + (books.count > 3 ? " 等 \(books.count) 本" : ""))
        }
        var seals = s.seals.compactMap { content.region($0)?.name }.map { $0 + "掌门盖印" }
        if s.crowned { seals.append("当选武林盟主") }
        if !seals.isEmpty { out.append(seals.joined(separator: "、")) }
        let fast = s.devices.filter { $0.bestCPM >= 1 }
        if s.duels > 0, !fast.isEmpty {
            if fast.count > 1 { out.append("最快 " + fast.map { "\($0.device) \(Int($0.bestCPM.rounded()))" }.joined(separator: " · ") + " 字/分") }
            else { out.append("最快 \(Int(fast[0].bestCPM.rounded())) 字/分") }
        }
        return out
    }
}
