import Foundation

extension Learner {
    /// 一卷的重数：没拿到是零重；拿到至少一重；再按这一卷常用音节的熟练度往上升。只升不降（结果 ≥ previous）。
    public func rank(of volume: String, obtained: Bool, previous: Int, content: LearningContent) -> Int {
        guard obtained else { return previous }
        let common = content.rankSyllables(in: volume, tuning: tuning).map(\.spelling)
        guard !common.isEmpty else { return max(previous, 1) }
        let n = Double(common.count)
        let fluent = Double(common.filter { proficiency($0) >= .fluent }.count)
        let master = Double(common.filter { proficiency($0) == .master }.count)
        var r = 1
        if fluent >= n / 2 { r = 2 }
        if fluent >= n { r = 3 }
        if master >= n / 2 { r = 4 }
        if master >= n { r = 5 }
        return max(previous, r)
    }

    /// 离下一重有多远（0…1），顶栏的进度环用。
    public func rankProgress(of volume: String, rank: Int, content: LearningContent) -> Double {
        let common = content.rankSyllables(in: volume, tuning: tuning).map(\.spelling)
        guard rank >= 1, rank < 5, !common.isEmpty else { return rank >= 5 ? 1 : 0 }
        let n = Double(common.count)
        let fluent = Double(common.filter { proficiency($0) >= .fluent }.count)
        let master = Double(common.filter { proficiency($0) == .master }.count)
        let (have, need): (Double, Double)
        switch rank {
        case 1: (have, need) = (fluent, n / 2)
        case 2: (have, need) = (fluent - n / 2, n / 2)
        case 3: (have, need) = (master, n / 2)
        default: (have, need) = (master - n / 2, n / 2)
        }
        return min(1, max(0, have / max(1, need)))
    }
}
