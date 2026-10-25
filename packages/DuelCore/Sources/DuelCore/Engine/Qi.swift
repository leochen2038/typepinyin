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

    /// 每出一招 +(5 + 连招数)，最多 +15；打中破绽再 +10；打出完美再 + perfectQi；必杀用掉全部气。
    func gainQiForStrike(flaw: Bool, finisher: Bool, perfect: Bool = false) {
        guard qiOn else { return }
        if finisher {
            player.qi = 0
            return
        }
        let n = min(tuning.qiPerStrikeMax, tuning.qiPerStrikeBase + player.combo) + (flaw ? tuning.flawQiBonus : 0)
            + (perfect ? tuning.perfectQi : 0)
        gainQi(n)
    }
}
