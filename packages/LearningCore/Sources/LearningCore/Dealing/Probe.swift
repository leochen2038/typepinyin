import Foundation

/// 杠杆：一族里还不熟练的常用音节，补上之后能多打出多少个常用字。
public enum Probe {
    public static func leverage(of family: String, learner: Learner, content: LearningContent) -> Int {
        content.commonSyllables(in: family)
            .filter { learner.proficiency($0.spelling) < .fluent }
            .reduce(0) { $0 + $1.commonChars.count }
    }

    /// 杠杆最大的几族（基本功不探：大多数人已经会）。
    public static func families(learner: Learner, content: LearningContent, count: Int) -> [String] {
        var scored: [(family: String, lev: Int)] = []
        for f in Volumes.all where f != "base" {
            scored.append((f, leverage(of: f, learner: learner, content: content)))
        }
        scored.sort { a, b in a.lev != b.lev ? a.lev > b.lev : a.family < b.family }
        return scored.prefix(count).map { $0.family }
    }
}

/// 渐进摸底的进度：每族探过哪些、错了几个、是不是重点。
public struct ProbeState: Codable, Sendable, Equatable {
    public struct Family: Codable, Sendable, Equatable {
        public var probed: [String] = []
        public var missed = 0
        public var focus = false
    }

    public var families: [String: Family] = [:]

    public init() {}

    /// 接下来要探的音节：杠杆最大的几族里，对应常用字最多、还没碰过也没探过的代表；重点族多探几个。
    public func candidates(learner: Learner, content: LearningContent, tuning: LearningTuning) -> [String] {
        var out: [String] = []
        for fam in Probe.families(learner: learner, content: content, count: tuning.probeFamilies) {
            let f = families[fam] ?? Family()
            let quota = tuning.probePerFamily + (f.focus ? tuning.probeFocusExtra : 0) - f.probed.count
            guard quota > 0 else { continue }
            let reps = content.commonSyllables(in: fam)
                .sorted { $0.commonChars.count != $1.commonChars.count ? $0.commonChars.count > $1.commonChars.count : $0.spelling < $1.spelling }
                .map(\.spelling)
                .filter { learner.proficiency($0) == .locked && !f.probed.contains($0) }
            out += reps.prefix(quota)
        }
        return out
    }

    /// 探了一个音节：记下来；一族错到门槛就记为重点。
    public mutating func note(_ spelling: String, correct: Bool, content: LearningContent, tuning: LearningTuning = LearningTuning()) {
        let fam = content.volume(of: spelling)
        var f = families[fam] ?? Family()
        if !f.probed.contains(spelling) { f.probed.append(spelling) }
        if !correct { f.missed += 1 }
        if f.missed >= tuning.probeFocusMisses { f.focus = true }
        families[fam] = f
    }
}
