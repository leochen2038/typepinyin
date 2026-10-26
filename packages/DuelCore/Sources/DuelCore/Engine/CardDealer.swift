import Foundation

extension DuelEngine {
    /// 场上其他目标的首字母（不含 `slot` 这张牌）。
    func takenFirstLetters(excludingSlot slot: Int?) -> Set<Character> {
        var set = Set<Character>()
        for (k, c) in cards.enumerated() where k != slot { set.insert(c.word.firstLetter) }
        if let inc = opponent.incoming { set.insert(inc.word.firstLetter) }
        return set
    }

    func onTable(excludingSlot slot: Int?) -> Set<String> {
        Set(cards.enumerated().filter { $0.offset != slot }.map(\.element.word.text))
    }

    func rank(for word: Word) -> Int { word.volume == "biyin-shang" ? 0 : 1 }

    /// 在 `slot` 位置发一张新牌：先看是否该出金色成语牌，再看有没有到期复现的音节，否则按洗好的顺序取。
    /// 保证和场上目标首字母不冲突、不和场上的词重复。
    func makeCard(slot: Int, forceFinisher: Bool = false) -> MoveCard {
        let taken = takenFirstLetters(excludingSlot: slot)
        let table = onTable(excludingSlot: slot)
        let ok: (Word) -> Bool = { !taken.contains($0.firstLetter) && !table.contains($0.text) }
        defer { dealCount += 1; nextCardId += 1 }

        if forceFinisher || (qiOn && finisherPending), let src = source, let (idiom, rank) = src.nextIdiom() {
            finisherPending = false
            return MoveCard(id: nextCardId, word: idiom, dealtAt: clock, isFinisher: true, rank: rank)
        }
        if forceFinisher || (qiOn && finisherPending),
           let idiom = bank.idioms.shuffled(using: &rng).first(where: ok) ?? (forceFinisher ? bank.idioms.first : nil) {
            finisherPending = false
            return MoveCard(id: nextCardId, word: idiom, dealtAt: clock, isFinisher: true, rank: rank(for: idiom))
        }

        if let src = source {
            let (w, rank) = src.nextCard(avoidingFirstLetters: taken, avoidingTexts: table)
            return MoveCard(id: nextCardId, word: w, dealtAt: clock, rank: rank)
        }

        if features.contains(.teaching) {
            let due = learner.replayQueue.filter { $0.deal <= dealCount }
            for entry in due {
                if let w = bank.plainWords.first(where: { ok($0) && $0.syllables.contains(entry.syllable) }) {
                    learner.replayQueue.removeAll { $0.deal == entry.deal && $0.syllable == entry.syllable }
                    return MoveCard(id: nextCardId, word: w, dealtAt: clock, rank: rank(for: w))
                }
                // 这次凑不出来，顺延到下一张
                if let k = learner.replayQueue.firstIndex(where: { $0.deal == entry.deal && $0.syllable == entry.syllable }) {
                    learner.replayQueue[k].deal = dealCount + 1
                }
            }
        }

        for _ in 0..<wordOrder.count {
            let w = wordOrder[wordCursor % wordOrder.count]
            wordCursor += 1
            if ok(w) { return MoveCard(id: nextCardId, word: w, dealtAt: clock, rank: rank(for: w)) }
        }
        // 兜底：随便找一个首字母不冲突的
        let w = bank.plainWords.first(where: { !taken.contains($0.firstLetter) }) ?? bank.plainWords[0]
        return MoveCard(id: nextCardId, word: w, dealtAt: clock, rank: rank(for: w))
    }
}
