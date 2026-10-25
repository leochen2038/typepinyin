import Foundation

/// 片段里的学习状态：哪些音节已学会、这一场打错几次、拆过哪些、哪些要复现。
public struct LearnerState: Sendable, Equatable {
    public var learned: Set<String>
    public var missCount: [String: Int] = [:]
    public var taught: Set<String> = []
    /// 待复现：(第几张补牌, 音节)。补牌计数从开打后的第一张补牌算起。
    public var replayQueue: [(deal: Int, syllable: String)] = []

    public init(learned: Set<String>) { self.learned = learned }

    /// 不在 learned 且不在 taught → 没学过。
    public func isNew(_ s: String) -> Bool { !learned.contains(s) && !taught.contains(s) }

    public static func == (a: LearnerState, b: LearnerState) -> Bool {
        a.learned == b.learned && a.missCount == b.missCount && a.taught == b.taught
            && a.replayQueue.map(\.deal) == b.replayQueue.map(\.deal)
            && a.replayQueue.map(\.syllable) == b.replayQueue.map(\.syllable)
    }

    /// 等着复现的音节（不管第几张）。
    public var pendingReplay: Set<String> { Set(replayQueue.map(\.syllable)) }
}
