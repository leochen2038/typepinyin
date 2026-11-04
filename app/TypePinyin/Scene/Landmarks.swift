import UIKit

/// 景物库：长卷和比武背景共用。每样景物一个绘制函数，
/// 位置是景物的「底边中点」（站在地上的那一点），width 是景物的宽度（点）；有的景物还要一个高度（茶园、溪、远山、雾）。
/// 画法：墨绿黑细描边（约 1 点）、平涂分三层（高光、本色、暗面）。光从右上来：亮面在右上、暗面在左下，影子往左下投。
/// 同一样景物按位置算出的种子，每次形状、颜色都有点不一样（Vary）。
/// 草木石头在 Landmarks+Plants.swift，房子和物件在 Landmarks+Village.swift。
enum Landmarks {
    enum Kind {
        // 背景
        case slope, mountains, hillBand, cloud, sun, mistBand
        // 草木石水
        case pine, roundTree, blossom, bigTree, willow, bush, teaBush, flowerBed, rock, carvedRock
        case grass, flowers, pebbles, steppingStones, terraces, stream
        // 房子和物件
        case house, teaHouse, smithy, hut, shrine, stele, pavilion, gate, lantern, steps, stoneBridge, waterwheel
        case teaStall, dryingRack, laundry, waterVat, cart, bench, flags, fence, basket, firewood, well
    }

    /// 背景：先画，不投影子。
    static let backdropKinds: Set<Kind> = [.slope, .mountains, .hillBand, .cloud, .sun, .mistBand]
    /// 贴在地面上的东西（茶园也算：一垄垄是顺着山坡铺的）：画在路之前，不投影子。
    static let groundKinds: Set<Kind> = [.stream, .steppingStones, .grass, .flowers, .pebbles, .terraces]
    static let noShadow: Set<Kind> = backdropKinds.union(groundKinds).union([.stoneBridge, .steps])

    /// 线宽倍数：长卷用 1；比武背景的景物画得大，线跟着加粗（SceneImages 画之前设，画完设回 1）。
    nonisolated(unsafe) static var pen: CGFloat = 1
    /// 主描边、细节线。效果图的线换算到 393 点宽的长卷上约 1 点。
    static var O: CGFloat { 1.15 * pen }
    static var D: CGFloat { 0.75 * pen }
    /// 描边色：很深的墨绿（效果图里的线不是纯黑）。
    static let ink = UIColor(hex: 0x1B2418)

    /// 半山镇的色板（从效果图里取的）。
    enum C {
        static let grassDark = UIColor(hex: 0x3F5D35), grassLight = UIColor(hex: 0xB1B879)
        static let teaHi = UIColor(hex: 0xA0BF5E), teaLight = UIColor(hex: 0x79A34E), teaMid = UIColor(hex: 0x4E8148)
        static let teaDark = UIColor(hex: 0x2F6A47), teaDeep = UIColor(hex: 0x1A3724)
        static let stone = UIColor(hex: 0xBDA882), stoneLight = UIColor(hex: 0xD2C099), stoneShade = UIColor(hex: 0x9A8A6A)
        static let rock = UIColor(hex: 0xC9BFA9), rockLight = UIColor(hex: 0xDDD4C0), rockShade = UIColor(hex: 0xA39A85), moss = UIColor(hex: 0x8DB25A)
        static let path = UIColor(hex: 0xDACDA7), pathSeam = UIColor(hex: 0x9C8E6E)
        static let roof = UIColor(hex: 0x4F5257), roofDark = UIColor(hex: 0x26272A), roofLight = UIColor(hex: 0x7A7E84)
        static let wall = UIColor(hex: 0xF0E8D7), wallShade = UIColor(hex: 0xCFC6B4), wood = UIColor(hex: 0x7A5638), woodDark = UIColor(hex: 0x3E2A1C)
        static let woodLight = UIColor(hex: 0x9A6A3F), bamboo = UIColor(hex: 0xB89A5A)
        static let willowA = UIColor(hex: 0x98C056), willowB = UIColor(hex: 0x84B14F), willowC = UIColor(hex: 0x6B9C4B), willowDark = UIColor(hex: 0x2C4A28)
        static let pine = UIColor(hex: 0x305A3F), pineLight = UIColor(hex: 0x5F8A67), pineDark = UIColor(hex: 0x172117)
        static let leaf = UIColor(hex: 0x4E8148), leafLight = UIColor(hex: 0x7CA74F), leafDark = UIColor(hex: 0x24432B)
        static let bush = UIColor(hex: 0x3A6944), bushLight = UIColor(hex: 0x608B55)
        static let trunk = UIColor(hex: 0x6B4A30)
        static let water = UIColor(hex: 0x95C5D2), waterLight = UIColor(hex: 0xBCDDE6)
        static let red = UIColor(hex: 0xD9452B), gold = UIColor(hex: 0xE9B949), pillar = UIColor(hex: 0xC8452E), pillarShade = UIColor(hex: 0x9E3322)
        static let greenRoof = UIColor(hex: 0x34694B), greenRoofDark = UIColor(hex: 0x214A36), greenRoofLight = UIColor(hex: 0x5E8F72)
        static let pink = UIColor(hex: 0xF2A7B8), pinkDark = UIColor(hex: 0xD9708C)
        static let cloth = UIColor(hex: 0xEFE2C4), porcelain = UIColor(hex: 0xEEF2F4), blueGlaze = UIColor(hex: 0x3B6EA8)
        static let mist = UIColor(hex: 0xF1F4EE)
        static let mountainFar = UIColor(hex: 0xB4CCC0), mountainMid = UIColor(hex: 0x88AE9C), mountainNear = UIColor(hex: 0x6F9E8E), mountainLine = UIColor(hex: 0x4E7468)
        static let sky = UIColor(hex: 0xDDEDE6)
    }

    static func draw(_ kind: Kind, in g: CGContext, center b: CGPoint, width w: CGFloat, height h: CGFloat = 0,
                     theme t: RegionTheme, eyeLevel: Bool, flip: Bool = false, grass: UIColor? = nil) {
        g.saveGState()
        g.translateBy(x: b.x, y: b.y)
        if flip { g.scaleBy(x: -1, y: 1) }
        g.setLineJoin(.round)
        g.setLineCap(.round)
        let seed = Int(b.x * 7 + b.y * 3)
        switch kind {
        case .slope: slope(g, w, grass ?? t.ui(t.nearHill))
        case .mountains: mountains(g, w, h)
        case .hillBand: hillBand(g, w, grass ?? t.ui(t.nearHill))
        case .cloud: cloud(g, w)
        case .sun: sun(g, w)
        case .mistBand: mistBand(g, x0: -w / 2, x1: w / 2, y: -max(h, 8), h: max(h, 8), alpha: 0.72, color: C.mist, seed: seed)
        case .pine: pine(g, w, seed: seed)
        case .roundTree: roundTree(g, w, seed: seed, colors: (C.leaf, C.leafLight, C.leafDark))
        case .blossom: roundTree(g, w, seed: seed, colors: (C.pink, color(0xF8CAD4), C.pinkDark))
        case .bigTree: bigTree(g, w, seed: seed)
        case .willow: willow(g, w, seed: seed)
        case .bush, .teaBush: bush(g, w, seed: seed)
        case .flowerBed: flowerBed(g, w, seed: seed)
        case .rock: rock(g, w, seed: seed)
        case .carvedRock: carvedRock(g, w, seed: seed)
        case .grass: tufts(g, w, seed: seed)
        case .flowers: flowers(g, w, seed: seed)
        case .pebbles: pebbles(g, w)
        case .steppingStones: steppingStones(g, w)
        case .terraces: terraces(g, w, h > 0 ? h : w, seed: seed)
        case .stream: stream(g, w, h > 0 ? h : w)
        case .house: house(g, w, seed: seed)
        case .teaHouse: house(g, w, seed: seed, tea: true)
        case .smithy: smithy(g, w)
        case .hut: hut(g, w, seed: seed)
        case .shrine: shrine(g, w)
        case .stele: stele(g, w, seed: seed)
        case .pavilion: pavilion(g, w)
        case .gate: gate(g, w)
        case .lantern: lantern(g, w)
        case .steps: steps(g, w)
        case .stoneBridge: stoneBridge(g, w)
        case .waterwheel: waterwheel(g, w)
        case .teaStall: teaStall(g, w)
        case .dryingRack: dryingRack(g, w, seed: seed)
        case .laundry: laundry(g, w, seed: seed)
        case .waterVat: waterVat(g, w)
        case .cart: cart(g, w)
        case .bench: bench(g, w)
        case .flags: flags(g, w)
        case .fence: fence(g, w, seed: seed)
        case .basket: basket(g, w, seed: seed)
        case .firewood: firewood(g, w)
        case .well: well(g, w)
        }
        g.restoreGState()
    }

    /// 景物实心部分大约多高（宽 × 高，底边中点在原点），投影子用；旗杆、烟这类细的、飘的不算。
    static func extent(_ kind: Kind, width w: CGFloat, height h: CGFloat) -> CGSize {
        let f: CGFloat
        switch kind {
        case .house, .teaHouse: f = 0.84
        case .smithy: f = 0.75
        case .gate: f = 1.0
        case .pine: f = 1.45
        case .roundTree, .blossom: f = 1.05
        case .bigTree: f = 1.0
        case .willow: f = 1.15
        case .bush, .teaBush: f = 0.5
        case .flowerBed: f = 0.3
        case .rock: f = 0.6
        case .carvedRock: f = 0.7
        case .fence: f = 0.3
        case .basket: f = 0.4
        case .firewood: f = 0.6
        case .well: f = 0.8
        case .pavilion: f = 0.92
        case .lantern: f = 1.2
        case .hut: f = 0.7
        case .shrine: f = 0.5
        case .stele: f = 0.8
        case .waterwheel: f = 0.75
        case .teaStall: f = 0.6
        case .dryingRack: f = 0.22
        case .laundry: f = 0.5
        case .waterVat: f = 0.62
        case .cart: f = 0.45
        case .bench: f = 0.16
        case .flags: f = 0.5
        case .terraces, .stream: return CGSize(width: w, height: h)
        default: return .zero
        }
        return CGSize(width: w, height: w * f)
    }

    // MARK: 工具

    static func color(_ hex: UInt32) -> UIColor { UIColor(hex: hex) }

    static func shape(_ g: CGContext, _ path: CGPath, fill: UIColor?, line: CGFloat? = nil, stroke: UIColor = ink) {
        if let fill { g.addPath(path); g.setFillColor(fill.cgColor); g.fillPath() }
        let lw = line ?? O
        if lw > 0 { g.addPath(path); g.setStrokeColor(stroke.cgColor); g.setLineWidth(lw); g.strokePath() }
    }

    static func dots(_ g: CGContext, _ path: CGPath, alpha: CGFloat = 0.22) {
        ArtStyle.fillDots(g, path: path, spacing: 4.5, radius: 0.8, alpha: alpha)
    }

    /// 按景物宽度缩放的 SVG 路径：d 里的坐标以宽 100 为准，底边中点在原点。
    static func path(_ d: String, _ w: CGFloat) -> CGPath {
        var t = CGAffineTransform(scaleX: w / 100, y: w / 100)
        return SVGPath.parse(d).copy(using: &t) ?? SVGPath.parse(d)
    }

    static func line(_ g: CGContext, _ d: String, _ w: CGFloat, width: CGFloat? = nil, color: UIColor = ink) {
        g.addPath(path(d, w)); g.setStrokeColor(color.cgColor); g.setLineWidth(width ?? D); g.strokePath()
    }

    static func ellipse(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry), transform: nil)
    }

    /// 椭圆，坐标和半径都按宽 100 的单位（和 path 一样）。
    static func E(_ w: CGFloat, _ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
        let k = w / 100
        return ellipse(x * k, y * k, rx * k, ry * k)
    }

    /// 矩形，按宽 100 的单位。
    static func R(_ w: CGFloat, _ x: CGFloat, _ y: CGFloat, _ rw: CGFloat, _ rh: CGFloat) -> CGRect {
        let k = w / 100
        return CGRect(x: x * k, y: y * k, width: rw * k, height: rh * k)
    }

    /// 固定种子的随机数（每次画得一样）。
    struct Rand {
        var s: UInt64
        init(_ seed: Int) { s = UInt64(truncatingIfNeeded: seed) &* 0x9E37_79B9_7F4A_7C15 &+ 0x1234_5678 }
        mutating func next() -> CGFloat {
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat((s >> 33) % 10_000) / 10_000
        }
        mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
    }

    /// 每样景物的个体差异：按位置算出的种子，决定形状大小、颜色深浅的细微变化，同一种东西每次都不太一样。
    struct Vary {
        var r: Rand
        init(_ seed: Int) { r = Rand(seed &* 7919 &+ 17) }
        mutating func f(_ a: CGFloat, _ b: CGFloat) -> CGFloat { r.range(a, b) }
        mutating func chance(_ p: CGFloat) -> Bool { r.next() < p }
        mutating func pick<T>(_ xs: [T]) -> T { xs[min(xs.count - 1, Int(r.next() * CGFloat(xs.count)))] }
    }

    /// 颜色微调：明度上下 k，色相、饱和度轻轻偏一点。
    static func tint(_ c: UIColor, _ v: inout Vary, _ k: CGFloat = 0.06) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: (h + v.f(-0.012, 0.012) + 1).truncatingRemainder(dividingBy: 1),
                       saturation: min(1, max(0, s * v.f(0.93, 1.07))), brightness: min(1, max(0, b * (1 + v.f(-k, k)))), alpha: a)
    }

    /// 穿过这些点的平滑曲线（Catmull-Rom）；closed 时首尾接上。
    static func smooth(_ pts: [CGPoint], closed: Bool) -> CGMutablePath {
        let p = CGMutablePath()
        guard let first = pts.first else { return p }
        p.move(to: first)
        addSmooth(p, pts, closed: closed)
        if closed { p.closeSubpath() }
        return p
    }

    /// 从当前点（应当就是 pts[0]）接着画穿过 pts 的平滑曲线（拼树干这类两条边合成一个形状时用）。
    static func addSmooth(_ p: CGMutablePath, _ pts: [CGPoint], closed: Bool = false) {
        let n = pts.count
        guard n > 2 else { if n == 2 { p.addLine(to: pts[1]) }; return }
        for i in 0..<(closed ? n : n - 1) {
            let p0 = pts[closed ? (i - 1 + n) % n : max(0, i - 1)], p1 = pts[i]
            let p2 = pts[closed ? (i + 1) % n : min(n - 1, i + 1)], p3 = pts[closed ? (i + 2) % n : min(n - 1, i + 2)]
            p.addCurve(to: p2, control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                       control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
        }
    }

    /// 不规则的一团：绕 (cx, cy) 一圈 n 个点，半径按种子起伏（树冠的团、草地的明暗块、苔藓）。
    static func blob(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, n: Int, wob: CGFloat, v: inout Vary) -> CGMutablePath {
        var pts: [CGPoint] = []
        let a0 = v.f(0, 2 * .pi)
        for i in 0..<n {
            let a = a0 + CGFloat(i) / CGFloat(n) * 2 * .pi, k = 1 + v.f(-wob, wob)
            pts.append(CGPoint(x: cx + cos(a) * rx * k, y: cy + sin(a) * ry * k))
        }
        return smooth(pts, closed: true)
    }

    /// 圆顶：底边平（站在地上），上面一圈起伏（灌木、石头）；lean 让顶往一边歪。坐标以底边中点为原点。
    static func dome(_ rx: CGFloat, _ ry: CGFloat, n: Int, wob: CGFloat, v: inout Vary, lean: CGFloat = 0) -> CGMutablePath {
        var pts: [CGPoint] = []
        for i in 0...n {
            let a = CGFloat(i) / CGFloat(n) * .pi
            let k = (i == 0 || i == n) ? 1 : 1 + v.f(-wob, wob)
            pts.append(CGPoint(x: cos(a) * rx * k + lean * sin(a) * ry, y: -sin(a) * ry * k))
        }
        let p = smooth(pts, closed: false)
        p.closeSubpath()
        return p
    }

    /// 给一个形状上光：右上一块亮、左下一块暗（只填和形状重叠的部分）。
    static func light(_ g: CGContext, _ p: CGPath, lit: UIColor, shade: UIColor, litH: CGFloat = 0.45, shadeH: CGFloat = 0.3) {
        let b = p.boundingBoxOfPath
        band(g, p, CGRect(x: b.minX + b.width * 0.18, y: b.minY, width: b.width * 0.82, height: b.height * litH), lit)
        band(g, p, CGRect(x: b.minX, y: b.maxY - b.height * shadeH, width: b.width * 0.78, height: b.height * shadeH), shade)
    }

    /// 叶纹：在形状里撒一个个小「u」形弧（深色），上半部分夹一些浅色的，像效果图里茶垄、灌木、树冠的细叶。
    /// 同色的弧先攒成一条路径，最后各描一次（一笔笔单独描太慢）。
    static func leaves(_ g: CGContext, _ p: CGPath, seed: Int, dark: UIColor, light: UIColor?, size: CGFloat, density: CGFloat = 0.5) {
        let box = p.boundingBoxOfPath
        guard box.width > 1, box.height > 1 else { return }
        var r = Rand(seed)
        let darkPath = CGMutablePath(), lightPath = CGMutablePath()
        let n = Int(box.width * box.height / (size * size) * density)
        for _ in 0..<n {
            let x = r.range(box.minX, box.maxX), y = r.range(box.minY, box.maxY)
            let upper = (y - box.minY) < box.height * 0.5
            let target = (light != nil && upper && r.next() < 0.45) ? lightPath : darkPath
            let s = size * r.range(0.7, 1.1)
            target.move(to: CGPoint(x: x - s / 2, y: y - s * 0.15))
            target.addQuadCurve(to: CGPoint(x: x + s / 2, y: y - s * 0.15), control: CGPoint(x: x, y: y + s * 0.4))
        }
        g.saveGState()
        g.addPath(p); g.clip()
        g.setLineWidth(D * 0.9); g.setLineCap(.round)
        g.addPath(darkPath); g.setStrokeColor(dark.cgColor); g.strokePath()
        if let light { g.addPath(lightPath); g.setStrokeColor(light.cgColor); g.strokePath() }
        g.restoreGState()
    }

    /// 在路径里填一块颜色，只填路径和一个矩形的交集（给形状上色的一截用）。
    static func band(_ g: CGContext, _ p: CGPath, _ rect: CGRect, _ c: UIColor) {
        g.saveGState()
        g.addPath(p); g.clip()
        g.setFillColor(c.cgColor); g.fill(rect)
        g.restoreGState()
    }

    // MARK: 天、地、路

    static func sky(_ g: CGContext, size: CGSize, theme t: RegionTheme, glow: UIColor? = nil) {
        g.setFillColor(C.sky.cgColor)
        g.fill(CGRect(origin: .zero, size: size))
        let top = ArtStyle.mix(C.sky, .white, 0.45)
        let space = CGColorSpaceCreateDeviceRGB()
        if let grad = CGGradient(colorsSpace: space, colors: [top.cgColor, C.sky.cgColor] as CFArray, locations: [0, 1]) {
            g.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: min(size.height, 360)), options: [])
        }
        if let glow, let rg = CGGradient(colorsSpace: space, colors: [glow.withAlphaComponent(0.8).cgColor, glow.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1]) {
            let c = CGPoint(x: size.width * 0.86, y: 0)
            g.drawRadialGradient(rg, startCenter: c, startRadius: 0, endCenter: c, endRadius: min(size.width * 0.95, 340), options: [])
        }
    }

    /// 弯曲的山路：细墨边、浅米色石板，错缝铺（每 7 点一行，单行三块、双行两块）。
    static func road(_ g: CGContext, line pts: [CGPoint], style: RegionScene.RoadStyle, theme t: RegionTheme) {
        guard pts.count >= 2 else { return }
        let p = CGMutablePath()
        p.addLines(between: pts)
        let half: CGFloat = 14
        g.setLineJoin(.round); g.setLineCap(.round)
        g.addPath(p); g.setStrokeColor(ink.cgColor); g.setLineWidth(2 * half + 2 * O * 1.2); g.strokePath()
        g.addPath(p); g.setStrokeColor(C.path.cgColor); g.setLineWidth(2 * half); g.strokePath()
        guard style == .stone else { return }
        g.setStrokeColor(C.pathSeam.cgColor)
        g.setLineWidth(D)
        var dist: CGFloat = 0, next: CGFloat = 3, k = 0
        let rowH: CGFloat = 7
        for i in 1..<pts.count {
            let a = pts[i - 1], b = pts[i]
            let seg = hypot(b.x - a.x, b.y - a.y)
            guard seg > 0 else { continue }
            let d = CGPoint(x: (b.x - a.x) / seg, y: (b.y - a.y) / seg), n = CGPoint(x: -d.y, y: d.x)
            while next <= dist + seg {
                let f = (next - dist) / seg
                let c = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
                g.move(to: CGPoint(x: c.x + n.x * half, y: c.y + n.y * half))
                g.addLine(to: CGPoint(x: c.x - n.x * half, y: c.y - n.y * half))
                let offs: [CGFloat] = k % 2 == 0 ? [-half / 2, half / 2] : [0]
                for off in offs {
                    let m = CGPoint(x: c.x + d.x * rowH / 2 + n.x * off, y: c.y + d.y * rowH / 2 + n.y * off)
                    g.move(to: CGPoint(x: m.x - d.x * rowH / 2, y: m.y - d.y * rowH / 2))
                    g.addLine(to: CGPoint(x: m.x + d.x * rowH / 2, y: m.y + d.y * rowH / 2))
                }
                next += rowH; k += 1
            }
            dist += seg
        }
        g.strokePath()
    }

    /// 比武背景的地面：浅米色石板路面（错缝），上沿一道墨线。
    static func ground(_ g: CGContext, size: CGSize, height h: CGFloat, theme t: RegionTheme) {
        let top = size.height - h
        g.setFillColor(C.path.cgColor)
        g.fill(CGRect(x: 0, y: top, width: size.width, height: h))
        g.setStrokeColor(C.pathSeam.cgColor); g.setLineWidth(D)
        let rows = 3
        let rowH = h / CGFloat(rows)
        for rIdx in 0..<rows {
            let y0 = top + CGFloat(rIdx) * rowH
            if rIdx > 0 { g.move(to: CGPoint(x: 0, y: y0)); g.addLine(to: CGPoint(x: size.width, y: y0)) }
            var x: CGFloat = rIdx % 2 == 0 ? 0 : 17
            while x < size.width {
                g.move(to: CGPoint(x: x, y: y0)); g.addLine(to: CGPoint(x: x, y: y0 + rowH))
                x += 34
            }
        }
        g.strokePath()
        g.setStrokeColor(ink.cgColor); g.setLineWidth(O * 1.4)
        g.move(to: CGPoint(x: 0, y: top)); g.addLine(to: CGPoint(x: size.width, y: top)); g.strokePath()
    }

    // MARK: 山、云

    /// 一大片草坡：上沿起伏、描边，铺满下面（长卷的地面）。width 很大，高度向下 4000 点。
    static func slope(_ g: CGContext, _ w: CGFloat, _ c: UIColor) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -w / 2, y: 30))
        p.addQuadCurve(to: CGPoint(x: -w / 6, y: -4), control: CGPoint(x: -w / 3, y: -24))
        p.addQuadCurve(to: CGPoint(x: w / 6, y: 8), control: CGPoint(x: 0, y: 26))
        p.addQuadCurve(to: CGPoint(x: w / 2, y: -10), control: CGPoint(x: w / 3, y: -30))
        p.addLine(to: CGPoint(x: w / 2, y: 4000)); p.addLine(to: CGPoint(x: -w / 2, y: 4000)); p.closeSubpath()
        shape(g, p, fill: c)
    }

    /// 远山：三层，越远越淡；每层一串圆润的山头（山坡内凹、山顶圆），山脊描细线，近两层画山褶；每层山脚一道白雾。
    /// height：山的总高（比武背景按画布高度给；不给就按宽度算，最高 145）。
    static func mountains(_ g: CGContext, _ w: CGFloat, _ height: CGFloat) {
        let H = height > 0 ? height : min(w * 0.22, 145)
        var r = Rand(Int(w) + 3)
        let layers: [(lift: CGFloat, color: UIColor, n: Int, hMin: CGFloat, hMax: CGFloat)] = [
            (0.5, C.mountainFar, 7, 0.3, 0.5), (0.28, C.mountainMid, 6, 0.24, 0.42), (0.05, C.mountainNear, 7, 0.18, 0.34)]
        for (li, L) in layers.enumerated() {
            let base = -H * L.lift
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -w / 2 - 10, y: base + H * 0.5))
            var x0 = -w / 2 - 10
            var y0 = base - H * 0.1
            p.addLine(to: CGPoint(x: x0, y: y0))
            var peaks: [CGPoint] = []
            let span = (w + 20) / CGFloat(L.n)
            for _ in 0..<L.n {
                let px = x0 + span * r.range(0.4, 0.6)
                let py = base - H * r.range(L.hMin, L.hMax)
                let vx = x0 + span, vy = base - H * r.range(0.05, 0.14)
                p.addCurve(to: CGPoint(x: px, y: py), control1: CGPoint(x: x0 + (px - x0) * 0.5, y: y0), control2: CGPoint(x: px - span * 0.28, y: py))
                p.addCurve(to: CGPoint(x: vx, y: vy), control1: CGPoint(x: px + span * 0.28, y: py), control2: CGPoint(x: px + (vx - px) * 0.5, y: vy))
                peaks.append(CGPoint(x: px, y: py))
                x0 = vx; y0 = vy
            }
            p.addLine(to: CGPoint(x: x0, y: base + H * 0.5)); p.closeSubpath()
            shape(g, p, fill: L.color, line: D, stroke: C.mountainLine)
            if li > 0 {                                               // 山褶：从山顶往下几道弯线
                g.setStrokeColor(ArtStyle.shade(L.color, 0.8).cgColor); g.setLineWidth(D)
                for pk in peaks {
                    for sgn: CGFloat in [-1, 1] {
                        g.move(to: CGPoint(x: pk.x + sgn * span * 0.06, y: pk.y + H * 0.03))
                        g.addQuadCurve(to: CGPoint(x: pk.x + sgn * span * 0.22, y: pk.y + H * 0.2), control: CGPoint(x: pk.x + sgn * span * 0.06, y: pk.y + H * 0.13))
                    }
                }
                g.strokePath()
            }
            g.setFillColor(C.mist.withAlphaComponent(0.92).cgColor)    // 山脚的白雾
            var x = -w / 2 + r.range(0, w * 0.08)
            while x < w / 2 {
                let rw = w * r.range(0.06, 0.11)
                g.addPath(ellipse(x, base + H * 0.04, rw, H * 0.05)); g.fillPath()
                x += rw * r.range(1.3, 2.2)
            }
        }
    }

    /// 中景的一道山梁：草色，细描边。
    static func hillBand(_ g: CGContext, _ w: CGFloat, _ grass: UIColor) {
        let h = min(w * 0.12, 56)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -w / 2, y: 0))
        p.addQuadCurve(to: CGPoint(x: -w * 0.18, y: -h), control: CGPoint(x: -w * 0.36, y: -h * 1.1))
        p.addQuadCurve(to: CGPoint(x: w * 0.14, y: -h * 0.45), control: CGPoint(x: -w * 0.02, y: -h * 0.4))
        p.addQuadCurve(to: CGPoint(x: w / 2, y: -h * 0.9), control: CGPoint(x: w * 0.34, y: -h * 1.2))
        p.addLine(to: CGPoint(x: w / 2, y: h * 2)); p.addLine(to: CGPoint(x: -w / 2, y: h * 2)); p.closeSubpath()
        shape(g, p, fill: grass)
    }

    /// 祥云：描边的云朵，里面两个卷。
    static func cloud(_ g: CGContext, _ w: CGFloat) {
        shape(g, path("M -46 0 Q -50 -14 -36 -16 Q -36 -30 -18 -28 Q -10 -40 6 -34 Q 24 -40 28 -24 Q 48 -26 50 -10 Q 52 0 40 0 Z", w),
              fill: color(0xFBF8EF))
        line(g, "M -16 -14 Q -10 -22 -2 -16 Q 2 -10 -6 -8", w, width: O)
        line(g, "M 14 -12 Q 20 -20 28 -14", w, width: O)
    }

    static func sun(_ g: CGContext, _ w: CGFloat) {
        let r = w / 2
        shape(g, CGPath(ellipseIn: CGRect(x: -r, y: -2 * r, width: 2 * r, height: 2 * r), transform: nil), fill: color(0xF3C14E))
    }

    // MARK: 光和空气

    /// 草地的明暗：太阳照到的地方浅一块，背光、低洼的地方深一块（不规则的扁团，平涂、不描边）。
    static func grassPatches(_ g: CGContext, area: CGRect, light L: SceneLight, seed: Int) {
        var v = Vary(seed)
        let lit = CGMutablePath(), shade = CGMutablePath()
        var y = area.minY + 8
        while y < area.maxY {
            for _ in 0..<2 {
                let rx = v.f(30, 88), ry = rx * v.f(0.2, 0.34)
                let blobPath = blob(v.f(area.minX - 20, area.maxX + 20), y + v.f(-10, 10), rx, ry, n: 10, wob: 0.22, v: &v)
                (v.chance(0.5) ? lit : shade).addPath(blobPath)
            }
            y += v.f(24, 40)
        }
        g.addPath(shade); g.setFillColor(UIColor(hex: L.grassShade).cgColor); g.fillPath()
        g.addPath(lit); g.setFillColor(UIColor(hex: L.grassLight).cgColor); g.fillPath()
    }

    /// 草地上满地的草叶、苜蓿、小花、石子，路边再多点一些小花（固定种子，避开路面）。
    /// 全部先攒成几条路径，最后按颜色各画一次（几千个小东西一个个画太慢）。
    static func scatter(_ g: CGContext, area: CGRect, road: [CGPoint], seed: Int) {
        var r = Rand(seed)
        let darkBlades = CGMutablePath(), lightBlades = CGMutablePath(), clovers = CGMutablePath(), pebbles = CGMutablePath()
        let petals = [CGMutablePath(), CGMutablePath(), CGMutablePath()], centers = CGMutablePath()
        let petalColors = [UIColor.white, C.pink, color(0xF6E27A)]
        func blades(_ p: CGPoint, _ s: CGFloat, light: Bool) {
            let k = s / 100
            for (bx, tips) in [(-26.0, [(-30.0, -12.0), (-24, -15), (-19, -11)]), (6, [(2, -11), (8, -15), (13, -10)])] {
                for (tx, ty) in tips {
                    darkBlades.move(to: CGPoint(x: p.x + bx * k, y: p.y)); darkBlades.addLine(to: CGPoint(x: p.x + tx * k, y: p.y + ty * k))
                }
            }
            if light {
                lightBlades.move(to: CGPoint(x: p.x + 30 * k, y: p.y)); lightBlades.addLine(to: CGPoint(x: p.x + 28 * k, y: p.y - 12 * k))
                lightBlades.move(to: CGPoint(x: p.x + 30 * k, y: p.y)); lightBlades.addLine(to: CGPoint(x: p.x + 35 * k, y: p.y - 10 * k))
            }
        }
        func flower(_ c: CGPoint, _ s: CGFloat, _ ci: Int) {
            for i in 0..<5 {
                let a = CGFloat(i) * .pi * 2 / 5 - .pi / 2
                petals[ci].addEllipse(in: CGRect(x: c.x + cos(a) * s - s * 0.72, y: c.y + sin(a) * s - s * 0.72, width: s * 1.44, height: s * 1.44))
            }
            centers.addEllipse(in: CGRect(x: c.x - s * 0.5, y: c.y - s * 0.5, width: s, height: s))
        }
        func nearRoad(_ p: CGPoint, _ d: CGFloat) -> Bool { road.contains { abs($0.y - p.y) < d && hypot($0.x - p.x, $0.y - p.y) < d } }
        let n = Int(area.width * area.height / 600)
        for _ in 0..<n {
            let p = CGPoint(x: r.range(area.minX, area.maxX), y: r.range(area.minY, area.maxY))
            let kind = r.next(), size = r.range(16, 26)
            if nearRoad(p, 24) { continue }
            switch kind {                                                  // 草叶为主，小花少撒（花集中在路边和花丛）
            case ..<0.7: blades(p, size, light: r.next() < 0.33)
            case ..<0.82:
                for (x, y) in [(-0.12, -0.08), (0.12, -0.08), (0, -0.2)] { clovers.addEllipse(in: CGRect(x: p.x + (x - 0.11) * size, y: p.y + (y - 0.09) * size, width: size * 0.22, height: size * 0.18)) }
            case ..<0.94:
                for _ in 0..<3 { flower(CGPoint(x: p.x + r.range(-0.35, 0.35) * size, y: p.y + r.range(-0.3, 0) * size), size * 0.08, r.next() < 0.55 ? 0 : 1) }
            default:
                for (x, y, rx) in [(-0.3, -0.04, 0.11), (0.05, 0.0, 0.08), (0.3, -0.05, 0.1)] { pebbles.addEllipse(in: CGRect(x: p.x + (x - rx) * size, y: p.y + (y - rx * 0.6) * size, width: 2 * rx * size, height: 1.2 * rx * size)) }
            }
        }
        // 路边：隔一小段点几朵小花或一丛草，左右交替
        var dist: CGFloat = 0, next: CGFloat = 20, side: CGFloat = 1
        for i in 1..<max(1, road.count) {
            let a = road[i - 1], b = road[i], seg = hypot(b.x - a.x, b.y - a.y)
            guard seg > 0 else { continue }
            while next <= dist + seg {
                let f = (next - dist) / seg
                let c = CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
                let nrm = CGPoint(x: -(b.y - a.y) / seg, y: (b.x - a.x) / seg), off = r.range(22, 30)
                let p = CGPoint(x: c.x + nrm.x * off * side, y: c.y + nrm.y * off * side + 4)
                if p.y > area.minY + 100 && r.next() > 0.25 {
                    if r.next() < 0.6 {
                        let s = r.range(18, 26)
                        for _ in 0..<3 { flower(CGPoint(x: p.x + r.range(-0.35, 0.35) * s, y: p.y + r.range(-0.3, 0) * s), s * 0.08, Int(r.next() * 2.99)) }
                    } else { blades(p, r.range(18, 24), light: true) }
                }
                side = -side
                next += r.range(12, 20)
            }
            dist += seg
        }
        g.setLineCap(.round); g.setLineJoin(.round)
        g.addPath(darkBlades); g.setStrokeColor(C.grassDark.cgColor); g.setLineWidth(D); g.strokePath()
        g.addPath(lightBlades); g.setStrokeColor(C.grassLight.cgColor); g.setLineWidth(D); g.strokePath()
        shape(g, clovers, fill: color(0x4F7F3E), line: D * 0.6)
        shape(g, pebbles, fill: C.rockLight, line: D)
        for p in petals { g.addPath(p) }                                   // 花瓣先一起描边，再按颜色填，花瓣之间不留线
        g.setStrokeColor(ink.cgColor); g.setLineWidth(D * 1.2); g.strokePath()
        for (i, p) in petals.enumerated() { g.addPath(p); g.setFillColor(petalColors[i].cgColor); g.fillPath() }
        g.addPath(centers); g.setFillColor(color(0xE9B949).cgColor); g.fillPath()
    }

    /// 影子：每样立着的东西脚下一块扁影子，往背光的一侧（左下）拉；高的拉得长。两层（外浅内深）显得软。
    /// items：(种类, 底边中点, 宽, 高)。所有影子攒成两条路径各画一次，叠在一起的影子不会更黑。
    static func shadows(_ g: CGContext, _ items: [(Kind, CGPoint, CGFloat, CGFloat)], light L: SceneLight) {
        let outer = CGMutablePath(), inner = CGMutablePath()
        for (kind, b, w, h) in items where !noShadow.contains(kind) {
            let e = extent(kind, width: w, height: h)
            guard e.height > 0 else { continue }
            let len = min(e.height * L.shadowLength, L.shadowMax)
            let dx = L.shadowDir.dx * len, dy = L.shadowDir.dy * len
            let rx = w * 0.44 + abs(dx) * 0.5, ry = max(2.5, min(w * 0.1, 5) + len * 0.12)
            let c = CGPoint(x: b.x + dx * 0.5, y: b.y - 0.5 + dy * 0.5)
            outer.addEllipse(in: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry))
            inner.addEllipse(in: CGRect(x: c.x - rx * 0.7 + dx * 0.12, y: c.y - ry * 0.66, width: 2 * rx * 0.7, height: 2 * ry * 0.66))
        }
        let sc = UIColor(hex: L.shadow)
        g.addPath(outer); g.setFillColor(sc.withAlphaComponent(L.shadowAlpha * 0.55).cgColor); g.fillPath()
        g.addPath(inner); g.setFillColor(sc.withAlphaComponent(L.shadowAlpha * 0.55).cgColor); g.fillPath()
    }

    /// 一条雾带：上沿一串圆鼓鼓的云头、下沿缓缓起伏、两头收窄；三层叠出软边（外大淡、内小浓），不描边。
    /// x0…x1 是左右范围，y 是雾带顶，h 是厚度（都是点）。
    static func mistBand(_ g: CGContext, x0: CGFloat, x1: CGFloat, y: CGFloat, h: CGFloat, alpha: CGFloat, color: UIColor, seed: Int) {
        var v = Vary(seed)
        var heads: [(x: CGFloat, w: CGFloat, hf: CGFloat)] = []
        var x = x0
        while x < x1 { let hw = v.f(h * 1.1, h * 2.2); heads.append((x + hw / 2, hw, v.f(0.45, 1))); x += hw * v.f(0.7, 0.9) }
        let midY = y + h * 0.55
        for layer in 0..<3 {
            let grow = CGFloat(2 - layer) * h * 0.16
            var top: [CGPoint] = [CGPoint(x: x0 - grow, y: midY)]
            for hd in heads {
                let taper = min(1, min(hd.x - x0, x1 - hd.x) / (h * 2.4) + 0.3)
                top.append(CGPoint(x: hd.x - hd.w * 0.32, y: midY - (h * 0.25 + grow * 0.6) * taper))
                top.append(CGPoint(x: hd.x, y: midY - (h * 0.55 * hd.hf + grow) * taper))
                top.append(CGPoint(x: hd.x + hd.w * 0.32, y: midY - (h * 0.25 + grow * 0.6) * taper))
            }
            top.append(CGPoint(x: x1 + grow, y: midY))
            var bottom: [CGPoint] = []
            for s in 0...10 {
                let fx = x1 + grow - (x1 - x0 + 2 * grow) * CGFloat(s) / 10
                let taper = min(1, min(fx - x0, x1 - fx) / (h * 2.4) + 0.35)
                bottom.append(CGPoint(x: fx, y: midY + (h * 0.42 + grow * 0.5) * taper + sin(fx * 0.045 + CGFloat(seed)) * h * 0.06))
            }
            let p = smooth(top + bottom, closed: true)
            g.addPath(p); g.setFillColor(color.withAlphaComponent(alpha * [0.3, 0.38, 0.5][layer]).cgColor); g.fillPath()
        }
    }

    /// 阳光：从右边缘斜着往左下射的几道淡金色光带（宽的淡、窄的亮一点；越远越宽）。
    static func rays(_ g: CGContext, width: CGFloat, starts: [CGFloat], color: UIColor) {
        let dir = CGVector(dx: -0.8, dy: 0.6), len = width * 1.9
        let n = CGVector(dx: dir.dy, dy: -dir.dx)
        for (i, y0) in starts.enumerated() {
            let o = CGPoint(x: width + 12, y: y0), e = CGPoint(x: o.x + dir.dx * len, y: o.y + dir.dy * len)
            for (wd, a) in [(CGFloat(30 + i % 2 * 14), CGFloat(0.07)), (CGFloat(12 + i % 2 * 5), CGFloat(0.08))] {
                let w0 = wd * 0.55, w1 = wd * 1.5
                let p = CGMutablePath()
                p.addLines(between: [CGPoint(x: o.x + n.dx * w0, y: o.y + n.dy * w0), CGPoint(x: e.x + n.dx * w1, y: e.y + n.dy * w1),
                                     CGPoint(x: e.x - n.dx * w1, y: e.y - n.dy * w1), CGPoint(x: o.x - n.dx * w0, y: o.y - n.dy * w0)])
                p.closeSubpath()
                g.addPath(p); g.setFillColor(color.withAlphaComponent(a).cgColor); g.fillPath()
            }
        }
    }
}
