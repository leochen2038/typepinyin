import Foundation

extension DuelEngine {
    /// 打错时马上提示正确的下一个字母，不用等卡住的时间（提示关掉时也不提示）。
    func hintNow(word: Word, typed: Int) {
        guard tuning.hintSeconds > 0, case .fighting = phase else { return }
        let l = Array(word.letters)
        guard typed < l.count, currentHint != l[typed] else { return }
        currentHint = l[typed]
        events.append(.hint(l[typed]))
    }

    /// 锁定目标后卡住 hintSeconds 秒：提示它的下一个字母。首字母不提示。
    /// 被提示过的那一招不算金色。
    func checkHint() {
        // 首字母不提示：还没锁定目标时由玩家自己挑牌
        guard tuning.hintSeconds > 0, currentHint == nil, target != .none, case .fighting = phase else { return }
        let since: Double
        let letter: Character?
        switch target {
        case .none:
            since = readyAt
            if let inc = opponent.incoming {
                letter = inc.word.firstLetter
            } else {
                letter = (cards.first { $0.hasFlaw && !$0.inactive } ?? cards.first { !$0.inactive })?.word.firstLetter
            }
        case .card(let i):
            since = lastAcceptedAt ?? clock
            let l = Array(cards[i].word.letters)
            letter = cards[i].typed.count < l.count ? l[cards[i].typed.count] : nil
        case .incoming:
            since = lastAcceptedAt ?? clock
            if let inc = opponent.incoming {
                let l = Array(inc.word.letters)
                letter = inc.typed.count < l.count ? l[inc.typed.count] : nil
            } else { letter = nil }
        }
        guard let c = letter, clock - since >= tuning.hintSeconds else { return }
        currentHint = c
        if target != .none { wordClean = false }
        hintedBeforeLock = target == .none
        events.append(.hint(c))
    }
}
