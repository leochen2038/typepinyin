import Foundation

extension DuelEngine {
    /// 基础伤害：每个字的拼音字母数 × (1 + 重数 × 10%) 后相加。
    func baseDamage(_ card: MoveCard) -> Double {
        let bonus = 1 + Double(card.rank) * tuning.rankBonusPerLevel
        return card.word.syllables.reduce(0) { $0 + Double($1.count) * bonus }
    }

    /// 一招的伤害 = 基础 × 连招 × 蓄势 × 破绽 × 晕眩；必杀另算（默认打掉对手总血量的 finisherShare）。
    /// 2026-10-25 起默认连招、重数都不加伤害，单张牌模式也没有蓄势、破绽、晕眩，伤害就是字母数。`combo` 是这一招算上之后的连招数。
    func damage(for card: MoveCard, combo: Int, store: Double) -> Int {
        let stun = opponent.isStunned(at: clock) ? tuning.stunDamageMultiplier : 1
        if card.isFinisher {
            if tuning.finisherShare > 0 { return max(1, Int((Double(opponent.maxHP) * tuning.finisherShare * stun).rounded())) }
            let v = tuning.finisherBase * (1 + tuning.finisherComboBonus * Double(combo)) * stun
            return Int(v.rounded())
        }
        let comboMul = 1 + tuning.comboBonusPerHit * Double(max(0, combo - 1))
        let flaw = (features.contains(.flaw) && card.hasFlaw) ? tuning.flawMultiplier : 1
        let v = baseDamage(card) * comboMul * store * flaw * stun
        return max(1, Int(v.rounded()))
    }

    /// 对手血量按玩家手速换算，使一场打下来约为目标时长。
    static func opponentHP(secondsPerLetter: Double, tuning: Tuning) -> Int {
        let perStrikeSeconds = 7 * secondsPerLetter * 1.5
        let hp = tuning.duelTargetSeconds / perStrikeSeconds * 7.5
        return max(50, Int(hp.rounded()))
    }
}
