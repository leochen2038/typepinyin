import Testing
@testable import LearningCore

/// 第一关减负：基本功只有 30 个核心音节。
@Suite struct LightStartTests {
    let c = TestContent.shared

    /// 第一关只有 30 个核心音节；其余的基本功音节按韵母挂到两字诀、省字诀。
    @Test func baseIsTheThirtyCoreSyllables() {
        #expect(Set(c.syllables(in: "base").map(\.spelling)) == Volumes.baseCore)
        #expect(Volumes.classify("ma") == "liangzi-shang")
        #expect(Volumes.classify("zhe") == "liangzi-shang")
        #expect(Volumes.classify("shu") == "liangzi-xia")
        #expect(Volumes.classify("bo") == "liangzi-xia")
        #expect(Volumes.classify("shi") == "shengzi")
        #expect(Volumes.classify("bai") == "liangzi-shang")
    }
}
