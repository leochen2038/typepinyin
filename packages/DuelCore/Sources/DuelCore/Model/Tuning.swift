import Foundation
import LearningCore

/// 比武的全部可调数值。App 里的默认值在 Resources/Tuning.default.json。
public struct Tuning: Codable, Sendable, Equatable {
    public var comboWindowInitial: Double = 2.6
    public var comboWindowMin: Double = 1.0
    /// 每连一招伤害多几成。2026-10-25 起默认 0：伤害只看字母数，连招的回报改成攒气（原为 0.08）。
    public var comboBonusPerHit: Double = 0
    public var attackInterval: Double = 5.5
    public var attackIntervalJitter: Double = 0.3
    public var chargePerLetterFactor: Double = 2.0
    public var chargeBaseSeconds: Double = 0.9
    public var chargeMinSeconds: Double = 2.4
    public var parryFraction: Double = 0.45
    public var stunSeconds: Double = 1.6
    public var stunDamageMultiplier: Double = 1.5
    public var incomingDamage: Int = 10
    public var mistakeDamage: Int = 3
    public var playerMaxHP: Int = 100
    public var duelTargetSeconds: Double = 75
    /// 秘籍每重伤害多几成。2026-10-25 起默认 0：重数只体现在爆字母的样子上，不让练熟的人一场打得更短（原为 0.1）。
    public var rankBonusPerLevel: Double = 0
    public var storeGainPerSecond: Double = 0.08
    public var storeMax: Double = 2.0
    public var flawMultiplier: Double = 1.5
    public var flawQiBonus: Int = 10
    public var qiPerStrikeBase: Int = 5
    public var qiPerStrikeMax: Int = 15
    public var qiParry: Int = 18
    public var qiBlock: Int = 6
    public var finisherBase: Double = 45
    public var finisherComboBonus: Double = 0.03
    /// 必杀打掉对手总血量的比例（0 = 按 finisherBase 和连招算的旧算法）。按比例算，不管对手血多血少，必杀的分量都一样。
    public var finisherShare: Double = 0.25
    /// 打出一招完美多攒几点气（又快又准，必杀来得更早）。
    public var perfectQi: Int = 5
    /// 群战（试玩）：一场好几个敌人，场上最多 groupSize 个，倒下一个补一个，一共 groupTotal 个；
    /// 打完一张牌自动打蓄力最多的那个并打断它的蓄力，必杀打全场。只在一张牌模式下有效。
    public var groupFight: Bool = false
    /// 命数（试玩）：对手有几条血（1 = 一条；掌门 3 条，最终 Boss 5 条）。打空一条跪地再站起来，血条满上。
    public var foeLives: Int = 1
    /// 必杀命中直接扣一条命。
    public var finisherTakesLife: Bool = false
    /// 每丢一条命，对手蓄力快几成。
    public var lifeSpeedup: Double = 0.1
    /// 丢一条命后跪地几秒（这段时间不蓄力）。
    public var lifeDownSeconds: Double = 1.2
    /// 掌门蓄力打不断（试玩，对手 3 条命以上才生效）：掌门按自己的节奏蓄力，打完一张牌不重来，只往回推 bossPushBack；
    /// 必杀才打断（清零）。一轮蓄力 = bossCycleCards 张牌的时间，满了打玩家 bossHit。
    public var bossPressure: Bool = false
    public var bossPushBack: Double = 0.2
    public var bossCycleCards: Double = 3
    public var bossHit: Int = 8
    /// 学习规则的数值（熟练度、复习、出字、摸底、手速、初入江湖）。
    public var learning: LearningTuning = LearningTuning()
    /// 打什么：3 = 旅程（默认：初入江湖、地区、总地图），0 = 比武，1 = 短句（奇遇），2 = 文章（下一篇）。
    public var textMode: Int = 3
    /// 试玩：打文字时的动效。0 = 简版（打完一句半秒快爆），1 = 战斗动效 + 回顾（打完一句翻回顾牌、逐个字母爆开），
    /// 2 = 战斗动效、不要回顾（下划线、打完一个字变红迸粒子，打完一句马上下一句；默认）。
    public var textStyle: Int = 2
    public var groupSize: Int = 3
    public var groupTotal: Int = 5
    public var heavyLetters: Int = 10
    public var mediumLetters: Int = 7
    public var replayOffsets: [Int] = [2, 5]
    public var commitOnRelease: Bool = true
    public var expectedKeyGrowPt: Double = 2
    public var nearMissMaxPt: Double = 8
    public var hapticsOnKey: Bool = true
    public var comboGoldAt: Int = 8
    public var comboRedAt: Int = 15
    /// 一场打几招就赢，最后一招是金色成语牌。0 = 按对手血量：打空血条才赢，必杀靠攒满气（默认）。
    public var movesPerDuel: Int = 0
    /// 一招算「金色」：没打错、没拆招，每个字母平均不超过这么多秒。
    public var goldSecondsPerLetter: Double = 0.6
    /// 卡住多少秒后，在键盘上提示下一个字母（0 = 不提示）。
    public var hintSeconds: Double = 2.0
    /// 场上同时有几张词牌。1 张时没有挑牌、蓄势、破绽和来招，改成对手蓄力条。
    public var cardsOnTable: Int = 1
    /// 对手蓄力条（只在 1 张牌时）：时长 = 字母数 × 每字母用时 × 系数 + 基础，至少下限；条满之前没打完，对手出手。
    public var pressureFactor: Double = 2.4
    public var pressureBaseSeconds: Double = 1.5
    public var pressureMinSeconds: Double = 3.0
    /// 试看：秘籍重数的爆字母效果。-1 = 关（默认彩纸），0–5 = 所有字母按这一重来爆（切片里还没有真的重数）。
    public var rankFx: Int = -1
    /// 试看：爆字母的主题。空 = 每个字母按它所在音节属于哪一卷，填卷名（如 liangzi-shang）= 全部用这一卷。
    public var rankFxTheme: String = ""
    /// 画面：状态栏下面那排每招一个的小圆点（最近 10 招金不金、哪招是必杀）。
    public var moveDots: Bool = true
    /// 玩家的气条：每出一招攒气，攒满出一张成语必杀牌。固定招数（movesPerDuel > 0）时必杀固定在最后一招，可以关掉。
    public var qiBar: Bool = true
    /// 画面：每打对一个字母，主角怎么把字母从键上取到左手（只影响演出）。
    /// 0 = 剑气（字母化成一道光打进主角身上），1 = 绳镖（左手甩出去钉住、拽回来）。
    /// 2026-10-25 定：默认剑气；绳镖不对玩家开放，只在调参面板里能切。
    public var grabStyle: Int = 0
    /// 取字节奏：0 = 每个字母取一次，1 = 一个音节取一次（字母先串起来，音节打完一把拽回）。
    public var grabMode: Int = 0
    /// 画面：长词出刀时每刀的最短间隔（秒）。字母多时每刀会压缩，但不低于这个值。
    public var slashMinGap: Double = 0.075
    /// 卡壳提示时，该用的那只手那一侧的字母键整块浅浅亮一下。
    public var handZones: Bool = true

    public init() {}

    public static let standard = Tuning()

    enum CodingKeys: String, CodingKey, CaseIterable {
        case comboWindowInitial, comboWindowMin, comboBonusPerHit, attackInterval, attackIntervalJitter
        case chargePerLetterFactor, chargeBaseSeconds, chargeMinSeconds, parryFraction, stunSeconds
        case stunDamageMultiplier, incomingDamage, mistakeDamage, playerMaxHP, duelTargetSeconds
        case rankBonusPerLevel, storeGainPerSecond, storeMax, flawMultiplier, flawQiBonus
        case qiPerStrikeBase, qiPerStrikeMax, qiParry, qiBlock, finisherBase, finisherComboBonus
        case heavyLetters, mediumLetters, replayOffsets, commitOnRelease
        case expectedKeyGrowPt, nearMissMaxPt, hapticsOnKey, comboGoldAt, comboRedAt, movesPerDuel, goldSecondsPerLetter, hintSeconds
        case cardsOnTable, pressureFactor, pressureBaseSeconds, pressureMinSeconds, grabStyle, handZones, slashMinGap, grabMode, qiBar, moveDots, rankFx, rankFxTheme, finisherShare, perfectQi, groupFight, groupSize, groupTotal, textMode, textStyle
        case foeLives, finisherTakesLife, lifeSpeedup, lifeDownSeconds
        case bossPressure, bossPushBack, bossCycleCards, bossHit
        case learning
    }

    /// 缺少的字段用默认值，这样旧的覆盖文件在加了新字段后仍然能读。
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Tuning()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) throws -> T { try c.decodeIfPresent(T.self, forKey: k) ?? def }
        comboWindowInitial = try v(.comboWindowInitial, d.comboWindowInitial)
        comboWindowMin = try v(.comboWindowMin, d.comboWindowMin)
        comboBonusPerHit = try v(.comboBonusPerHit, d.comboBonusPerHit)
        attackInterval = try v(.attackInterval, d.attackInterval)
        attackIntervalJitter = try v(.attackIntervalJitter, d.attackIntervalJitter)
        chargePerLetterFactor = try v(.chargePerLetterFactor, d.chargePerLetterFactor)
        chargeBaseSeconds = try v(.chargeBaseSeconds, d.chargeBaseSeconds)
        chargeMinSeconds = try v(.chargeMinSeconds, d.chargeMinSeconds)
        parryFraction = try v(.parryFraction, d.parryFraction)
        stunSeconds = try v(.stunSeconds, d.stunSeconds)
        stunDamageMultiplier = try v(.stunDamageMultiplier, d.stunDamageMultiplier)
        incomingDamage = try v(.incomingDamage, d.incomingDamage)
        mistakeDamage = try v(.mistakeDamage, d.mistakeDamage)
        playerMaxHP = try v(.playerMaxHP, d.playerMaxHP)
        duelTargetSeconds = try v(.duelTargetSeconds, d.duelTargetSeconds)
        rankBonusPerLevel = try v(.rankBonusPerLevel, d.rankBonusPerLevel)
        storeGainPerSecond = try v(.storeGainPerSecond, d.storeGainPerSecond)
        storeMax = try v(.storeMax, d.storeMax)
        flawMultiplier = try v(.flawMultiplier, d.flawMultiplier)
        flawQiBonus = try v(.flawQiBonus, d.flawQiBonus)
        qiPerStrikeBase = try v(.qiPerStrikeBase, d.qiPerStrikeBase)
        qiPerStrikeMax = try v(.qiPerStrikeMax, d.qiPerStrikeMax)
        qiParry = try v(.qiParry, d.qiParry)
        qiBlock = try v(.qiBlock, d.qiBlock)
        finisherBase = try v(.finisherBase, d.finisherBase)
        finisherComboBonus = try v(.finisherComboBonus, d.finisherComboBonus)
        heavyLetters = try v(.heavyLetters, d.heavyLetters)
        mediumLetters = try v(.mediumLetters, d.mediumLetters)
        replayOffsets = try v(.replayOffsets, d.replayOffsets)
        commitOnRelease = try v(.commitOnRelease, d.commitOnRelease)
        expectedKeyGrowPt = try v(.expectedKeyGrowPt, d.expectedKeyGrowPt)
        nearMissMaxPt = try v(.nearMissMaxPt, d.nearMissMaxPt)
        hapticsOnKey = try v(.hapticsOnKey, d.hapticsOnKey)
        comboGoldAt = try v(.comboGoldAt, d.comboGoldAt)
        comboRedAt = try v(.comboRedAt, d.comboRedAt)
        movesPerDuel = try v(.movesPerDuel, d.movesPerDuel)
        goldSecondsPerLetter = try v(.goldSecondsPerLetter, d.goldSecondsPerLetter)
        hintSeconds = try v(.hintSeconds, d.hintSeconds)
        cardsOnTable = try v(.cardsOnTable, d.cardsOnTable)
        pressureFactor = try v(.pressureFactor, d.pressureFactor)
        pressureBaseSeconds = try v(.pressureBaseSeconds, d.pressureBaseSeconds)
        pressureMinSeconds = try v(.pressureMinSeconds, d.pressureMinSeconds)
        grabStyle = min(1, try v(.grabStyle, d.grabStyle))     // 旧存档：1 隔空取字、2 绳镖，都算绳镖
        grabMode = try v(.grabMode, d.grabMode)
        qiBar = try v(.qiBar, d.qiBar)
        moveDots = try v(.moveDots, d.moveDots)
        rankFx = try v(.rankFx, d.rankFx)
        rankFxTheme = try v(.rankFxTheme, d.rankFxTheme)
        finisherShare = try v(.finisherShare, d.finisherShare)
        perfectQi = try v(.perfectQi, d.perfectQi)
        groupFight = try v(.groupFight, d.groupFight)
        groupSize = try v(.groupSize, d.groupSize)
        groupTotal = try v(.groupTotal, d.groupTotal)
        foeLives = try v(.foeLives, d.foeLives)
        finisherTakesLife = try v(.finisherTakesLife, d.finisherTakesLife)
        lifeSpeedup = try v(.lifeSpeedup, d.lifeSpeedup)
        lifeDownSeconds = try v(.lifeDownSeconds, d.lifeDownSeconds)
        bossPressure = try v(.bossPressure, d.bossPressure)
        bossPushBack = try v(.bossPushBack, d.bossPushBack)
        bossCycleCards = try v(.bossCycleCards, d.bossCycleCards)
        bossHit = try v(.bossHit, d.bossHit)
        learning = try v(.learning, d.learning)
        textMode = try v(.textMode, d.textMode)
        textStyle = try v(.textStyle, d.textStyle)
        handZones = try v(.handZones, d.handZones)
        slashMinGap = try v(.slashMinGap, d.slashMinGap)
    }
}
