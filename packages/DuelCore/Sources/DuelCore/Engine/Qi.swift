import Foundation

extension DuelEngine {
    /// 气条开着才攒气、才因为气满出必杀牌。
    var qiOn: Bool { features.contains(.qi) && tuning.qiBar }

    func gainQi(_ n: Int) {
        guard qiOn, !finisherPending, !cards.contains(where: \.isFinisher) else { return }
        if tuning.movesPerDuel > 0, moveMarks.count >= tuning.movesPerDuel - 1 { return }
        let before = player.qi
        player.qi = min(100, player.qi + n)
        if before < 100, player.qi >= 100 {
            finisherPending = true
            emit(.qiFull)
        }
    }

    /// 按字母攒气时，一张牌按几个字母算「一张」（前几关一张牌五六个字母，后几关八九个）。
    static let qiLettersPerCard = 6.0

    /// 每出一招 +(5 + 连招数)，最多 +15；打中破绽再 +10；打出完美再 + perfectQi；必杀用掉全部气。
    /// 按字母攒气时（qiByLetters）整招的气再乘「字母数 / 6」。
    func gainQiForStrike(flaw: Bool, finisher: Bool, perfect: Bool = false, letters: Int = 0) {
        guard qiOn else { return }
        if finisher {
            player.qi = 0
            return
        }
        let n = min(tuning.qiPerStrikeMax, tuning.qiPerStrikeBase + player.combo) + (flaw ? tuning.flawQiBonus : 0)
            + (perfect ? tuning.perfectQi : 0)
        let share = tuning.qiByLetters && letters > 0 ? Double(letters) / Self.qiLettersPerCard : 1
        gainQi(Int((Double(n) * share * max(1, tuning.qiMultiplier)).rounded()))     // 测试用的攒气倍数
    }
}
