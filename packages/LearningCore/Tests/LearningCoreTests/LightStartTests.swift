import Testing
@testable import LearningCore

/// 按韵母分卷（2026-11-09）：基本功是声母加一个韵母 a o e i u（含 zh ch sh），两字诀只剩 ai ei / ao ou，省字诀只剩 iu ui un。
/// 原来的分卷（调参「课程」选「原来」）：基本功只有 30 个核心音节，其余按韵母挂到两字诀、省字诀。
@Suite struct LightStartTests {
    let c = TestContent.shared

    @Test func baseIsEverySingleFinal() {
        let base = Set(c.syllables(in: "base").map(\.spelling))
        #expect(Volumes.baseCore.isSubset(of: base))
        for s in ["ma", "zhe", "shu", "bo", "shi", "zhi", "ri", "mi"] {
            #expect(base.contains(s), "\(s)")
            #expect(Volumes.classify(s) == "base", "\(s)")
        }
        #expect(Volumes.classify("bai") == "liangzi-shang")
        #expect(Volumes.classify("zhou") == "liangzi-xia")
        #expect(Volumes.classify("shui") == "shengzi")
        #expect(c.syllables(in: "liangzi-shang").allSatisfy { $0.spelling.hasSuffix("ai") || $0.spelling.hasSuffix("ei") })
        #expect(c.syllables(in: "liangzi-xia").allSatisfy { $0.spelling.hasSuffix("ao") || $0.spelling.hasSuffix("ou") })
    }

    @Test func legacyIsTheThirtyCoreSyllables() {
        let old = c.legacyCurriculum()
        #expect(Set(old.syllables.filter { $0.volume == "base" }.map(\.spelling)) == Volumes.baseCore)
        #expect(old.regions.map(\.volume) == Volumes.legacyRegionOrder)
        #expect(Volumes.classifyLegacy("ma") == "liangzi-shang")
        #expect(Volumes.classifyLegacy("zhe") == "liangzi-shang")
        #expect(Volumes.classifyLegacy("shu") == "liangzi-xia")
        #expect(Volumes.classifyLegacy("bo") == "liangzi-xia")
        #expect(Volumes.classifyLegacy("shi") == "shengzi")
        #expect(Volumes.classifyLegacy("bai") == "liangzi-shang")
    }
}
