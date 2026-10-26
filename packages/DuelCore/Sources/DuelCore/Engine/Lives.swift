import Foundation

/// 命数（试玩）：对手有好几条血（掌门 3 条，最终 Boss 5 条）。打空一条，他跪地一下再站起来，血条换个颜色重新满上；
/// 打空最后一条才倒下。多出来的伤害打进下一条；开了 finisherTakesLife 时，必杀命中直接扣一条命。
/// 每丢一条命，对手蓄力快 lifeSpeedup。群战和按招数计的一场不用命数。
extension DuelEngine {
    var livesOn: Bool { !groupMode && tuning.movesPerDuel == 0 }

    func startLives() {
        let n = livesOn ? min(5, max(1, setup.lives ?? tuning.foeLives)) : 1
        opponent.maxLives = n
        opponent.lives = n
        foeDownUntil = 0
    }

    /// 一条命的血：整场的血平分到每条命上，一场的长短和一条命时差不多。
    func perLifeHP(_ hp: Int) -> Int {
        let lives = setup.lives ?? tuning.foeLives
        guard livesOn, lives > 1 else { return hp }
        return max(1, Int((Double(hp) / Double(min(5, lives))).rounded()))
    }

    /// 蓄力时长的倍数：丢了几条命就快几次。
    var lifePressureFactor: Double {
        pow(max(0.3, 1 - tuning.lifeSpeedup), Double(opponent.maxLives - opponent.lives))
    }

    /// 扣血。打空这一条但还有命：扣一条命、血条满上（多出来的伤害打进去），对手跪地 lifeDownSeconds 秒，这段时间不蓄力。
    /// 返回 true 表示这一招扣了一条命。
    @discardableResult
    func hitWithLives(_ dmg: Int, finisher: Bool) -> Bool {
        opponent.hp -= dmg
        var lost = false
        if opponent.lives > 1, opponent.hp <= 0 {
            let over = -opponent.hp
            opponent.lives -= 1
            opponent.hp = max(1, opponent.maxHP - over)
            lost = true
        } else if opponent.lives > 1, finisher, tuning.finisherTakesLife {
            opponent.lives -= 1
            opponent.hp = opponent.maxHP
            lost = true
        }
        opponent.hp = max(0, opponent.hp)
        if lost {
            foeDownUntil = clock + tuning.lifeDownSeconds
            if bossMode, let s = opponent.pressureStart { opponent.pressureStart = s + tuning.lifeDownSeconds }   // 跪着时掌门的蓄力停住
            emit(.lifeLost(left: opponent.lives))
        }
        return lost
    }
}
