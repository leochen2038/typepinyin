import Testing
@testable import LearningCore

/// 一个词只归一关（2026-11-09）：词归它里面最后才学到的那一卷；第 k 关只出归前 k 关的词，主题牌都归这一关。
@Suite struct CurriculumTests {
    let c = TestContent.shared

    @Test func everyWordHasOneLevel() {
        #expect(c.owner.count == c.words.count)
        #expect(c.ownedCount.values.reduce(0, +) == c.words.count)
        #expect(c.regions.map(\.volume) == ["base", "biyin-shang", "biyin-xia", "liangzi-shang", "liangzi-xia",
                                            "yw", "lv", "shengzi", "sanpin-shang", "sanpin-xia"])
        for (w, v) in zip(c.words, c.owner) {
            let k = c.level(of: v)!
            #expect(w.syllables.allSatisfy { (c.level(of: c.volume(of: $0)) ?? 99) <= k }, "\(w.text)")
            #expect(w.syllables.contains { c.volume(of: $0) == v }, "\(w.text)")
        }
    }

    /// 武林大会：每位掌门都有下台的话，妙笔书生有四句丢命的话。
    @Test func gatheringHasEveryMaster() throws {
        let g = try #require(c.gathering)
        for r in c.regions { #expect(!(g.praise[r.id] ?? "").isEmpty, "\(r.name)") }
        #expect((g.boss.lifeLines ?? []).count >= 4)
        #expect(g.stele.syllables.count == g.stele.text.filter { $0.isLetter }.count)
    }

    /// 每座岛的地名都在这一关或更早学过。
    @Test func regionNamesAreLearnedBy() {
        for r in c.regions {
            let k = c.level(of: r.volume)!
            for s in r.pinyin.split(separator: " ").map(String.init) {
                #expect((c.level(of: c.volume(of: s)) ?? 99) <= k, "\(r.name) \(s)")
            }
        }
    }

    func learner(knowingUpTo v: String) -> Learner {
        var l = Learner()
        let k = c.level(of: v)!
        for r in c.regions.prefix(k) {
            for s in c.syllables(in: r.volume) {
                var rec = SyllableRecord(spelling: s.spelling)
                rec.proficiency = .fluent
                rec.correct = 3
                rec.nextReview = 3
                l.records[s.spelling] = rec
            }
        }
        return l
    }

    /// 每座岛走一趟：牌只用这一关和前面的音节；八成左右是这一关的词。
    @Test(arguments: TestContent.shared.regions.map(\.volume)) func dealsOnlyUpToThisLevel(_ v: String) {
        let allowed = c.syllables(upTo: v)
        let focus: Set<String>? = v == "base" ? Set(c.syllables(in: "base").map(\.spelling).filter { $0.count >= 3 }) : nil
        var own = 0, total = 0
        for seed in 1...10 as ClosedRange<UInt64> {
            let d = Dealer(content: c, learner: learner(knowingUpTo: v),
                           context: DealContext(volume: v, today: 5, lengths: [2: 0.85, 3: 0.15], allowedSyllables: allowed, focus: focus),
                           seed: seed)
            for _ in 0..<20 {
                let w = d.next()
                total += 1
                #expect(w.word.syllables.allSatisfy(allowed.contains), "\(v) \(w.word.text)")
                if c.owner(of: w.word.syllables) == v { own += 1 }
                d.note(w.word, clean: true)
            }
            #expect(d.nextIdiom().syllables.allSatisfy(allowed.contains), "\(v) 必杀")
        }
        #expect(Double(own) / Double(total) >= 0.7, "\(v) 归这一关的牌只占 \(own) / \(total)")
    }

    /// 葫芦集的主题牌都带一个三个字母的音节（zh ch sh 这类），不全是两个字母。
    @Test func firstLevelThemeCardsHaveLongSyllables() {
        let focus = Set(c.syllables(in: "base").map(\.spelling).filter { $0.count >= 3 })
        for seed in 1...10 as ClosedRange<UInt64> {
            let d = Dealer(content: c, learner: Learner(),
                           context: DealContext(volume: "base", today: 5, lengths: [2: 0.85, 3: 0.15],
                                                allowedSyllables: c.syllables(upTo: "base"), focus: focus),
                           seed: seed)
            for _ in 0..<20 {
                let w = d.next()
                if w.reason == .knownInVolume { #expect(w.word.syllables.contains { $0.count >= 3 }, "\(w.word.text)") }
                d.note(w.word, clean: true)
            }
        }
    }
}
