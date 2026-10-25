import Foundation
import QuartzCore

/// 手机上的性能记录（-perflog 启动参数打开）：统计掉帧和主线程上各部分花的时间，每 5 秒写一份到 Documents/perf.txt。
/// 用来在真机上找卡顿原因（远程用 Instruments 录不稳）。平时不开，不影响游戏。
@MainActor
enum PerfLog {
    static let on = ProcessInfo.processInfo.arguments.contains("-perflog")

    private struct Stat { var n = 0; var total = 0.0; var worst = 0.0 }
    private static var stats: [String: Stat] = [:]
    private static var frames: [Bool: (n: Int, late: Int, worst: Double, sum: Double)] = [:]
    private static var lastFrame: CFTimeInterval = 0
    private static var lastWrite: CFTimeInterval = 0
    private static let started = CACurrentMediaTime()

    /// 量一段代码在主线程上花了多久。
    static func measure<T>(_ name: String, _ body: () -> T) -> T {
        guard on else { return body() }
        let t0 = CACurrentMediaTime()
        let r = body()
        let d = CACurrentMediaTime() - t0
        var s = stats[name, default: Stat()]
        s.n += 1; s.total += d; s.worst = max(s.worst, d)
        stats[name] = s
        return r
    }

    /// 每帧调一次：记下和上一帧隔了多久（超过预期 1.5 倍算掉帧），分「回顾中」和「平时」。
    static func frame(at t: CFTimeInterval, expected: Double, inReview: Bool) {
        guard on else { return }
        if lastFrame > 0 {
            let d = t - lastFrame
            var f = frames[inReview] ?? (0, 0, 0, 0)
            f.n += 1; f.sum += d; f.worst = max(f.worst, d)
            if d > expected * 1.5 { f.late += 1 }
            frames[inReview] = f
        }
        lastFrame = t
        if t - lastWrite > 5 { lastWrite = t; write() }
    }

    private static func write() {
        var out = String(format: "运行 %.0f 秒\n", CACurrentMediaTime() - started)
        for (k, f) in frames.sorted(by: { !$0.key && $1.key }) {
            out += String(format: "%@：%d 帧，掉帧 %d（%.1f%%），平均 %.1f ms，最长 %.1f ms\n",
                          k ? "回顾中" : "平时", f.n, f.late, Double(f.late) / Double(max(1, f.n)) * 100,
                          f.sum / Double(max(1, f.n)) * 1000, f.worst * 1000)
        }
        out += "主线程耗时（次数 / 合计 ms / 平均 ms / 最长 ms）：\n"
        for (name, s) in stats.sorted(by: { $0.value.total > $1.value.total }) {
            out += String(format: "  %@：%d / %.0f / %.2f / %.1f\n", name, s.n, s.total * 1000, s.total / Double(max(1, s.n)) * 1000, s.worst * 1000)
        }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("perf.txt")
        try? out.write(to: url, atomically: true, encoding: .utf8)
    }
}
