import QuartzCore

/// 按键延迟：记录手指按下的时刻，在下一次画面刷新时取「这一帧预计显示的时间」求差，保留最近 50 次。
@MainActor
final class LatencyMeter {
    private var pending: [TimeInterval] = []
    private(set) var samples: [Double] = []
    private var lastFrame: CFTimeInterval = 0
    private(set) var fps: Double = 0

    func touchDown(_ t: TimeInterval) { pending.append(t) }

    /// 每帧调用：`target` 是 CADisplayLink.targetTimestamp。
    func frame(target: CFTimeInterval, timestamp: CFTimeInterval) {
        if lastFrame > 0 {
            let dt = timestamp - lastFrame
            if dt > 0 { fps = fps == 0 ? 1 / dt : 0.9 * fps + 0.1 / dt }
        }
        lastFrame = timestamp
        guard !pending.isEmpty else { return }
        for t in pending { samples.append(max(0, target - t) * 1000) }
        pending.removeAll()
        if samples.count > 50 { samples.removeFirst(samples.count - 50) }
    }

    var averageMs: Double { samples.isEmpty ? 0 : samples.reduce(0, +) / Double(samples.count) }
    var worstMs: Double { samples.max() ?? 0 }

    func reset() { samples.removeAll(); pending.removeAll() }
}
