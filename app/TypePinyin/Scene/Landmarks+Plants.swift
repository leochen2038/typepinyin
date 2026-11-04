import UIKit

/// 景物库的草木、石头、茶园和水。树、灌木、石头按种子各有各的样子（Vary）：歪向、团数、大小、颜色深浅都不同。
/// 光从右上来：每团、每块的右上亮，左下暗。
extension Landmarks {
    // MARK: 工具

    /// 只在 clip 形状里面填 p（给形状上一块亮面、暗面）。
    static func clipFill(_ g: CGContext, _ clip: CGPath, _ p: CGPath, _ c: UIColor) {
        g.saveGState()
        g.addPath(clip); g.clip()
        g.addPath(p); g.setFillColor(c.cgColor); g.fillPath()
        g.restoreGState()
    }

    /// 树干：从底边到 top 的一根，两条边是平滑曲线；x(y) 给出每个高度的中线，half(f) 给出半宽（f：0 底、1 顶），都按宽 100 的单位。
    static func trunk(_ w: CGFloat, top: CGFloat, x: (CGFloat) -> CGFloat, half: (CGFloat) -> CGFloat) -> CGPath {
        let k = w / 100
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0...6 {
            let f = CGFloat(i) / 6, y = top * f
            left.append(CGPoint(x: (x(y) - half(f)) * k, y: y * k))
            right.append(CGPoint(x: (x(y) + half(f)) * k, y: y * k))
        }
        let p = CGMutablePath()
        p.move(to: left[0])
        addSmooth(p, left)
        p.addLine(to: right[6])
        addSmooth(p, right.reversed())
        p.closeSubpath()
        return p
    }

    /// 带墨边的枝条：先画一道粗墨线，再在上面画细一点的树皮色。
    static func branch(_ g: CGContext, _ d: String, _ w: CGFloat, width: CGFloat, color: UIColor = C.trunk) {
        line(g, d, w, width: width + 2 * O, color: ink)
        line(g, d, w, width: width, color: color)
    }

    // MARK: 树

    /// 中式松：弯曲的树干往一边歪，一层层云状的针叶团（层数、大小、左右错落每棵不同），团的右上亮、下沿深，松针纹。
    static func pine(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        let k = w / 100
        let lean = v.f(-10, 10), top = v.f(-142, -124), bend = v.f(2, 6) * (v.chance(0.5) ? 1 : -1)
        let base = tint(C.pine, &v, 0.08), lit = tint(C.pineLight, &v, 0.06)
        func cx(_ y: CGFloat) -> CGFloat { let f = min(1, y / top); return 1.5 + (lean - 1.5) * f + sin(f * .pi * 1.4) * bend }
        let stem = trunk(w, top: top + 14, x: cx, half: { f in 6.5 - 4 * f + (f == 0 ? 2.5 : 0) })
        shape(g, stem, fill: C.trunk)
        line(g, "M \(cx(-14) - 1) -14 Q \(cx(-40)) -40 \(cx(-62) - 2) -62", w, color: ArtStyle.shade(C.trunk, 0.7))
        // 针叶团：从顶往下一层层，越往下越宽；每层一团或左右两团
        var pads: [(x: CGFloat, y: CGFloat, rw: CGFloat, rh: CGFloat)] = [(cx(top) + v.f(-3, 3), top + 4, v.f(20, 26), v.f(13, 16))]
        let tiers = v.chance(0.5) ? 4 : 5
        var side: CGFloat = v.chance(0.5) ? 1 : -1
        for i in 1...tiers {
            let f = CGFloat(i) / CGFloat(tiers)
            let y = top + 4 + f * (-54 - top - 4) + v.f(-4, 4)
            let spread = 8 + f * 22
            pads.append((cx(y) + side * spread * v.f(0.8, 1.15), y, v.f(24, 31), v.f(14, 18)))
            if v.chance(0.5) { pads.append((cx(y) - side * spread * v.f(0.6, 1.0), y + v.f(3, 9), v.f(20, 27), v.f(12, 16))) }
            side = -side
        }
        for pd in pads.dropFirst() where abs(pd.x - cx(pd.y)) > 10 {    // 伸到两边的团，露一截枝
            let tx = cx(pd.y + 8)
            branch(g, "M \(tx) \(pd.y + 8) Q \((tx + pd.x) / 2) \(pd.y + 6) \(pd.x * 0.85 + tx * 0.15) \(pd.y + 2)", w, width: O * 1.3)
        }
        for (i, pd) in pads.enumerated() {
            var pts: [CGPoint] = []
            let tops: [(CGFloat, CGFloat)] = [(-1, 0), (-0.92, -0.62), (-0.58, -0.88), (-0.28, -1.18), (0.02, -1.06), (0.32, -1.24), (0.62, -0.86), (0.93, -0.6), (1, 0),
                                              (0.5, 0.36), (0, 0.24), (-0.5, 0.36)]
            for (j, (fx, fy)) in tops.enumerated() {
                let jy: CGFloat = (j > 0 && j < 8) ? v.f(-0.1, 0.1) : 0
                pts.append(CGPoint(x: (pd.x + fx * pd.rw) * k, y: (pd.y + (fy + jy) * pd.rh) * k))
            }
            let pad = smooth(pts, closed: true)
            shape(g, pad, fill: base, line: 0)
            light(g, pad, lit: lit, shade: color(0x1F3A28), litH: 0.45, shadeH: 0.28)
            leaves(g, pad, seed: seed + i * 31, dark: C.pineDark, light: color(0x8DB38F), size: max(3, w * 0.05), density: 0.6)
            shape(g, pad, fill: nil)
        }
    }

    /// 圆冠的树（落叶树、樱花树）：分叉的树干，五六团树冠（位置、大小每棵不同），每团右上一块亮，整团左下暗，叶纹。
    static func roundTree(_ g: CGContext, _ w: CGFloat, seed: Int, colors: (UIColor, UIColor, UIColor)) {
        var v = Vary(seed)
        let k = w / 100
        let base = tint(colors.0, &v), lit = tint(colors.1, &v), dark = colors.2
        let lean = v.f(-6, 6)
        shape(g, path("M -5 0 Q -3 -24 \(-12 + lean) -46 L \(-6 + lean) -48 Q \(lean * 0.5) -32 \(2 + lean) -44 L \(8 + lean) -42 Q 5 -22 6 0 Z", w), fill: C.trunk)
        let cy = -64 + v.f(-4, 4), cxp = lean * 0.6
        var puffs: [(CGFloat, CGFloat, CGFloat)] = []
        let n = v.chance(0.5) ? 5 : 6
        let a0 = v.f(0, 2 * .pi)
        for i in 0..<n {
            let a = a0 + CGFloat(i) / CGFloat(n) * 2 * .pi + v.f(-0.25, 0.25)
            puffs.append((cxp + cos(a) * 22 * v.f(0.85, 1.1), cy + 2 + sin(a) * 12 * v.f(0.85, 1.1), v.f(15, 20)))
        }
        puffs.append((cxp + v.f(-5, 5), cy - 14 + v.f(-3, 3), v.f(19, 24)))         // 顶上一团大的
        let blobs = puffs.map { blob($0.0 * k, $0.1 * k, $0.2 * k, $0.2 * 0.9 * k, n: 9, wob: 0.07, v: &v) }
        let canopy = CGMutablePath()
        blobs.forEach { canopy.addPath($0) }
        shape(g, canopy, fill: base, line: 0)
        for (b, (x, y, r)) in zip(blobs, puffs) {
            clipFill(g, b, ellipse((x + r * 0.22) * k, (y - r * 0.34) * k, r * 0.62 * k, r * 0.42 * k), lit)
        }
        let box = canopy.boundingBoxOfPath
        clipFill(g, canopy, ellipse(box.minX + box.width * 0.36, box.maxY, box.width * 0.56, box.height * 0.3), ArtStyle.shade(base, 0.78))
        leaves(g, canopy, seed: seed, dark: dark, light: ArtStyle.mix(lit, .white, 0.3), size: max(3, w * 0.06), density: 0.6)
        blobs.forEach { shape(g, $0, fill: nil, line: D) }
        shape(g, canopy, fill: nil)
    }

    /// 古樟：粗矮的树干（树根往外扒、树皮纹），三股大枝，又宽又大的树冠（八九团），树干上系一条祈福的红布。
    static func bigTree(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        let k = w / 100
        let base = tint(C.leaf, &v, 0.05), lit = tint(C.leafLight, &v, 0.05)
        shape(g, path("M -24 0 Q -13 -3 -11 -14 Q -12 -30 -16 -42 L -6 -46 Q -2 -38 0 -44 L 8 -46 Q 12 -32 11 -14 Q 13 -3 25 0 Z", w), fill: C.trunk)
        line(g, "M -6 -5 Q -4 -20 -8 -34 M 4 -7 Q 6 -22 4 -36 M -15 -2 Q -11 -6 -10 -12 M 16 -2 Q 12 -6 11 -12", w, color: ArtStyle.shade(C.trunk, 0.65))
        branch(g, "M -10 -40 Q -22 -50 -34 -56", w, width: O * 2.2)
        branch(g, "M 7 -42 Q 20 -52 32 -58", w, width: O * 2.2)
        branch(g, "M -1 -44 Q -2 -58 2 -70", w, width: O * 2)
        shape(g, path("M -11.5 -25 Q 0 -22 11.5 -25 L 11.5 -20.5 Q 0 -17.5 -11.5 -20.5 Z", w), fill: C.red, line: D)       // 红布
        shape(g, path("M 1 -20 Q 3 -12 0 -5 L 4 -6 Q 6 -12 5 -20 Z M 5 -20 Q 9 -14 9 -8 L 12 -9 Q 11 -15 8 -20.5 Z", w), fill: C.red, line: D)
        var puffs: [(CGFloat, CGFloat, CGFloat)] = []
        for (x, y, r) in [(-40.0, -62.0, 15.0), (-20, -60, 17), (2, -60, 17), (24, -62, 16), (42, -64, 14),
                          (-30, -80, 20), (-4, -84, 23), (24, -80, 20), (-14, -100, 16), (12, -100, 15)] {
            puffs.append((CGFloat(x) + v.f(-3, 3), CGFloat(y) + v.f(-3, 3), CGFloat(r) * v.f(0.9, 1.1)))
        }
        let blobs = puffs.map { blob($0.0 * k, $0.1 * k, $0.2 * k, $0.2 * 0.88 * k, n: 9, wob: 0.07, v: &v) }
        let canopy = CGMutablePath()
        blobs.forEach { canopy.addPath($0) }
        shape(g, canopy, fill: base, line: 0)
        for (b, (x, y, r)) in zip(blobs, puffs) {
            clipFill(g, b, ellipse((x + r * 0.22) * k, (y - r * 0.34) * k, r * 0.62 * k, r * 0.42 * k), lit)
        }
        let box = canopy.boundingBoxOfPath
        clipFill(g, canopy, ellipse(box.minX + box.width * 0.36, box.maxY, box.width * 0.58, box.height * 0.32), ArtStyle.shade(base, 0.76))
        leaves(g, canopy, seed: seed, dark: C.leafDark, light: ArtStyle.mix(lit, .white, 0.3), size: max(3, w * 0.05), density: 0.6)
        blobs.forEach { shape(g, $0, fill: nil, line: D) }
        shape(g, canopy, fill: nil)
    }

    /// 垂柳：树干往一边歪，树冠一大团，下面垂着一缕缕细长的柳条（条数、长短每棵不同；后排深，前排右边亮、左边暗）。
    static func willow(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        let lean = v.f(-8, 5)
        shape(g, path("M -4 0 Q 2 -36 \(-6 + lean) -70 L \(2 + lean) -72 Q 10 -40 10 0 Z", w), fill: C.trunk)
        line(g, "M 0 -16 Q 3 -36 \(-2 + lean * 0.8) -60", w, color: ArtStyle.shade(C.trunk, 0.7))
        let cx = lean
        shape(g, path("M \(cx - 42) -70 Q \(cx - 40) -110 \(cx) \(-114 + v.f(-4, 4)) Q \(cx + 40) -112 \(cx + 44) -74 Q \(cx + 22) -88 \(cx) -88 Q \(cx - 22) -88 \(cx - 42) -70 Z", w),
              fill: tint(C.willowB, &v))
        for layer in 0..<2 {
            let count = 10 + Int(v.f(0, 2.99))
            for i in 0..<count {
                let x = cx - 44 + CGFloat(i) * 88 / CGFloat(count - 1) + (layer == 0 ? 4 : 0) + v.f(-1.5, 1.5)
                let len = (layer == 0 ? 50 : 58) + v.f(0, 22)
                let top = (layer == 0 ? -100 : -92) + v.f(-3, 3), sway = v.f(-3, 3)
                let c = layer == 0 ? C.willowC : (x > cx ? C.willowA : C.willowB)
                let d = "M \(x - 4) \(top) Q \(x - 5 + sway) \(top + len * 0.55) \(x + 1 + sway * 1.5) \(top + len) Q \(x + 5 + sway) \(top + len * 0.5) \(x + 4) \(top) Z"
                shape(g, path(d, w), fill: c, line: D)
                line(g, "M \(x) \(top + 4) Q \(x - 1 + sway) \(top + len * 0.5) \(x + 1 + sway * 1.4) \(top + len - 5)", w, width: D * 0.8, color: C.willowDark)
            }
        }
    }

    /// 灌木：一团圆顶（高矮、歪向每丛不同），右上亮、左下暗，叶纹；有的开几朵小花。
    static func bush(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        let k = w / 100
        let p = dome(48 * k, v.f(26, 36) * k, n: 7, wob: 0.16, v: &v, lean: v.f(-0.15, 0.15))
        shape(g, p, fill: tint(C.bush, &v), line: 0)
        light(g, p, lit: tint(C.bushLight, &v), shade: C.leafDark, litH: 0.45, shadeH: 0.28)
        leaves(g, p, seed: seed, dark: C.leafDark, light: color(0x9CC27A), size: max(2.5, w * 0.12), density: 0.7)
        if v.chance(0.35) {
            let petal = v.pick([UIColor.white, C.pink, color(0xF6E27A)])
            for _ in 0..<3 { flower(g, CGPoint(x: v.f(-0.3, 0.3) * w, y: v.f(-0.26, -0.08) * w), size: w * 0.05, petal: petal) }
        }
        shape(g, p, fill: nil)
    }

    /// 花丛：几片叶子，五六朵白、粉、黄的小花。
    static func flowerBed(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var r = Rand(seed)
        for _ in 0..<5 {
            let x = r.range(-0.4, 0.4) * w, y = r.range(-0.25, 0) * w
            shape(g, ellipse(x, y, w * 0.1, w * 0.05), fill: C.leaf, line: D * 0.8)
        }
        let petals = [UIColor.white, C.pink, color(0xF6E27A)]
        for _ in 0..<6 {
            let x = r.range(-0.4, 0.4) * w, y = r.range(-0.45, -0.05) * w
            flower(g, CGPoint(x: x, y: y), size: w * 0.075, petal: petals[Int(r.next() * 2.99)])
        }
    }

    static func flower(_ g: CGContext, _ c: CGPoint, size s: CGFloat, petal: UIColor) {
        let petals = CGMutablePath()
        for k in 0..<5 {
            let a = CGFloat(k) * .pi * 2 / 5 - .pi / 2
            petals.addEllipse(in: CGRect(x: c.x + cos(a) * s - s * 0.72, y: c.y + sin(a) * s - s * 0.72, width: s * 1.44, height: s * 1.44))
        }
        g.addPath(petals); g.setStrokeColor(ink.cgColor); g.setLineWidth(D * 1.2); g.strokePath()   // 先描粗边再填，花瓣之间不留线
        g.addPath(petals); g.setFillColor(petal.cgColor); g.fillPath()
        g.addPath(ellipse(c.x, c.y, s * 0.5, s * 0.5)); g.setFillColor(color(0xE9B949).cgColor); g.fillPath()
    }

    // MARK: 石头

    /// 石头的身子：右上一块亮面，左下暗面（网点）。
    static func stoneBody(_ g: CGContext, _ p: CGPath, _ v: inout Vary) {
        let box = p.boundingBoxOfPath
        shape(g, p, fill: tint(C.rock, &v, 0.05), line: 0)
        clipFill(g, p, ellipse(box.midX + box.width * 0.22, box.minY + box.height * 0.16, box.width * 0.42, box.height * 0.36), C.rockLight)
        let shade = ellipse(box.minX + box.width * 0.16, box.maxY, box.width * 0.46, box.height * 0.62)
        clipFill(g, p, shade, C.rockShade)
        g.saveGState(); g.addPath(p); g.clip(); dots(g, shade); g.restoreGState()
    }

    /// 大石：圆顶不规则（每块歪向、棱角不同），右上亮、左下暗，顶上常有一块青苔，一两道裂纹。
    static func rock(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        let k = w / 100
        let p = dome(48 * k, v.f(42, 60) * k, n: 6, wob: 0.16, v: &v, lean: v.f(-0.3, 0.3))
        let box = p.boundingBoxOfPath
        stoneBody(g, p, &v)
        if v.chance(0.7) {
            let moss = blob(box.midX + v.f(-0.15, 0.1) * box.width, box.minY + box.height * 0.1, box.width * v.f(0.22, 0.3), box.height * 0.13, n: 8, wob: 0.25, v: &v)
            clipFill(g, p, moss, C.moss)
            g.saveGState(); g.addPath(p); g.clip(); shape(g, moss, fill: nil, line: D); g.restoreGState()
        }
        let cx = box.midX + v.f(0.05, 0.25) * box.width, cy = box.minY + box.height * 0.3
        g.move(to: CGPoint(x: cx, y: cy)); g.addLine(to: CGPoint(x: cx + v.f(2, 6) * k, y: cy + box.height * 0.25))
        g.addLine(to: CGPoint(x: cx + v.f(-3, 2) * k, y: cy + box.height * 0.5))
        g.setStrokeColor(ink.cgColor); g.setLineWidth(D); g.strokePath()
        shape(g, p, fill: nil)
    }

    /// 摩崖石：高高的一块立石，正面磨平一块（不刻字，红框），石缝里长出一小丛松。
    static func carvedRock(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        let k = w / 100
        let p = dome(46 * k, v.f(68, 78) * k, n: 7, wob: 0.1, v: &v, lean: v.f(-0.12, 0.12))
        stoneBody(g, p, &v)
        let panel = CGPath(roundedRect: R(w, -15, -56, 30, 38), cornerWidth: 2 * k, cornerHeight: 2 * k, transform: nil)
        shape(g, panel, fill: ArtStyle.mix(C.rockLight, .white, 0.25), line: D)
        shape(g, CGPath(roundedRect: R(w, -12, -53, 24, 32), cornerWidth: 1.5 * k, cornerHeight: 1.5 * k, transform: nil), fill: nil, line: D, stroke: C.red)
        branch(g, "M -30 -54 Q -38 -62 -44 -64", w, width: O)
        for (x, y, rw) in [(-46.0, -64.0, 11.0), (-36, -70, 9.0)] {
            let pad = blob(CGFloat(x) * k, CGFloat(y) * k, CGFloat(rw) * k, CGFloat(rw) * 0.55 * k, n: 8, wob: 0.18, v: &v)
            shape(g, pad, fill: C.pine, line: 0)
            light(g, pad, lit: C.pineLight, shade: color(0x1F3A28))
            shape(g, pad, fill: nil, line: D)
        }
        shape(g, p, fill: nil)
    }

    // MARK: 地上的小东西

    /// 几丛小草（深色为主，偶尔一根浅色）。
    static func tufts(_ g: CGContext, _ w: CGFloat, seed: Int) {
        line(g, "M -26 0 L -30 -12 M -26 0 L -24 -15 M -26 0 L -19 -11 M 6 0 L 2 -11 M 6 0 L 8 -15 M 6 0 L 13 -10", w, width: D, color: C.grassDark)
        if seed % 3 == 0 { line(g, "M 30 0 L 28 -12 M 30 0 L 35 -10", w, width: D, color: C.grassLight) }
    }

    /// 几朵小花（白、粉，黄心）。
    static func flowers(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var r = Rand(seed)
        for _ in 0..<3 {
            let x = r.range(-0.35, 0.35) * w, y = r.range(-0.3, 0) * w
            flower(g, CGPoint(x: x, y: y), size: w * 0.08, petal: r.next() < 0.55 ? .white : C.pink)
        }
    }

    static func pebbles(_ g: CGContext, _ w: CGFloat) {
        for (x, y, rx) in [(-0.3, -0.04, 0.14), (0.05, 0.0, 0.1), (0.3, -0.06, 0.12)] {
            shape(g, ellipse(CGFloat(x) * w, CGFloat(y) * w, CGFloat(rx) * w, CGFloat(rx) * w * 0.6), fill: C.rockLight, line: D)
        }
    }

    /// 一串踏脚石。
    static func steppingStones(_ g: CGContext, _ w: CGFloat) {
        for (x, y) in [(-0.36, 0.0), (-0.1, -0.08), (0.14, -0.04), (0.38, -0.12)] {
            shape(g, ellipse(CGFloat(x) * w, CGFloat(y) * w, w * 0.11, w * 0.05), fill: C.stoneLight, line: D)
        }
    }

    // MARK: 茶园

    /// 茶垄的弧线：中间拱起 sag，右端比左端低 tilt。
    static func arcY(_ x: CGFloat, _ w: CGFloat, _ sag: CGFloat, _ tilt: CGFloat) -> CGFloat {
        let u = 2 * x / w
        return -sag * (1 - u * u) + tilt * u * 0.5
    }

    /// 一垄茶：顺着弧线的细长带子，两头收圆，上沿一个个浅浅的鼓包；上半截浅、下沿深，满是细叶纹，顶上几道高光。
    static func teaRow(_ g: CGContext, _ w: CGFloat, rh: CGFloat, sag: CGFloat, tilt: CGFloat, seed: Int) {
        var top: [CGPoint] = [], bottom: [CGPoint] = [], mid: [CGPoint] = []
        let cap = rh * 0.7, bw = rh * 1.35
        var x = -w / 2
        while x <= w / 2 + 0.01 {
            let e = max(0, abs(x) - (w / 2 - cap)) / cap
            let k = sqrt(max(0, 1 - e * e))
            let m = arcY(x, w, sag, tilt) - rh / 2
            let bump = abs(sin((x + w / 2) / bw * .pi)) * rh * 0.14
            top.append(CGPoint(x: x, y: m - (rh / 2 + bump) * k))
            bottom.append(CGPoint(x: x, y: m + rh / 2 * k))
            mid.append(CGPoint(x: x, y: m - rh * 0.12 * k))
            x += 1.5
        }
        let body = CGMutablePath()
        body.addLines(between: bottom + top.reversed())
        body.closeSubpath()
        let upper = CGMutablePath()
        upper.addLines(between: top + mid.reversed())
        upper.closeSubpath()
        let lower = CGMutablePath()
        lower.addLines(between: bottom + bottom.reversed().map { CGPoint(x: $0.x, y: $0.y - rh * 0.28) })
        lower.closeSubpath()
        shape(g, body, fill: C.teaMid, line: 0)
        g.saveGState(); g.addPath(body); g.clip()
        g.addPath(upper); g.setFillColor(C.teaLight.cgColor); g.fillPath()
        g.addPath(lower); g.setFillColor(C.teaDark.cgColor); g.fillPath()
        g.restoreGState()
        leaves(g, body, seed: seed, dark: C.teaDeep, light: C.teaHi, size: rh * 0.32, density: 0.55)
        g.setStrokeColor(C.teaHi.cgColor); g.setLineWidth(D)            // 鼓包顶的高光
        var bx = -w / 2 + bw * 0.5
        while bx < w / 2 - cap {
            let i = min(top.count - 1, max(0, Int((bx + w / 2) / 1.5)))
            let p = top[i]
            g.move(to: CGPoint(x: p.x - bw * 0.25, y: p.y + rh * 0.2))
            g.addQuadCurve(to: CGPoint(x: p.x + bw * 0.2, y: p.y + rh * 0.18), control: CGPoint(x: p.x, y: p.y + rh * 0.05))
            bx += bw
        }
        g.strokePath()
        shape(g, body, fill: nil)
    }

    /// 石砌挡墙：顺着同一条弧线的一道墙，两层大小不一的乱石。
    static func stoneWall(_ g: CGContext, _ w: CGFloat, wh: CGFloat, sag: CGFloat, tilt: CGFloat, seed: Int) {
        var r = Rand(seed)
        var topPts: [CGPoint] = [], botPts: [CGPoint] = []
        var x = -w / 2
        while x <= w / 2 + 0.01 { let y = arcY(x, w, sag, tilt); topPts.append(CGPoint(x: x, y: y - wh)); botPts.append(CGPoint(x: x, y: y)); x += 3 }
        let band = CGMutablePath()
        band.addLines(between: botPts + topPts.reversed())
        band.closeSubpath()
        shape(g, band, fill: C.stoneShade, line: 0)
        for course in 0..<2 {
            var sx = -w / 2 + (course == 1 ? r.range(2, 6) : 0)
            while sx < w / 2 - 2 {
                let sw = min(r.range(7, 13), w / 2 - sx)
                let cx = sx + sw / 2
                let y0 = arcY(cx, w, sag, tilt)
                let slope = (arcY(cx + 1, w, sag, tilt) - arcY(cx - 1, w, sag, tilt)) / 2
                let ch = wh / 2
                let cy = y0 - ch * (CGFloat(course) + 0.5)
                g.saveGState()
                g.translateBy(x: cx, y: cy)
                g.rotate(by: atan(slope))
                let stoneRect = CGRect(x: -sw / 2 + 0.6, y: -ch / 2 + 0.5, width: sw - 1.2, height: ch - 1)
                let sp = CGPath(roundedRect: stoneRect, cornerWidth: min(2.5, ch / 2 - 0.6), cornerHeight: min(2.5, ch / 2 - 0.6), transform: nil)
                shape(g, sp, fill: r.next() < 0.5 ? C.stone : C.stoneLight, line: D)
                g.restoreGState()
                sx += sw
            }
        }
        shape(g, band, fill: nil, line: D)
    }

    /// 一片茶园梯田：从上往下一垄垄茶，每两垄一道乱石墙；越往下（越近）的画在越上面。
    /// 整片顺着山势：中间宽、两头窄（一垄垄长短不一），每垄弯成弧；默认右端对齐（靠路那头齐，外头参差），flip 后左端对齐。
    static func terraces(_ g: CGContext, _ w: CGFloat, _ h: CGFloat, seed: Int) {
        var r = Rand(seed)
        let rh: CGFloat = 14, wh: CGFloat = 10
        let tilt = r.range(5, 10)
        var y = -h + rh
        var k = 0
        while y <= 0 {
            let t = (y + h) / h                                           // 0 = 最上面一垄，1 = 最下面
            let env = 0.72 + 0.28 * sin(.pi * (0.1 + 0.9 * t))
            let rowW = w * env * r.range(0.94, 1.0)
            let cx = w / 2 - rowW / 2 - r.range(0, 4)                    // 右端对齐（靠路），左端参差
            let sag = rowW * r.range(0.05, 0.08)
            g.saveGState(); g.translateBy(x: cx, y: y)
            teaRow(g, rowW, rh: rh, sag: sag, tilt: tilt, seed: seed + k * 7)
            g.restoreGState()
            if k % 2 == 1 && y + wh <= 0 {
                g.saveGState(); g.translateBy(x: cx + rowW * 0.015, y: y + wh - 1)
                stoneWall(g, rowW * 0.95, wh: wh, sag: sag, tilt: tilt, seed: seed + k * 13)
                g.restoreGState()
                y += wh - 1
            }
            y += rh * 0.86
            k += 1
        }
    }

    // MARK: 水

    /// 小溪：从底边往上弯弯曲曲一段（height 是长度，width 是溪宽），中间一道浅色水光，几道白浪，两岸的石头。
    static func stream(_ g: CGContext, _ w: CGFloat, _ h: CGFloat) {
        let half = w / 2
        let pts = stride(from: CGFloat(0), through: 1, by: 0.05).map { f in CGPoint(x: sin(f * 5) * half * 0.7, y: -f * h) }
        let p = CGMutablePath()
        p.addLines(between: pts.map { CGPoint(x: $0.x - half, y: $0.y) } + pts.reversed().map { CGPoint(x: $0.x + half, y: $0.y) })
        p.closeSubpath()
        shape(g, p, fill: C.water, line: 0)
        let glint = CGMutablePath()
        glint.addLines(between: pts.map { CGPoint(x: $0.x - half * 0.25, y: $0.y) } + pts.reversed().map { CGPoint(x: $0.x + half * 0.15, y: $0.y) })
        glint.closeSubpath()
        shape(g, glint, fill: C.waterLight, line: 0)
        g.setStrokeColor(UIColor.white.cgColor); g.setLineWidth(D)
        for (k, q) in pts.enumerated() where k % 2 == 1 {
            let dx: CGFloat = k % 4 == 1 ? -half * 0.3 : half * 0.25
            g.move(to: CGPoint(x: q.x + dx - 5, y: q.y)); g.addQuadCurve(to: CGPoint(x: q.x + dx + 5, y: q.y), control: CGPoint(x: q.x + dx, y: q.y - 3))
        }
        g.strokePath()
        shape(g, p, fill: nil)
        for (k, q) in pts.enumerated() where k % 3 == 0 {
            let side: CGFloat = k % 2 == 0 ? -1 : 1
            let rp = ellipse(q.x + side * half * 0.98, q.y, half * 0.36, half * 0.22)
            shape(g, rp, fill: C.rock, line: 0)
            band(g, rp, CGRect(x: q.x + side * half * 0.98 - half * 0.4, y: q.y + half * 0.04, width: half * 0.8, height: half * 0.2), C.rockShade)
            shape(g, rp, fill: nil)
        }
    }
}
