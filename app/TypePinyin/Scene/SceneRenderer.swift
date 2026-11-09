import UIKit

/// 地区场景：路的几何（站点、走路的位置）在这里；画图片交给 SceneImages（后台画、存磁盘）。
@MainActor
enum SceneRenderer {
    /// 长卷高度。站和站之间留长一点的路，看得到主角赶路（2026-11-01 从 1500 加长到 2600，
    /// 2026-11-02 收到 2250：第一站下面只留进场的一小段路和镜头需要的余量，不要一大段用不上的景）。
    nonisolated static let scrollHeight: CGFloat = 2250
    /// 矢量长卷的路和景物按这个宽度设计；整张图比它宽，两边用来适配不同屏幕。
    nonisolated static let scrollDesignWidth: CGFloat = 393
    /// 场景布局按 1500 高写；山顶（400 点以上）原样，往下按比例拉长到 scrollHeight。
    nonisolated static let designHeight: CGFloat = 1500, summit: CGFloat = 400
    nonisolated static func y(_ v: CGFloat) -> CGFloat {
        v <= summit ? v : summit + (v - summit) * (scrollHeight - summit) / (designHeight - summit)
    }
    /// 调试构建打出画一张图用了多久。
    nonisolated static func log(_ what: String, since t: CFTimeInterval) {
        #if DEBUG
        print(String(format: "[SceneRenderer] %@ %.0f ms", what, (CACurrentMediaTime() - t) * 1000))
        #endif
    }

    // MARK: 路

    private static var lineCache: [String: [CGPoint]] = [:]

    /// 路的控制点连成的平滑曲线上，均匀取很多点（Catmull-Rom），换成长卷坐标。走路时每一帧都要用，算一次存起来。
    static func roadPolyline(_ scene: RegionScene, width: CGFloat) -> [CGPoint] {
        let key = "\(Int(width))|\(scene.road)"
        if let hit = lineCache[key] { return hit }
        let line = makePolyline(scene, width: width)
        lineCache[key] = line
        return line
    }

    nonisolated static func makePolyline(_ scene: RegionScene, width: CGFloat) -> [CGPoint] {
        // 有矢量长卷时景物大小固定：路按设计宽度换算，再居中（宽屏多看到两边，窄屏裁掉两边）；旧画法按屏幕宽度比例
        let c = scene.road.map { p in
            CGPoint(x: scene.scrollAsset == nil ? p.x * width : p.x * scrollDesignWidth + (width - scrollDesignWidth) / 2, y: y(p.y))
        }
        guard c.count >= 2 else { return c }
        var out: [CGPoint] = []
        for i in 0..<(c.count - 1) {
            let p0 = c[max(0, i - 1)], p1 = c[i], p2 = c[i + 1], p3 = c[min(c.count - 1, i + 2)]
            for k in 0..<24 {
                let t = CGFloat(k) / 24, t2 = t * t, t3 = t2 * t
                func f(_ a: CGFloat, _ b: CGFloat, _ cc: CGFloat, _ d: CGFloat) -> CGFloat {
                    0.5 * (2 * b + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3)
                }
                out.append(CGPoint(x: f(p0.x, p1.x, p2.x, p3.x), y: f(p0.y, p1.y, p2.y, p3.y)))
            }
        }
        out.append(c[c.count - 1])
        return out
    }

    /// 路上按弧长取一点：s = 0 是山脚，1 是终点。
    static func point(on line: [CGPoint], at s: CGFloat) -> CGPoint {
        guard line.count >= 2 else { return line.first ?? .zero }
        var lens: [CGFloat] = [0]
        for i in 1..<line.count { lens.append(lens[i - 1] + hypot(line[i].x - line[i - 1].x, line[i].y - line[i - 1].y)) }
        let target = min(max(s, 0), 1) * lens[lens.count - 1]
        var i = 1
        while i < lens.count - 1 && lens[i] < target { i += 1 }
        let seg = max(0.0001, lens[i] - lens[i - 1])
        let f = (target - lens[i - 1]) / seg
        return CGPoint(x: line[i - 1].x + (line[i].x - line[i - 1].x) * f, y: line[i - 1].y + (line[i].y - line[i - 1].y) * f)
    }

    /// 第一站的高度（从顶往下的点数）：下面留一段路，进地区时主角从山脚走上来。
    static let firstStationY: CGFloat = scrollHeight - 350
    /// 进地区时主角出发的地方（第 -1 站）：第一站下面一小段路。
    static let startY: CGFloat = firstStationY + 120

    /// 第 i 站（可以是小数，走路用）在长卷上的位置：n 站沿路等距，第一站在路上刚过 firstStationY 的地方，最后一站在终点；
    /// -1 到 0 之间是从山脚走到第一站的那段路。
    static func station(_ i: Double, count: Int, scene: RegionScene, width: CGFloat) -> CGPoint {
        let line = roadPolyline(scene, width: width)
        let n = Double(max(1, count - 1))
        let first = arcFraction(line, aboveY: firstStationY)
        if i < 0 {
            let s0 = arcFraction(line, aboveY: startY)
            return point(on: line, at: s0 + (first - s0) * CGFloat(1 + max(i, -1)))
        }
        let s = first + (1 - first) * CGFloat(min(i, n) / n)
        return point(on: line, at: s)
    }

    /// 第 i 站（共 count 站）的比武背景：站在长卷的哪一段就用哪一张；同一段里的几站把取景左右拉开，每一战看到的不一样。
    /// pan 是取景位置（0 最左，1 最右）。最后一段的路上对手只用左半边，右边留给掌门站（duelBossX）。
    static func duelShot(station i: Int, count: Int, scene: RegionScene) -> (segment: Int, pan: CGFloat) {
        let segments = scene.duelSegments
        guard !segments.isEmpty else { return (0, CGFloat(min(i, 10)) / 10) }
        func segment(_ k: Int) -> Int {
            let y = station(Double(k), count: count, scene: scene, width: scrollDesignWidth).y
            return segments.firstIndex { y >= $0.minY } ?? segments.count - 1
        }
        let seg = i >= count - 1 ? segments.count - 1 : segment(i)            // 走到头的掌门站固定用最后一张
        let peers = (0..<max(0, count - 1)).filter { segment($0) == seg }     // 这一段路上的站，不算掌门
        guard let k = peers.firstIndex(of: i) else { return (seg, 0.5) }
        let t = peers.count > 1 ? CGFloat(k) / CGFloat(peers.count - 1) : 0.5
        return (seg, seg == segments.count - 1 ? t * 0.5 : t)
    }

    /// 沿路从山脚走，第一次走到 y ≤ limit 时走过了全长的几成。
    static func arcFraction(_ line: [CGPoint], aboveY limit: CGFloat) -> CGFloat {
        guard line.count >= 2 else { return 0 }
        var total: CGFloat = 0
        var hit: CGFloat?
        for i in 1..<line.count {
            let seg = hypot(line[i].x - line[i - 1].x, line[i].y - line[i - 1].y)
            if hit == nil, line[i].y <= limit { hit = total + seg }
            total += seg
        }
        return min(0.9, (hit ?? 0) / max(1, total))
    }

    // MARK: 图片

    /// 主线程上留一份最近用过的图：长卷视图每次刷新都要取图，有就直接用，不去碰后台队列
    /// （后台正在画别的地区时，去队列里取会把主线程卡住）。
    private static var recent: [String: UIImage] = [:]

    static func scroll(regionId: String, scene: RegionScene, theme: RegionTheme, width: CGFloat) -> UIImage {
        let key = "scroll-\(regionId)-\(Int(width))"
        if let hit = recent[key] { return hit }
        let img = SceneImages.scroll(regionId: regionId, scene: scene, theme: theme, width: width)
        recent = recent.filter { !$0.key.hasPrefix("scroll-") }               // 长卷只留一张（一张约 14MB）
        recent[key] = img
        return img
    }

    /// 雾和阳光那一层比长卷左右各宽这么多，左右飘的时候边上不露空。
    nonisolated static let mistPad: CGFloat = 24

    /// 长卷的雾和阳光（没有雾也没有阳光就是 nil）：盖在长卷上、站牌和小人下面，慢慢左右飘。
    static func mist(regionId: String, scene: RegionScene, width: CGFloat) -> UIImage? {
        guard !scene.light.mistBands.isEmpty || !scene.light.rays.isEmpty else { return nil }
        let key = "mist-\(regionId)-\(Int(width))"
        if let hit = recent[key] { return hit }
        let img = SceneImages.mist(regionId: regionId, scene: scene, width: width)
        recent = recent.filter { !$0.key.hasPrefix("mist-") }
        recent[key] = img
        return img
    }

    /// 比武背景：按固定尺寸画一次（SceneImages.duelSize 的 1.6 倍宽），用的时候按画面高度缩放。
    static func duel(regionId: String, scene: RegionScene, theme: RegionTheme, segment: Int = 0) -> UIImage {
        let key = "duel-\(regionId)-\(segment)"
        if let hit = recent[key] { return hit }
        let img = SceneImages.duel(regionId: regionId, scene: scene, theme: theme, segment: segment)
        recent = recent.filter { !$0.key.hasPrefix("duel-") }
        recent[key] = img
        return img
    }

    /// App 一打开就在后台把有正式美术场景的地区的长卷和比武背景画好（或从磁盘读出来）。
    static func prewarm(regionIds: [String], width: CGFloat) {
        let jobs = regionIds.compactMap { id in RegionScenes.scene(for: id).map { (id, $0, RegionTheme.of(id)) } }
        SceneImages.prewarm(jobs, width: width)
    }
}

/// 场景图片：在一条串行队列上画（线宽倍数 Landmarks.pen 是全局的，不能两张同时画），
/// 画好存内存（最近三张）和磁盘缓存（文件名带 App 的构建时间，美术一改就重画）。
enum SceneImages {
    static let queue = DispatchQueue(label: "typepinyin.scene-art", qos: .userInitiated)
    nonisolated(unsafe) private static var memory: [(String, UIImage)] = []          // 只在 queue 里读写
    /// 比武背景按这个尺寸画（宽再乘 1.6），地面高 52（和 DuelScene 在这个高度时一样）。
    static let duelSize = CGSize(width: 393, height: 330), duelGround: CGFloat = 52

    private static let dir: URL? = {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let d = base.appendingPathComponent("scene-art", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    private static let stamp: Int = {
        // 只换矢量图时可执行文件不一定重新生成，所以资源包的时间也算上，否则会一直读旧缓存
        let paths = [Bundle.main.executablePath, Bundle.main.path(forResource: "Assets", ofType: "car")].compactMap { $0 }
        let dates = paths.compactMap { (try? FileManager.default.attributesOfItem(atPath: $0)[.modificationDate]) as? Date }
        return Int((dates.max() ?? Date(timeIntervalSince1970: 0)).timeIntervalSince1970)
    }()

    static func scroll(regionId: String, scene: RegionScene, theme: RegionTheme, width: CGFloat) -> UIImage {
        queue.sync { scrollOnQueue(regionId, scene, theme, width) }
    }

    static func duel(regionId: String, scene: RegionScene, theme: RegionTheme, segment: Int = 0) -> UIImage {
        queue.sync { duelOnQueue(regionId, scene, theme, segment) }
    }

    static func mist(regionId: String, scene: RegionScene, width: CGFloat) -> UIImage {
        queue.sync { mistOnQueue(regionId, scene, width) }
    }

    /// 删掉磁盘上所有场景图（开发用：量装完第一次打开要画多久）。
    static func clearDiskCache() {
        guard let dir else { return }
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// 预画最后一次花了多久（秒），开发时看。
    nonisolated(unsafe) static var prewarmSeconds: Double?

    /// 把还没画过的图画好存到磁盘：已经有的不读、不占内存，只有装完第一次打开才真的要画。
    /// 一张一张排进队列：主线程这时要取图，最多等手上这一张，不用等全部画完。
    static func prewarm(_ jobs: [(String, RegionScene, RegionTheme)], width: CGFloat) {
        DispatchQueue.global(qos: .utility).async {
            let t = CACurrentMediaTime()
            removeOldFiles()
            for (id, scene, theme) in jobs {
                for segment in 0..<max(1, scene.duelSegments.count) {
                    queue.sync { ensureOnDisk(key: "duel-\(id)-\(segment)", scale: 3) { renderDuel(scene: scene, theme: theme, segment: segment) } }
                }
                if !scene.light.mistBands.isEmpty || !scene.light.rays.isEmpty {
                    queue.sync { ensureOnDisk(key: "mist-\(id)-\(Int(width))", scale: 1) { renderMist(scene: scene, width: width) } }
                }
                queue.sync { ensureOnDisk(key: "scroll-\(id)-\(Int(width))", scale: 2) { renderScroll(regionId: id, scene: scene, theme: theme, width: width) } }
            }
            prewarmSeconds = CACurrentMediaTime() - t
        }
    }

    private static func fileURL(_ key: String, _ scale: CGFloat) -> URL? { dir?.appendingPathComponent("\(key)@\(Int(scale))x-\(stamp).png") }

    private static func ensureOnDisk(key: String, scale: CGFloat, render: () -> UIImage) {
        guard let file = fileURL(key, scale), !FileManager.default.fileExists(atPath: file.path) else { return }
        autoreleasepool {
            let t = CACurrentMediaTime()
            let img = render()
            SceneRenderer.log(key, since: t)
            if let data = img.pngData() { try? data.write(to: file) }
        }
    }

    /// 更新 App 后，上个版本画的图没用了，删掉省空间。
    private static func removeOldFiles() {
        guard let dir, let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        for name in names where !name.hasSuffix("-\(stamp).png") { try? FileManager.default.removeItem(at: dir.appendingPathComponent(name)) }
    }

    private static func scrollOnQueue(_ id: String, _ scene: RegionScene, _ theme: RegionTheme, _ width: CGFloat) -> UIImage {
        image(key: "scroll-\(id)-\(Int(width))", scale: 2) { renderScroll(regionId: id, scene: scene, theme: theme, width: width) }
    }

    private static func duelOnQueue(_ id: String, _ scene: RegionScene, _ theme: RegionTheme, _ segment: Int) -> UIImage {
        image(key: "duel-\(id)-\(segment)", scale: 3) { renderDuel(scene: scene, theme: theme, segment: segment) }
    }

    private static func mistOnQueue(_ id: String, _ scene: RegionScene, _ width: CGFloat) -> UIImage {
        image(key: "mist-\(id)-\(Int(width))", scale: 1) { renderMist(scene: scene, width: width) }
    }

    private static func image(key: String, scale: CGFloat, render: () -> UIImage) -> UIImage {
        if let hit = memory.first(where: { $0.0 == key })?.1 { return hit }
        let file = fileURL(key, scale)
        if let file, let data = try? Data(contentsOf: file), let img = UIImage(data: data, scale: scale) {
            remember(key, img)
            return img
        }
        let t = CACurrentMediaTime()
        let img = render()
        SceneRenderer.log(key, since: t)
        if let file, let data = img.pngData() { try? data.write(to: file) }
        remember(key, img)
        return img
    }

    private static func remember(_ key: String, _ img: UIImage) {
        memory.removeAll { $0.0 == key }
        memory.insert((key, img), at: 0)
        if memory.count > 3 { memory.removeLast(memory.count - 3) }
    }

    // MARK: 长卷

    static func renderScroll(regionId: String, scene: RegionScene, theme: RegionTheme, width: CGFloat) -> UIImage {
        let H = SceneRenderer.scrollHeight
        let y = SceneRenderer.y
        let size = CGSize(width: width, height: H)
        let light = scene.light
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 2                                           // 长卷很长，@2x 够清楚，内存少一半
        if let name = scene.scrollAsset, let art = UIImage(named: name) {
            let artW = max(art.size.width, width)                  // 不拉伸，居中裁两边
            return UIGraphicsImageRenderer(size: size, format: format).image { _ in art.draw(in: CGRect(x: (width - artW) / 2, y: 0, width: artW, height: H)) }
        }
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let g = ctx.cgContext
            Landmarks.pen = 1
            Landmarks.sky(g, size: size, theme: theme, glow: light.skyGlow.map { UIColor(hex: $0) })
            let grass = UIColor(hex: scene.grass)
            let road = SceneRenderer.makePolyline(scene, width: width)
            let seed = regionId.unicodeScalars.reduce(0) { $0 &* 31 &+ Int($1.value) } & 0xFFFF
            func height(_ it: RegionScene.Item) -> CGFloat { it.h > 0 ? y(it.y) - y(it.y - it.h) : 0 }   // 高度也跟着长卷拉长
            func put(_ it: RegionScene.Item) {
                Landmarks.draw(it.kind, in: g, center: CGPoint(x: it.x * width, y: y(it.y)), width: it.size, height: height(it),
                               theme: theme, eyeLevel: false, flip: it.flip, grass: grass)
            }
            // 背景（云、远山、草坡）照列出的顺序；草坡铺好就上草地的明暗、满地的小草小花
            for it in scene.items where Landmarks.backdropKinds.contains(it.kind) {
                put(it)
                guard it.kind == .slope else { continue }
                let area = CGRect(x: 0, y: y(it.y) + 20, width: width, height: H - y(it.y) - 20)
                Landmarks.grassPatches(g, area: area, light: light, seed: seed)
                Landmarks.scatter(g, area: area, road: road, seed: seed)
            }
            // 贴地的（溪、踏脚石、茶园）、路、盖在路上的台阶
            scene.items.filter { Landmarks.groundKinds.contains($0.kind) }.forEach(put)
            Landmarks.road(g, line: road, style: scene.roadStyle, theme: theme)
            scene.aboveRoad.forEach(put)
            // 立着的景物：先画全部影子，再按底边从上到下画（近的盖住远的）
            let standing = scene.items.enumerated().filter {
                !Landmarks.backdropKinds.contains($0.element.kind) && !Landmarks.groundKinds.contains($0.element.kind)
            }
            Landmarks.shadows(g, standing.map { ($0.element.kind, CGPoint(x: $0.element.x * width, y: y($0.element.y)), $0.element.size, height($0.element)) },
                              light: light)
            standing.sorted { ($0.element.y, $0.offset) < ($1.element.y, $1.offset) }.forEach { put($0.element) }
        }
    }

    /// 长卷的雾和阳光：透明底，比长卷左右各宽 mistPad（飘动时边上不露空）；雾是软的，@1x 就够。
    private static func renderMist(scene: RegionScene, width: CGFloat) -> UIImage {
        let pad = SceneRenderer.mistPad, y = SceneRenderer.y, light = scene.light
        let size = CGSize(width: width + 2 * pad, height: SceneRenderer.scrollHeight)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let g = ctx.cgContext
            Landmarks.rays(g, width: size.width, starts: light.rays.map(y), color: UIColor(hex: light.rayColor))
            for b in light.mistBands {
                let top = y(b.y - b.h)
                Landmarks.mistBand(g, x0: pad + b.x0 * width, x1: pad + b.x1 * width, y: top, h: y(b.y) - top, alpha: b.alpha,
                                   color: UIColor(hex: light.mist), seed: Int(b.y))
            }
        }
    }

    // MARK: 比武背景

    /// 比 duelSize 宽 1.6 倍的平视背景；地面高 duelGround。
    static func renderDuel(scene: RegionScene, theme: RegionTheme, segment: Int = 0) -> UIImage {
        let canvas = CGSize(width: duelSize.width * 1.6, height: duelSize.height)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 3
        if scene.duelSegments.indices.contains(segment), let art = UIImage(named: scene.duelSegments[segment].asset) {
            return UIGraphicsImageRenderer(size: art.size, format: format).image { _ in art.draw(in: CGRect(origin: .zero, size: art.size)) }
        }
        return UIGraphicsImageRenderer(size: canvas, format: format).image { ctx in
            let g = ctx.cgContext
            let light = scene.light
            Landmarks.sky(g, size: canvas, theme: theme, glow: light.skyGlow.map { UIColor(hex: $0) })
            Landmarks.pen = 1.5                                                // 比武背景的景物画得大，线跟着粗一点
            defer { Landmarks.pen = 1 }
            for it in scene.duel {
                Landmarks.draw(it.kind, in: g, center: CGPoint(x: it.x * canvas.width, y: it.y * canvas.height),
                               width: it.size * canvas.height, height: it.h * canvas.height, theme: theme, eyeLevel: true, flip: it.flip,
                               grass: UIColor(hex: scene.grass))
            }
            Landmarks.rays(g, width: canvas.width, starts: light.duelRays.map { $0 * canvas.height }, color: UIColor(hex: light.rayColor))
            Landmarks.ground(g, size: canvas, height: duelGround, theme: theme)
        }
    }
}
