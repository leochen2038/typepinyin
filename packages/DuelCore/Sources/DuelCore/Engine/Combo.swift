import Foundation

extension DuelEngine {
    /// 连招窗口：初始 2.6 秒，按最近的上手时间收紧（1.7 × 上手 + 0.4），不低于下限。
    var comboWindow: Double {
        guard let r = player.reaction else { return tuning.comboWindowInitial }
        return min(tuning.comboWindowInitial, max(tuning.comboWindowMin, 1.7 * r + 0.4))
    }

    func breakCombo() {
        guard player.combo > 0 else { return }
        player.combo = 0
        emit(.comboBroken)
    }

    /// 没在打任何目标、又超过窗口 → 断连招。新牌还被回顾盖着时不算。
    func checkComboTimeout() {
        guard player.combo > 0, target == .none, !awaitingReveal, let last = player.lastStrikeAt else { return }
        if clock - last > comboWindow { breakCombo() }
    }

    /// 开始打一个新目标时：超过窗口才开始，连招断。
    func checkComboGapOnLock() {
        guard player.combo > 0, !awaitingReveal, let last = player.lastStrikeAt else { return }
        if clock - last > comboWindow { breakCombo() }
    }

    func addCombo() {
        player.combo += 1
        player.maxCombo = max(player.maxCombo, player.combo)
        emit(.comboChanged(player.combo))
    }

    /// 出招后更新手速：上手时间和每字母用时都取滚动平均。
    func recordSpeed(word: Word) {
        guard let first = firstLetterAt else { return }
        let lat = max(0, first - readyAt)
        let dur = max(0, clock - first)
        player.reaction = player.reaction.map { 0.7 * $0 + 0.3 * lat } ?? lat
        let per = min(2.0, max(0.12, (lat + dur) / Double(max(1, word.letterCount))))
        player.secondsPerLetter = 0.8 * player.secondsPerLetter + 0.2 * per
    }
}
