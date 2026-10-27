import Testing
@testable import LearningCore

/// 初入江湖的梦：只从专门挑的词里出牌，必杀也从里面的四字词出。
@Suite struct DreamTests {
    let c = TestContent.shared

    @Test func dreamWordsAreEasy() throws {
        let d = try #require(c.dream)
        #expect(d.words.count >= 60)
        for w in d.words {
            for s in w.syllables {
                // 没有 ü、省写 iu ui un、三拼的介音，拼音不长
                #expect(!["lv", "shengzi", "sanpin-shang", "sanpin-xia"].contains(Volumes.classifyBySpelling(s)), "\(w.text) \(s)")
                #expect(s.count <= 4, "\(w.text) \(s)")
            }
        }
    }

    @Test func dealsOnlyFromThePool() throws {
        let d0 = try #require(c.dream)
        let pool = Set(d0.words.map(\.text))
        let d = Dealer(content: c, learner: Learner(), probe: ProbeState(),
                       context: DealContext(volume: nil, today: 1, lengths: [2: 0.7, 3: 0.3], pool: d0.words), seed: 2)
        for _ in 0..<40 {
            let w = d.next()
            #expect(pool.contains(w.word.text))
            d.note(w.word, clean: true)
        }
        let f = d.nextIdiom()
        #expect(pool.contains(f.text) && f.text.count == 4)
    }

    /// 教学：第一张牌固定是「江湖」，后面照常从词池里出。
    @Test func tutorialWordComesFirst() throws {
        let d0 = try #require(c.dream)
        let t = try #require(d0.tutorial)
        #expect(t.text == "江湖")
        let d = Dealer(content: c, learner: Learner(), probe: ProbeState(),
                       context: DealContext(volume: nil, today: 1, pool: d0.words, firstWord: t), seed: 3)
        #expect(d.next().word.text == "江湖")
        #expect(d.next().word.text != "江湖")
    }
}
