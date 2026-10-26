import Foundation

/// 学习规则的全部数值。默认值在这里，App 的 Tuning.default.json 的 learning 一节可以覆盖，调参面板能改。
public struct LearningTuning: Codable, Sendable, Equatable {
    // 熟练度
    /// 第一次出现就打对、没看提示、上手不到这么多秒 → 直接熟练。
    public var firstFluentStart: Double = 1.0
    /// 熟练：至少在这么多个不同的日子里打对……
    public var fluentDays: Int = 2
    /// ……并且最近这么多次都没错……
    public var fluentRecent: Int = 3
    /// ……上手都不到这么多秒。
    public var fluentStart: Double = 2.0
    /// 精通：熟练之后，最近这么多次都没错、上手不到 masterStart 秒。
    public var masterRecent: Int = 5
    public var masterStart: Double = 0.8

    // 复习
    /// 刚成为新招的音节，在接下来第几张牌里复现。
    public var replayOffsets: [Int] = [2, 5]
    /// 之后按这些天数间隔复习。
    public var reviewDays: [Int] = [1, 3, 7, 16, 35]

    // 出字
    /// 在地区里：本卷已会、本卷没会、复习、垫底各占多少。
    public var mixKnown: Double = 0.35
    public var mixNew: Double = 0.25
    public var mixReview: Double = 0.3
    public var mixFiller: Double = 0.1
    /// 一场最多几个新音节；出完一个新的，后面至少隔几张会的。
    public var newPerDuel: Int = 3
    public var newGap: Int = 2
    /// 每天最多新学几个音节。
    public var newPerDay: Int = 8
    /// 刚错过一个，接下来几张出会的。
    public var afterMissKnown: Int = 2
    /// 打对率目标和统计窗口（张数）。
    public var successTarget: Double = 0.85
    public var successWindow: Int = 20
    /// 最近出过的多少个词不重复。
    public var recentWords: Int = 14

    // 渐进摸底
    public var probeFamilies: Int = 3
    public var probePerFamily: Int = 4
    /// 某族错这么多个以上记为重点，再探 probeFocusExtra 个。
    public var probeFocusMisses: Int = 2
    public var probeFocusExtra: Int = 3

    // 手速
    /// 每场结束按这个权重滑动更新。
    public var speedWeight: Double = 0.2

    // 初入江湖
    public var openingBattles: Int = 3
    public var openingTargetSeconds: Double = 40
    public var openingMinHP: Int = 1

    public init() {}

    enum CodingKeys: String, CodingKey, CaseIterable {
        case firstFluentStart, fluentDays, fluentRecent, fluentStart, masterRecent, masterStart
        case replayOffsets, reviewDays, mixKnown, mixNew, mixReview, mixFiller, newPerDuel, newGap, newPerDay
        case afterMissKnown, successTarget, successWindow, recentWords
        case probeFamilies, probePerFamily, probeFocusMisses, probeFocusExtra, speedWeight
        case openingBattles, openingTargetSeconds, openingMinHP
    }

    /// 缺少的字段用默认值，旧的覆盖文件在加了新字段后仍然能读。
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = LearningTuning()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) throws -> T { try c.decodeIfPresent(T.self, forKey: k) ?? def }
        firstFluentStart = try v(.firstFluentStart, d.firstFluentStart)
        fluentDays = try v(.fluentDays, d.fluentDays)
        fluentRecent = try v(.fluentRecent, d.fluentRecent)
        fluentStart = try v(.fluentStart, d.fluentStart)
        masterRecent = try v(.masterRecent, d.masterRecent)
        masterStart = try v(.masterStart, d.masterStart)
        replayOffsets = try v(.replayOffsets, d.replayOffsets)
        reviewDays = try v(.reviewDays, d.reviewDays)
        mixKnown = try v(.mixKnown, d.mixKnown)
        mixNew = try v(.mixNew, d.mixNew)
        mixReview = try v(.mixReview, d.mixReview)
        mixFiller = try v(.mixFiller, d.mixFiller)
        newPerDuel = try v(.newPerDuel, d.newPerDuel)
        newGap = try v(.newGap, d.newGap)
        newPerDay = try v(.newPerDay, d.newPerDay)
        afterMissKnown = try v(.afterMissKnown, d.afterMissKnown)
        successTarget = try v(.successTarget, d.successTarget)
        successWindow = try v(.successWindow, d.successWindow)
        recentWords = try v(.recentWords, d.recentWords)
        probeFamilies = try v(.probeFamilies, d.probeFamilies)
        probePerFamily = try v(.probePerFamily, d.probePerFamily)
        probeFocusMisses = try v(.probeFocusMisses, d.probeFocusMisses)
        probeFocusExtra = try v(.probeFocusExtra, d.probeFocusExtra)
        speedWeight = try v(.speedWeight, d.speedWeight)
        openingBattles = try v(.openingBattles, d.openingBattles)
        openingTargetSeconds = try v(.openingTargetSeconds, d.openingTargetSeconds)
        openingMinHP = try v(.openingMinHP, d.openingMinHP)
    }
}
