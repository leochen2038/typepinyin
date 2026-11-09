import LearningCore
import SwiftUI

/// 真机上测长卷（开发用，启动参数 -scrollPerf）：先量画图、存图、读图各花多久，再自动上下拖 18 秒记帧间隔和内存，
/// 结果写到 Documents/scroll-perf.txt。只显示长卷，不读不写玩家进度。
struct ScrollPerfView: View {
    private let region: Region?
    private let route: Route?
    @State private var probe = ScrollPerfProbe()

    init(content: LearningContent) {
        let r = content.regions.first { $0.id == "banshanzhen" }
        region = r
        route = r.map { RoutePlanner.plan(region: $0, content: content, seed: 1) }
    }

    var body: some View {
        GeometryReader { geo in
            if let region, let route, let scene = RegionScenes.scene(for: region.id), probe.ready {
                RegionScrollView(region: region, route: route, cleared: 0, hero: 0, width: geo.size.width, scene: scene)
                    .offset(y: -probe.y)
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                    .clipped()
            } else {
                Text("测长卷中").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { probe.start(viewH: UIScreen.main.bounds.height) }
    }
}

@MainActor @Observable
final class ScrollPerfProbe: NSObject {
    var y: CGFloat = 0
    var ready = false
    private var report = ""
    private var viewH: CGFloat = 0
    private var link: CADisplayLink?
    private var startedAt: CFTimeInterval = 0
    private var last: CFTimeInterval = 0
    private var intervals: [Double] = []
    private var late = 0
    private var expected = 0.0
    private var peak = 0.0
    private var startPeak = 0.0
    private var sampler: Timer?

    func start(viewH: CGFloat) {
        guard link == nil, !ready else { return }
        self.viewH = viewH
        report = "启动时内存 \(String(format: "%.0f", Self.footprint())) MB\n"
        sampler = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.startPeak = max(self?.startPeak ?? 0, Self.footprint()) } }   // 从一开始就记，首次预画也算进去
        // 装完第一次打开的情况：缓存清空，十片地区从零预画一遍
        SceneImages.clearDiskCache()
        SceneRenderer.prewarm(regionIds: ["huluji", "baimeitai", "chaotoudao", "yueyawan", "chuiliucun", "lvquanju", "banshanzhen", "changfengcheng", "xiaoqiaoxiang", "huanghuaguan"], width: UIScreen.main.bounds.width)
        Task.detached(priority: .userInitiated) {
            let text = ScrollPerfProbe.measureStill()
            await MainActor.run { self.beginScrolling(text) }
        }
    }

    /// 在场景图的队列上量：矢量图画一次、旧画法画一次、存 PNG、读 PNG 解码。
    nonisolated private static func measureStill() -> String {
        guard let scene = RegionScenes.scene(for: "banshanzhen") else { return "" }
        var out = ""
        func ms(_ name: String, _ body: () -> Void) {
            let t = CACurrentMediaTime()
            body()
            out += String(format: "%@ %.0f ms\n", name, (CACurrentMediaTime() - t) * 1000)
        }
        SceneImages.queue.sync {
            let theme = RegionTheme.of("banshanzhen")
            var art: UIImage?
            for run in 1...3 { ms("矢量图画一次（第 \(run) 次）") { art = SceneImages.renderScroll(regionId: "banshanzhen", scene: scene, theme: theme, width: 393) } }
            var old = scene
            old.scrollAsset = nil
            ms("旧画法画一次") { _ = SceneImages.renderScroll(regionId: "banshanzhen", scene: old, theme: theme, width: 393) }
            var data: Data?
            ms("存成 PNG") { data = art?.pngData() }
            out += String(format: "PNG 大小 %.1f MB\n", Double(data?.count ?? 0) / 1e6)
            ms("读 PNG 并解码") { _ = data.flatMap { UIImage(data: $0, scale: 2)?.preparingForDisplay() } }
            var duel: UIImage?
            for run in 1...2 { ms("比武背景画一次（第 \(run) 次）") { duel = SceneImages.renderDuel(scene: scene, theme: theme) } }
            var duelData: Data?
            ms("比武背景存成 PNG") { duelData = duel?.pngData() }
            out += String(format: "比武背景 PNG 大小 %.1f MB\n", Double(duelData?.count ?? 0) / 1e6)
            ms("比武背景读取并缩放到屏幕") {
                guard let img = duelData.flatMap({ UIImage(data: $0, scale: 3) }) else { return }
                let size = CGSize(width: 393, height: 325)
                let format = UIGraphicsImageRendererFormat()
                format.opaque = true
                let k = size.height / img.size.height
                _ = UIGraphicsImageRenderer(size: size, format: format).image { _ in img.draw(in: CGRect(x: 0, y: 0, width: img.size.width * k, height: size.height)) }
            }
        }
        return out
    }

    private func beginScrolling(_ text: String) {
        report += text
        for (id, count) in [("huluji", 6), ("baimeitai", 10), ("chaotoudao", 10), ("yueyawan", 10), ("chuiliucun", 10), ("lvquanju", 10), ("banshanzhen", 10), ("changfengcheng", 10), ("xiaoqiaoxiang", 10), ("huanghuaguan", 10)] {
            guard let scene = RegionScenes.scene(for: id) else { continue }     // 这么多站时，每一站用第几张比武背景、取景在哪
            let shots = (0..<count).map { i -> String in
                let s = SceneRenderer.duelShot(station: i, count: count, scene: scene)
                return String(format: "%d(%.2f)", s.segment + 1, s.pan)
            }
            report += "\(id) \(count) 站：" + shots.joined(separator: " ") + "\n"
        }
        ready = true
        startedAt = CACurrentMediaTime()
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    @objc private func tick(_ l: CADisplayLink) {
        expected = l.targetTimestamp - l.timestamp
        if last > 0 {
            let d = l.timestamp - last
            intervals.append(d)
            if d > expected * 1.5 { late += 1 }
        }
        last = l.timestamp
        let t = l.timestamp - startedAt
        if t < 1 { return }                                        // 第一秒是长卷第一次显示，单独算
        if t >= 19 { finish(); return }
        let range = RegionScrollView.height - viewH
        let phase = ((t - 1) / 6).truncatingRemainder(dividingBy: 2)   // 6 秒拖完一趟，来回三趟
        y = range * (phase < 1 ? phase : 2 - phase)
        peak = max(peak, Self.footprint())
    }

    private func finish() {
        link?.invalidate()
        let sorted = intervals.sorted()
        let first = intervals.prefix(20).max() ?? 0
        report += String(format: "刷新间隔 %.1f ms\n拖动 %d 帧，掉帧 %d（%.1f%%），平均 %.1f ms，最长 %.1f ms\n长卷刚显示时最长一帧 %.1f ms\n内存峰值 %.0f MB\n",
                         expected * 1000, intervals.count, late, Double(late) / Double(max(1, intervals.count)) * 100,
                         sorted.reduce(0, +) / Double(max(1, sorted.count)) * 1000, (sorted.last ?? 0) * 1000, first * 1000, peak)
        sampler?.invalidate()
        report += String(format: "从启动起内存峰值 %.0f MB\n预画全部图 %.1f 秒\n", startPeak, SceneImages.prewarmSeconds ?? -1)
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("scroll-perf.txt")
        try? report.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func footprint() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let r = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
        }
        return r == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
    }
}
