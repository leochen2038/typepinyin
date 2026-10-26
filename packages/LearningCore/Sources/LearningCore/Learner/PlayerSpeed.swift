import Foundation

/// 手速（按设备）：每个字母的平均用时、平均上手时间。每场结束滑动更新一次。
public struct PlayerSpeed: Codable, Sendable, Equatable {
    public var secondsPerLetter: Double
    public var startSeconds: Double
    public var samples: Int

    public init(secondsPerLetter: Double, startSeconds: Double, samples: Int) {
        self.secondsPerLetter = secondsPerLetter
        self.startSeconds = startSeconds
        self.samples = samples
    }

    /// 没有记录时直接用这一场的；否则按权重往这一场的方向挪一点。
    public static func updated(_ old: PlayerSpeed?, secondsPerLetter: Double, startSeconds: Double, weight: Double) -> PlayerSpeed {
        guard let o = old else { return PlayerSpeed(secondsPerLetter: secondsPerLetter, startSeconds: startSeconds, samples: 1) }
        return PlayerSpeed(secondsPerLetter: o.secondsPerLetter * (1 - weight) + secondsPerLetter * weight,
                           startSeconds: o.startSeconds * (1 - weight) + startSeconds * weight,
                           samples: o.samples + 1)
    }
}
