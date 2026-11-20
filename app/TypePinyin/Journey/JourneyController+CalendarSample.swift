import Foundation
import LearningCore
import ProgressStore

/// 开发用（启动参数 -sampleCalendar）：写进正式版规格板的样例数据，看日历页、勋章页、收获页。
/// 10 月 8 日开始练，练过 26 天（10 月 12 天、11 月 14 天），打通葫芦集、半山镇、长风城，一共 32 枚勋章。
/// 只写日历和勋章；词卡、秘籍等级用存档里现有的（可以配合 -obtain 看书架）。
extension JourneyController {
    func seedSampleCalendar() {
        // （月, 日, 岛, 比武, 文字, 掌门盖印, 最快速度）
        let plan: [(Int, Int, String, Int, Int, Bool, Double)] = [
            (10, 8, "huluji", 5, 1, false, 14), (10, 9, "huluji", 6, 0, false, 15), (10, 10, "huluji", 6, 1, false, 15),
            (10, 12, "huluji", 6, 0, false, 16), (10, 14, "huluji", 5, 0, false, 16), (10, 15, "huluji", 6, 0, false, 16),
            (10, 17, "huluji", 4, 0, false, 17), (10, 20, "huluji", 5, 1, false, 17), (10, 22, "huluji", 3, 0, false, 17),
            (10, 25, "huluji", 4, 0, false, 18), (10, 28, "huluji", 3, 0, false, 18), (10, 30, "huluji", 4, 0, false, 18),
            (11, 1, "huluji", 6, 1, false, 18), (11, 2, "huluji", 7, 0, true, 19), (11, 3, "banshanzhen", 5, 1, false, 17),
            (11, 5, "banshanzhen", 4, 0, false, 18), (11, 6, "banshanzhen", 6, 2, true, 19), (11, 7, "changfengcheng", 5, 1, false, 18),
            (11, 9, "changfengcheng", 6, 0, false, 20), (11, 10, "changfengcheng", 6, 1, false, 20), (11, 11, "changfengcheng", 7, 0, true, 21),
            (11, 13, "baimeitai", 5, 1, false, 21), (11, 14, "banshanzhen", 6, 0, false, 22), (11, 16, "changfengcheng", 5, 0, false, 22),
            (11, 18, "baimeitai", 7, 1, false, 22), (11, 19, "baimeitai", 6, 1, false, 23),
        ]
        func day(_ m: Int, _ d: Int) -> Int {
            var c = DateComponents(); c.year = 2026; c.month = m; c.day = d
            return DayClock.day(of: Calendar.current.date(from: c) ?? Date())
        }
        var ch = ProgressChange()
        for (m, d, r, duels, texts, seal, cpm) in plan {
            let v = content.region(r)?.volume ?? "base"
            var log = DayLog(day: day(m, d), deviceId: deviceId, device: Self.deviceName)
            log.duels = duels
            log.texts = texts
            log.newCards = 20 + (d * 11) % 45
            log.xp = [v: 150 + (d * 37) % 150]
            log.xpAt = [v: Double(d)]
            if d % 4 == 3 { log.levelUps = ["\(v)|\(2 + d % 3)"] }
            if seal { log.seals = [r] }
            log.bestCPM = cpm
            log.lastRegion = r
            ch.days.append(log)
        }
        // 32 枚：词卡 9、秘籍收集 3、秘籍等级 4、打几场 8、来了几天 8（日期、那一刻照样例）
        let base = content.regions.first { $0.id == "huluji" }?.volume ?? "base"
        let ban = content.region("banshanzhen")?.volume ?? base, bai = content.region("baimeitai")?.volume ?? base
        let got: [(BadgeTrack, [(Int, Int, String)])] = [
            (.cards, [(10, 8, "大米"), (10, 8, "葫芦"), (10, 8, "地图"), (10, 9, "读书"), (10, 14, "自己"), (10, 20, "历史"), (11, 3, "安心"), (11, 9, "长城"), (11, 19, "白菜")]),
            (.books, [(11, 2, "huluji"), (11, 6, "banshanzhen"), (11, 11, "changfengcheng")]),
            (.levels, [(10, 9, "\(base)|2"), (10, 15, "\(base)|4"), (11, 6, "\(ban)|3"), (11, 13, "\(bai)|2")]),
            (.fights, [(10, 8, "葫芦集，打赢了拦路的小混混胡四"), (10, 8, "葫芦集，3 人群战"), (10, 9, "葫芦集，打赢了路边毛贼刘三"), (10, 12, "葫芦集，5 人群战"),
                       (10, 14, "练习场，3 人群战"), (10, 25, "葫芦集，和集上的拳师胡大叔过招"), (11, 9, "长风城，5 人群战"), (11, 19, "白梅台，3 人群战")]),
            (.days, [(10, 8, ""), (10, 9, ""), (10, 10, ""), (10, 14, ""), (10, 17, ""), (10, 25, ""), (11, 2, ""), (11, 11, "")]),
        ]
        for (t, list) in got {
            for (i, (m, d, memo)) in list.enumerated() {
                let b = BadgeRecord(track: t, step: i, day: day(m, d), memento: memo)
                ch.badges.append(b)
                if let k = ch.days.firstIndex(where: { $0.day == b.day }) { ch.days[k].badges.append(b.key) }
            }
        }
        var j = progress.journey
        j.tipsSeen.insert(Self.backfillKey)
        j.tipsSeen.formUnion(ch.badges.filter { $0.day < day(11, 19) }.map { Self.badgeSeenKey($0.key) })   // 11 月 19 日那两枚是新的
        ch.journey = j
        save(ch)
    }
}
