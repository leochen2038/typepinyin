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

    /// 每个人物的外形取值都在允许的范围里（没写的为空，用默认）。
    @Test func looksUseKnownValues() {
        let c = TestContent.shared
        let values: [KeyPath<Look, String?>: Set<String>] = [
            \.build: ["slim", "normal", "burly"],
            \.weapon: ["sword", "saber", "hammer", "pole", "staff", "spear", "fan", "qin", "brush", "fists"],
            \.face: ["plain", "mustache", "beard", "old"],
        ]
        let hats: Set<String> = ["none", "band", "conical", "topknot", "bun", "scholar", "helmet", "opera"]
        var cast = c.regions.flatMap { [$0.boss] + $0.foes } + c.places.flatMap { $0.foes ?? [] }
        if let d = c.dream { cast.append(d.boss) }
        #expect(cast.count >= 30)
        for f in cast {
            #expect(hats.contains(f.look.hat), "\(f.name) 的 hat")
            for (k, ok) in values { if let v = f.look[keyPath: k] { #expect(ok.contains(v), "\(f.name) 的 \(v)") } }
            if let b = f.look.back { #expect(b == "flag", "\(f.name) 的 back") }
        }
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
