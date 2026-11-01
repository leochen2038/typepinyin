import Testing
@testable import LearningCore

/// 词卡：第一次打完就收；累计 2 场打对熟练、4 场精通；重数按词卡算（音节是桥梁）；
/// 地区里挑词时没收过的优先、复现先出拼错的原词、第一次就又快又对的新音节退回名额。
@Suite struct CardTests {
    let c = TestContent.shared

    func card(_ text: String, duels: Int) -> PracticeWord {
        let w = c.words.first { $0.text == text } ?? c.words[0]
        return PracticeWord(text: w.text, syllables: w.syllables, volume: w.volume, seen: duels, clean: duels, cleanDuels: duels)
    }

    @Test func levelsByCleanDuels() {
        let t = LearningTuning()
        #expect(card("朋友", duels: 0).level(t) == .met)
        #expect(card("朋友", duels: 1).level(t) == .met)
        #expect(card("朋友", duels: 2).level(t) == .fluent)
        #expect(card("朋友", duels: 4).level(t) == .master)
    }

    /// 每个音节都有一张熟练的词卡 → 三重；一半精通 → 四重。
    @Test func rankFollowsSyllableCoverage() {
        let vol = "base"
        let syl = CardRank.syllables(in: vol, content: c)
        func cards(_ duels: Int, upTo n: Int) -> [PracticeWord] {
            syl.prefix(n).compactMap { s in c.wordsBySyllable[s]?.first.map { c.words[$0] } }
                .map { PracticeWord(text: $0.text, syllables: $0.syllables, volume: $0.volume, cleanDuels: duels) }
        }
        let t = LearningTuning()
        func rank(_ cs: [PracticeWord]) -> Int {
            CardRank.rank(of: vol, obtained: true, previous: 0, best: CardRank.best(cs, tuning: t), content: c)
        }
        #expect(rank([]) == 1)
        #expect(rank(cards(1, upTo: syl.count)) == 1)          // 都只见过
        #expect(rank(cards(2, upTo: syl.count)) == 3)          // 都熟练
        #expect(rank(cards(4, upTo: syl.count)) == 5)          // 都精通
        #expect(CardRank.rank(of: vol, obtained: false, previous: 0, best: [:], content: c) == 0)
    }

    /// 没收过的词优先：收过的词全不出现在前几张里的概率很高；全收过时照样能出牌。
    @Test func freshWordsPreferred() {
        var l = Learner()
        for s in c.syllables(in: "base") { var r = SyllableRecord(spelling: s.spelling); r.proficiency = .fluent; l.records[s.spelling] = r }
        let common = Set(c.words.filter { !$0.isIdiom && $0.syllables.allSatisfy { c.volume(of: $0) == "base" } }.prefix(40).map(\.text))
        var fresh = 0, total = 0
        for seed in 1...8 as ClosedRange<UInt64> {
            let d = Dealer(content: c, learner: l, context: DealContext(volume: "base", today: 1, collected: common), seed: seed)
            for _ in 0..<10 { let w = d.next(); total += 1; if !common.contains(w.word.text) { fresh += 1 }; d.note(w.word, clean: true) }
        }
        #expect(Double(fresh) / Double(total) > 0.5, "\(fresh)/\(total)")
    }

    @Test func replayDealsTheMissedWord() {
        var l = Learner()
        for s in c.syllables(in: "base") { var r = SyllableRecord(spelling: s.spelling); r.proficiency = .fluent; l.records[s.spelling] = r }
        let target = c.words.first { !$0.isIdiom && $0.text.count == 2 && $0.syllables.allSatisfy { c.volume(of: $0) == "base" } }!
        let d = Dealer(content: c, learner: l, context: DealContext(volume: "base", today: 1), seed: 2)
        _ = d.next()
        d.newMove(target.syllables[0], word: target.text)
        var texts: [String] = []
        for _ in 0..<6 { let w = d.next(); texts.append(w.word.text); d.note(w.word, clean: true) }
        #expect(texts.contains(target.text), "\(texts)")
    }

    @Test func fastCleanNewSyllableFreesTheSlot() {
        let d = Dealer(content: c, learner: Learner(), context: DealContext(volume: "biyin-shang", today: 1), seed: 4)
        var freed = false
        for _ in 0..<20 {
            let w = d.next()
            let before = d.newThisDuel
            d.note(w.word, clean: true, secondsPerLetter: 0.3)
            if !w.newSyllables.isEmpty { #expect(d.newThisDuel < before); freed = true }
        }
        #expect(freed)
    }
}
