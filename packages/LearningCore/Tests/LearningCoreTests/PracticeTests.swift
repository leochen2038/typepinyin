import Testing
@testable import LearningCore

/// 练功房：只出打过的词，打得不顺、常打错的多出，练熟的少出但还会出；可以重复穿插。
@Suite struct PracticeTests {
    let c = TestContent.shared

    func word(_ text: String, _ sy: [String], clean: [Bool], spl: Double) -> PracticeWord {
        var w = PracticeWord(text: text, syllables: sy, volume: "base")
        for (k, ok) in clean.enumerated() { w.note(clean: ok, secondsPerLetter: spl, at: Double(k)) }
        return w
    }

    @Test func weakWordsWeighMoreButFamiliarStillAppear() {
        let familiar = word("地图", ["di", "tu"], clean: [true, true, true, true, true], spl: 0.3)
        let shaky = word("比如", ["bi", "ru"], clean: [true, false, false, true, false], spl: 0.6)
        let slow = word("大地", ["da", "di"], clean: [true, true, true, true, true], spl: 0.9)
        let wf = PracticeWeights.weight(familiar, typical: 0.4)
        #expect(PracticeWeights.weight(shaky, typical: 0.4) > wf * 3)
        #expect(PracticeWeights.weight(slow, typical: 0.4) > wf * 2)
        #expect(wf >= PracticeWeights.floor)
    }

    @Test func dealsOnlyFromThePoolByWeight() {
        let shaky = word("比如", ["bi", "ru"], clean: [false, false, true, false, false], spl: 0.8)
        let familiar = [("地图", ["di", "tu"]), ("大地", ["da", "di"]), ("可以", ["ke", "yi"]), ("他的", ["ta", "de"]),
                        ("哥哥", ["ge", "ge"]), ("西瓜", ["xi", "gua"])].map { word($0.0, $0.1, clean: Array(repeating: true, count: 5), spl: 0.3) }
        let words = [shaky] + familiar
        let dealer = Dealer(content: c, learner: Learner(tuning: LearningTuning()), probe: ProbeState(),
                            context: DealContext(volume: nil, today: 0, probeLimit: 0, pool: words.map(\.asContentWord),
                                                 weights: PracticeWeights.weights(words, typical: 0.4)),
                            seed: 7)
        var count: [String: Int] = [:]
        var last = ""
        var repeatsBackToBack = 0
        for _ in 0..<1400 {
            let t = dealer.next().word.text
            if t == last { repeatsBackToBack += 1 }
            last = t
            count[t, default: 0] += 1
        }
        #expect(Set(count.keys) == Set(words.map(\.text)))                 // 只出打过的词，熟的也会出
        for f in familiar { #expect(count["比如", default: 0] > count[f.text, default: 0] * 3, "\(f.text)") }
        #expect(repeatsBackToBack == 0)                                     // 重复是穿插着来，不连着出同一张
    }
}
