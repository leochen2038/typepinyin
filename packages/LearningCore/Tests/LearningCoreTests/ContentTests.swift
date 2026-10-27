import Foundation
import Testing
@testable import LearningCore

@Suite struct ContentTests {
    @Test func loadsAllSyllables() {
        let c = TestContent.shared
        #expect(c.syllables.count == 401)        // 3500 个常用字的规范读音
        #expect(c.commonChars.count == 3500)
        #expect(c.regions.count == 10)
        #expect(c.places.count == 2)
    }

    /// 和生成脚本导出的对照表完全一致。
    @Test func classifyMatchesGenerator() throws {
        let table = try JSONDecoder().decode([String: String].self, from: TestContent.fixture("volumes.json"))
        #expect(table.count == 401)
        for (s, v) in table { #expect(Volumes.classify(s) == v, "\(s)") }
    }

    /// 诗文里的少见读音也能归卷。
    @Test func unknownSpellingsStillClassify() {
        let c = TestContent.shared
        #expect(c.volume(of: "nou") == "liangzi-xia")
        #expect(c.volume(of: "dia") == "sanpin-shang")
        #expect(c.volume(of: "yue") == "yw")
    }

    @Test func wordsIndexedBySyllableInFrequencyOrder() {
        let c = TestContent.shared
        let idx = c.wordsBySyllable["shan"] ?? []
        #expect(idx.count >= 4)
        let freqs = idx.map { c.words[$0].freq }
        #expect(freqs == freqs.sorted())
    }
}
