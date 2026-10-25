import Foundation

extension DuelEngine {
    /// 蓄势：没被选中的牌每秒 +8%，最多 ×2。
    func storeAt(_ card: MoveCard, _ g: Double) -> Double {
        guard features.contains(.store), !card.isFinisher, !singleCard else { return 1 }
        return min(tuning.storeMax, 1 + tuning.storeGainPerSecond * max(0, g - card.dealtAt))
    }
}
