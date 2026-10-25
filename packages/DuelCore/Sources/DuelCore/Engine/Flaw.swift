import Foundation

extension DuelEngine {
    /// 三张牌里保持恰好一张破绽。优先给待复现的音节，其次本卷的音节，否则随机；尽量不给刚补上的那张。
    func assignFlaw(excluding fresh: Int?) {
        guard features.contains(.flaw), cards.count > 1 else { return }
        for k in cards.indices { cards[k].hasFlaw = false }
        let candidates = cards.indices.filter { $0 != fresh && !cards[$0].isFinisher }
        let pool = candidates.isEmpty ? Array(cards.indices) : candidates
        let replay = learner.pendingReplay.union(learner.taught)
        if let k = pool.first(where: { cards[$0].word.syllables.contains(where: replay.contains) }) {
            cards[k].hasFlaw = true
        } else if let k = pool.first(where: { cards[$0].word.volume == "biyin-shang" }) {
            cards[k].hasFlaw = true
        } else {
            cards[pool[Int(rng.next() % UInt64(pool.count))]].hasFlaw = true
        }
    }
}
