import UIKit

/// 景物库的房子和物件：镇上的瓦房、茶馆、铁匠铺，茶园的茅屋、茶摊，山上的凉亭、山门，路边的小东西。
/// 同一种房子按种子换着屋顶、墙、门窗和门口的小物件，不会一模一样。坐标都按宽 100 的单位（底边中点为原点）。
extension Landmarks {
    // MARK: 院子里的东西

    /// 木篱笆：尖头桩高低不齐、略歪，两道横档微微下垂。
    static func fence(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        let wood = tint(C.woodLight, &v)
        let sag = v.f(0, 2.5)
        shape(g, path("M -50 -12 Q 0 \(-12 + sag) 50 -12 L 50 -8 Q 0 \(-8 + sag) -50 -8 Z M -50 -24 Q 0 \(-24 + sag) 50 -24 L 50 -20 Q 0 \(-20 + sag) -50 -20 Z", w),
              fill: wood, line: D)
        var x: CGFloat = -46
        while x <= 46 {
            let h = v.f(26, 31), lean = v.f(-1.5, 1.5)
            shape(g, path("M \(x - 3) 0 L \(x + 3) 0 L \(x + 3 + lean) \(-h) L \(x + lean) \(-h - 3) L \(x - 3 + lean) \(-h) Z", w), fill: wood, line: D)
            line(g, "M \(x - 1) -4 L \(x - 1 + lean) \(-h + 2)", w, width: D * 0.6, color: ArtStyle.shade(wood, 0.7))
            x += v.f(10.5, 13)
        }
    }

    /// 竹篓：一两只（大小不一），有的装满刚采的茶叶。
    static func basket(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        let xs: [CGFloat] = v.chance(0.35) ? [0] : [-24, 22]
        for x in xs {
            let s = v.f(0.85, 1.1), top = -40 * s, hw = 18 * s, bw = 14 * s
            let reed = tint(color(0xC9A15A), &v, 0.05)
            shape(g, path("M \(x - hw) \(top) L \(x + hw) \(top) L \(x + bw) 0 L \(x - bw) 0 Z", w), fill: reed, line: D)
            var d = ""
            for f in [0.2, 0.4, 0.6, 0.8] as [CGFloat] { let y = top * (1 - f), hx = bw + (hw - bw) * (1 - f) - 1; d += "M \(x - hx) \(y) L \(x + hx) \(y) " }
            d += "M \(x - 8 * s) \(top) L \(x - 6 * s) 0 M \(x) \(top) L \(x) 0 M \(x + 8 * s) \(top) L \(x + 6 * s) 0"
            line(g, d, w, width: D * 0.7, color: color(0x8A6A2E))
            if v.chance(0.6) {                                                  // 一篓茶叶
                let heap = path("M \(x - hw * 0.92) \(top) Q \(x - hw * 0.55) \(top - 9 * s) \(x) \(top - 10 * s) Q \(x + hw * 0.55) \(top - 9 * s) \(x + hw * 0.92) \(top) Z", w)
                shape(g, heap, fill: C.teaLight, line: 0)
                leaves(g, heap, seed: seed &+ Int(x), dark: C.teaDark, light: C.teaHi, size: max(1.6, w * 0.06), density: 0.9)
                shape(g, heap, fill: nil, line: D)
            }
            shape(g, E(w, x, top, hw, 4 * s), fill: color(0xB08A45), line: D)
        }
    }

    /// 柴堆：一摞木头的截面。
    static func firewood(_ g: CGContext, _ w: CGFloat) {
        for (x, y) in [(-26.0, -12.0), (0, -12), (26, -12), (-13, -34), (13, -34), (0, -56)] {
            shape(g, E(w, CGFloat(x), CGFloat(y), 12, 11), fill: color(0xC9A27A), line: D)
            g.addPath(E(w, CGFloat(x), CGFloat(y), 5, 4.5))
            g.setStrokeColor(color(0x8A6A4A).cgColor); g.setLineWidth(D * 0.7); g.strokePath()
        }
    }

    /// 水井：乱石井栏、两根柱子撑一个小瓦顶、吊一只木桶。
    static func well(_ g: CGContext, _ w: CGFloat) {
        shape(g, path("M -30 -70 L -26 -70 L -26 -28 L -30 -28 Z M 26 -70 L 30 -70 L 30 -28 L 26 -28 Z", w), fill: C.wood, line: D)
        let roof = path("M -46 -66 L -24 -88 L 24 -88 L 46 -66 L 40 -62 L -40 -62 Z", w)
        tiles(g, roof, w, spacing: 4)
        shape(g, roof, fill: nil)
        line(g, "M 0 -62 L 0 -46", w)
        shape(g, path("M -7 -46 L 7 -46 L 6 -34 L -6 -34 Z", w), fill: C.woodLight, line: D)
        let body = path("M -34 0 L 34 0 L 34 -30 L -34 -30 Z", w)
        shape(g, body, fill: C.stone, line: 0)
        line(g, "M -34 -10 L 34 -10 M -34 -20 L 34 -20 M -22 -30 L -22 -20 M -2 -30 L -2 -20 M 18 -30 L 18 -20 M -12 -20 L -12 -10 M 8 -20 L 8 -10 M 26 -20 L 26 -10 M -24 -10 L -24 0 M 0 -10 L 0 0 M 20 -10 L 20 0", w,
             color: C.stoneShade)
        dots(g, path("M -34 0 L -22 0 L -22 -30 L -34 -30 Z", w), alpha: 0.18)
        shape(g, body, fill: nil)
        shape(g, E(w, 0, -30, 34, 7), fill: color(0x5B5348))
    }

    /// 水缸：大肚陶缸（右上一道高光、左下暗），缸口一汪清水，半盖着木盖，搭一只瓢。
    static func waterVat(_ g: CGContext, _ w: CGFloat) {
        let glaze = color(0x6E4A33)
        let body = path("M -30 -56 Q -48 -34 -32 -6 Q -28 0 -20 0 L 20 0 Q 28 0 32 -6 Q 48 -34 30 -56 Z", w)
        shape(g, body, fill: glaze, line: 0)
        clipFill(g, body, E(w, -30, -8, 26, 42), ArtStyle.shade(glaze, 0.75))
        line(g, "M 24 -48 Q 36 -34 28 -14", w, width: 3 * w / 100, color: ArtStyle.mix(glaze, .white, 0.3))
        shape(g, body, fill: nil)
        shape(g, E(w, 0, -56, 31, 6), fill: ArtStyle.shade(glaze, 0.7), line: D)
        shape(g, E(w, 0, -56, 27, 4.4), fill: C.water, line: D * 0.7)
        line(g, "M 4 -57 Q 10 -58 16 -56.5", w, width: D, color: .white)
        shape(g, path("M -32 -57 Q -14 -64 4 -61 L 2 -55.5 Q -14 -58 -31 -53 Z", w), fill: C.woodLight, line: D)
        line(g, "M 14 -60 L 34 -72", w, width: O * 1.6, color: C.woodDark)
        shape(g, E(w, 12, -59, 6, 3), fill: C.bamboo, line: D)
    }

    /// 晾衣竿：两根竹竿拉一根绳，挂着几件衣裳和布（颜色每家不同），下摆往一边飘。
    static func laundry(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        shape(g, path("M -46 0 L -42 0 L -42 -54 L -46 -54 Z M 42 0 L 46 0 L 46 -54 L 42 -54 Z", w), fill: C.bamboo, line: D)
        line(g, "M -44 -48 Q 0 -36 44 -48", w, width: D)
        func ropeY(_ x: CGFloat) -> CGFloat { let u = x / 44; return -48 + 6 * (1 - u * u) }
        let cloths = [color(0x3B5E8C), color(0xF4EFE4), C.red, color(0x9CC3D5), color(0xD9A441)]
        var x: CGFloat = -38
        while x < 32 {
            let cw = v.f(12, 18), ch = v.f(16, 26), sway = v.f(1, 4)
            let x0 = x, x1 = min(40, x + cw), y0 = ropeY(x0), y1 = ropeY(x1)
            let c = v.pick(cloths)
            let p = path("M \(x0) \(y0) L \(x1) \(y1) Q \(x1 + sway * 0.5) \(y1 + ch * 0.5) \(x1 + sway) \(y1 + ch) Q \((x0 + x1) / 2 + sway) \(y1 + ch - 2) \(x0 + sway) \(y0 + ch) Q \(x0 + sway * 0.4) \(y0 + ch * 0.5) \(x0) \(y0) Z", w)
            shape(g, p, fill: c, line: 0)
            clipFill(g, p, path("M \(x0 - 2) \(y0) L \(x0 + cw * 0.3) \(y0) L \(x0 + cw * 0.3 + sway) \(y0 + ch + 2) L \(x0 - 2) \(y0 + ch + 2) Z", w), ArtStyle.shade(c, 0.85))
            if v.chance(0.4) { clipFill(g, p, path("M \(x0 - 2) \(y0 + ch * 0.55) L \(x1 + 6) \(y1 + ch * 0.55) L \(x1 + 6) \(y1 + ch * 0.68) L \(x0 - 2) \(y0 + ch * 0.68) Z", w), c == C.red ? C.gold : C.red) }
            shape(g, p, fill: nil, line: D)
            shape(g, path("M \(x0 + 1) \(y0 - 2) L \(x0 + 3) \(y0 - 2) L \(x0 + 3) \(y0 + 3) L \(x0 + 1) \(y0 + 3) Z M \(x1 - 3) \(y1 - 2) L \(x1 - 1) \(y1 - 2) L \(x1 - 1) \(y1 + 3) L \(x1 - 3) \(y1 + 3) Z", w),
                  fill: C.woodDark, line: 0)
            x = x1 + v.f(2, 5)
        }
    }

    /// 板车：木板车身、一只大轮、两根车把斜搭在地上，车上两只麻袋。
    static func cart(_ g: CGContext, _ w: CGFloat) {
        let k = w / 100
        shape(g, path("M -50 -4 L -20 -22 L -18 -19 L -48 -1 Z", w), fill: C.wood, line: D)
        shape(g, path("M -26 -26 L 44 -26 L 44 -20 L -26 -20 Z", w), fill: C.woodLight, line: D)
        line(g, "M -12 -26 L -12 -20 M 4 -26 L 4 -20 M 20 -26 L 20 -20 M 34 -26 L 34 -20", w, width: D * 0.8, color: C.woodDark)
        for (x, h) in [(-6.0, 22.0), (22.0, 18.0)] as [(CGFloat, CGFloat)] {
            let sack = path("M \(x - 12) -26 Q \(x - 15) \(-30 - h * 0.4) \(x - 8) \(-26 - h) Q \(x) \(-30 - h) \(x + 8) \(-26 - h) Q \(x + 15) \(-30 - h * 0.4) \(x + 12) -26 Z", w)
            shape(g, sack, fill: C.cloth, line: 0)
            clipFill(g, sack, E(w, x - 12, -26, 10, h), ArtStyle.shade(C.cloth, 0.85))
            shape(g, sack, fill: nil, line: D)
            line(g, "M \(x - 6) \(-22 - h) Q \(x) \(-20 - h) \(x + 6) \(-22 - h)", w, width: D, color: C.woodDark)
        }
        let c = CGPoint(x: 10 * k, y: -15 * k), r = 15 * k
        let ring = ellipse(c.x, c.y, r, r)
        g.addPath(ring); g.setStrokeColor(ink.cgColor); g.setLineWidth(3 * k + 2 * O); g.strokePath()
        g.addPath(ring); g.setStrokeColor(C.wood.cgColor); g.setLineWidth(3 * k); g.strokePath()
        g.setStrokeColor(C.woodDark.cgColor); g.setLineWidth(D * 1.2)
        for i in 0..<6 {
            let a = CGFloat(i) / 6 * .pi * 2
            g.move(to: c); g.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.9, y: c.y + sin(a) * r * 0.9))
        }
        g.strokePath()
        shape(g, ellipse(c.x, c.y, 3 * k, 3 * k), fill: C.woodDark, line: D)
    }

    /// 长凳。
    static func bench(_ g: CGContext, _ w: CGFloat) {
        shape(g, path("M -44 0 L -38 0 L -34 -12 L -38 -12 Z M 44 0 L 38 0 L 34 -12 L 38 -12 Z", w), fill: C.wood, line: D)
        shape(g, path("M -48 -12 L 48 -12 L 48 -16 L -48 -16 Z", w), fill: C.woodLight, line: D)
    }

    /// 茶壶（青花白瓷）：x、y 是壶底中点，s 是大小倍数。
    static func teapot(_ g: CGContext, _ w: CGFloat, x: CGFloat, y: CGFloat, s: CGFloat) {
        shape(g, path("M \(x + 4 * s) \(y - 3 * s) L \(x + 11 * s) \(y - 10 * s) L \(x + 12.5 * s) \(y - 9 * s) L \(x + 6 * s) \(y - 1.5 * s) Z", w), fill: C.porcelain, line: D)
        line(g, "M \(x - 5 * s) \(y - 7.5 * s) Q \(x - 11 * s) \(y - 6 * s) \(x - 5 * s) \(y - 2 * s)", w, width: O * 1.3)
        shape(g, E(w, x, y - 4.5 * s, 6.5 * s, 4.5 * s), fill: C.porcelain, line: D)
        line(g, "M \(x - 6 * s) \(y - 4.5 * s) Q \(x) \(y - 3 * s) \(x + 6 * s) \(y - 4.5 * s)", w, width: D * 1.2, color: C.blueGlaze)
        shape(g, E(w, x, y - 9 * s, 3.5 * s, 1.3 * s), fill: C.porcelain, line: D * 0.8)
        shape(g, E(w, x, y - 10.6 * s, 1.2 * s, 1.1 * s), fill: C.blueGlaze, line: 0)
    }

    /// 茶摊：两根竹竿撑一块布篷（篷面红白条，前沿一排波浪边），篷下一张矮桌（茶壶、茶碗），旁边一只小泥炉坐着水壶冒热气。
    static func teaStall(_ g: CGContext, _ w: CGFloat) {
        shape(g, path("M -44 0 L -40 0 L -40 -62 L -44 -62 Z M 40 0 L 44 0 L 44 -62 L 40 -62 Z", w), fill: C.bamboo, line: D)
        line(g, "M -44 -20 L -40 -20 M -44 -40 L -40 -40 M 40 -20 L 44 -20 M 40 -40 L 44 -40", w, width: D, color: ArtStyle.shade(C.bamboo, 0.7))
        shape(g, path("M -29 -18 L -26 -18 L -26 0 L -29 0 Z M 2 -18 L 5 -18 L 5 0 L 2 0 Z", w), fill: C.wood, line: D)
        shape(g, path("M -32 -22 L 8 -22 L 8 -18 L -32 -18 Z", w), fill: C.woodLight, line: D)
        teapot(g, w, x: -19, y: -22, s: 1)
        shape(g, path("M -7 -22 L -1 -22 L 0 -27 L -8 -27 Z M 1 -22 L 7 -22 L 8 -27 L 0 -27 Z", w), fill: C.porcelain, line: D)
        shape(g, path("M 16 0 L 34 0 L 32 -16 L 18 -16 Z", w), fill: color(0xA9714B), line: D)                  // 泥炉
        shape(g, path("M 21 -3 L 29 -3 L 29 -9 Q 25 -12 21 -9 Z", w), fill: color(0xF29A3A), line: D)
        line(g, "M 31 -22 L 37 -27", w, width: O * 1.4, color: ink)
        shape(g, E(w, 25, -21, 7.5, 5), fill: color(0x5B5348), line: D)                                      // 水壶
        line(g, "M 20 -25 Q 25 -33 30 -25", w, width: D)
        line(g, "M 37 -31 Q 34 -37 38 -43 Q 42 -49 38 -55", w, width: D * 1.4, color: UIColor.white.withAlphaComponent(0.9))
        let roof = path("M -50 -60 L 50 -60 L 44 -74 L -44 -74 Z", w)                                        // 布篷
        shape(g, roof, fill: C.cloth, line: 0)
        var d = ""
        var x: CGFloat = -44
        while x < 44 { d += "M \(x) -74 L \(x + 8) -74 L \(x + 8 * 1.14 + 1) -60 L \(x * 1.14) -60 Z "; x += 16 }
        clipFill(g, roof, path(d, w), C.red)
        clipFill(g, roof, path("M -50 -60 L 50 -60 L 48 -64 L -48 -64 Z", w), UIColor.black.withAlphaComponent(0.12))
        shape(g, roof, fill: nil, line: D)
        var v = "M -50 -60 L 50 -60 L 50 -56"
        x = 50
        while x > -50 { v += " Q \(x - 5) -51 \(x - 10) -56"; x -= 10 }
        v += " Z"
        shape(g, path(v, w), fill: C.red, line: D)
    }

    /// 晒茶：矮竹架上摆两三只圆竹匾，摊着刚采的茶叶。
    static func dryingRack(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        let n = v.chance(0.5) ? 2 : 3
        shape(g, path("M -42 0 L -39 0 L -39 -9 L -42 -9 Z M 39 0 L 42 0 L 42 -9 L 39 -9 Z M -2 0 L 1 0 L 1 -9 L -2 -9 Z", w), fill: C.bamboo, line: D)
        shape(g, path("M -46 -9 L 46 -9 L 46 -12 L -46 -12 Z", w), fill: C.bamboo, line: D)
        let span = 92 / CGFloat(n)
        for i in 0..<n {
            let x = -46 + span * (CGFloat(i) + 0.5) + v.f(-2, 2)
            let rx = span * 0.5, ry = rx * 0.32
            shape(g, E(w, x, -14, rx, ry), fill: C.bamboo, line: D)
            let inner = E(w, x, -14.4, rx * 0.84, ry * 0.74)
            shape(g, inner, fill: tint(C.teaLight, &v, 0.06), line: D * 0.7)
            leaves(g, inner, seed: seed + i * 5, dark: C.teaDark, light: C.teaHi, size: max(1.6, w * 0.035), density: 0.9)
        }
    }

    /// 长幡：石座上一根高旗杆，顶上挑一面窄长的红幡（金边、下摆分叉），顺风往右飘（flip 往左）。
    static func flags(_ g: CGContext, _ w: CGFloat) {
        let pole = color(0x4A3426)
        shape(g, path("M -16 0 L 16 0 L 12 -10 L -12 -10 Z", w), fill: C.stoneLight, line: D)
        shape(g, path("M -2.5 -10 L 2.5 -10 L 2 -232 L -2 -232 Z", w), fill: pole, line: D)
        shape(g, E(w, 0, -236, 4, 4), fill: C.gold, line: D)
        line(g, "M 0 -222 L 36 -224", w, width: O * 1.4, color: pole)
        let banner = path("M 4 -222 L 34 -224 Q 40 -190 34 -160 Q 28 -130 38 -102 L 26 -110 L 20 -96 Q 12 -128 8 -160 Q 2 -190 4 -222 Z", w)
        shape(g, banner, fill: C.red, line: 0)
        clipFill(g, banner, path("M 0 -230 L 14 -230 Q 16 -190 18 -160 Q 22 -128 26 -90 L 0 -90 Z", w), ArtStyle.shade(C.red, 0.82))
        g.saveGState(); g.addPath(banner); g.clip()
        g.addPath(banner); g.setStrokeColor(C.gold.cgColor); g.setLineWidth(5 * w / 100); g.strokePath()
        g.restoreGState()
        shape(g, E(w, 20, -194, 6, 6), fill: nil, line: D * 1.4, stroke: C.gold)
        shape(g, E(w, 20, -194, 2.4, 2.4), fill: C.gold, line: 0)
        shape(g, banner, fill: nil)
    }

    // MARK: 房子

    /// 瓦：屋顶里一列列瓦垄（从屋脊往檐口微微张开；给了 shear 就改成顺着进深方向往右上斜），每垄一片片瓦（本色，左边一道高光），
    /// 瓦缝露出深色底。几百片瓦攒成一条路径，填一次、描一次。
    static func tiles(_ g: CGContext, _ roof: CGPath, _ w: CGFloat, spacing: CGFloat, base: UIColor = C.roof, dark: UIColor = C.roofDark, light: UIColor = C.roofLight,
                      shear: CGFloat? = nil) {
        let box = roof.boundingBoxOfPath
        let s = spacing * w / 100, c = s * 1.3
        let pieces = CGMutablePath(), shine = CGMutablePath()
        var y = box.minY
        while y < box.maxY {
            let mid = y + c / 2
            let spread = shear == nil ? 0.72 + 0.28 * min(1, (mid - box.minY) / box.height) : 1
            let shift = (shear ?? 0) * (box.maxY - mid)
            for k in Int(((-s - shift) / s).rounded(.down))...Int(((box.width + s - shift) / s).rounded(.up)) {
                let x = box.midX + (box.minX + CGFloat(k) * s + shift - box.midX) * spread
                let r = CGRect(x: x - s * 0.4 * spread, y: y + c * 0.06, width: s * 0.8 * spread, height: c * 0.92)
                pieces.addRoundedRect(in: r, cornerWidth: r.width * 0.45, cornerHeight: min(r.height * 0.4, r.width * 0.45))
                shine.move(to: CGPoint(x: r.minX + r.width * 0.3, y: r.minY + c * 0.22))
                shine.addLine(to: CGPoint(x: r.minX + r.width * 0.3, y: r.maxY - c * 0.3))
            }
            y += c
        }
        g.saveGState()
        g.addPath(roof); g.clip()
        g.setFillColor(dark.cgColor); g.fill(box)
        g.addPath(pieces); g.setFillColor(base.cgColor); g.fillPath()
        g.addPath(shine); g.setStrokeColor(light.cgColor); g.setLineWidth(D * 0.8); g.strokePath()
        g.restoreGState()
    }

    /// 瓦顶：檐口两头翘起 curl、屋脊两头起翘；瓦垄、檐口一排瓦当，左半边背光暗一点。
    /// half：檐口半宽，eave：檐口高度，ridge：屋脊高度，ridgeHalf：屋脊半长（都按宽 100 的单位）。
    static func tileRoof(_ g: CGContext, _ w: CGFloat, half: CGFloat, eave: CGFloat, ridge: CGFloat, ridgeHalf: CGFloat, curl: CGFloat, spacing: CGFloat = 3.4,
                         colors: (UIColor, UIColor, UIColor) = (C.roof, C.roofDark, C.roofLight)) {
        let (base, dark, lightC) = colors
        let tip = eave - curl
        let roof = path("M \(-half) \(tip) Q \(-half + 10) \(tip - 1) \(-half + 14) \(eave - 9) L \(-ridgeHalf) \(ridge) L \(ridgeHalf) \(ridge) L \(half - 14) \(eave - 9) Q \(half - 10) \(tip - 1) \(half) \(tip) Q 0 \(eave + curl) \(-half) \(tip) Z", w)
        tiles(g, roof, w, spacing: spacing, base: base, dark: dark, light: lightC)
        clipFill(g, roof, path("M \(-half - 2) \(ridge - 2) L \(-ridgeHalf * 0.2) \(ridge - 2) L \(-half * 0.3) \(eave + 4) L \(-half - 2) \(eave + 4) Z", w), UIColor.black.withAlphaComponent(0.1))
        shape(g, roof, fill: nil)
        g.setFillColor(dark.cgColor)                                                   // 檐口的瓦当
        var t: CGFloat = 0.03
        let step = spacing / (2 * half)
        while t <= 0.97 {
            let x = -half + 2 * half * t, y = tip + 4 * curl * t * (1 - t)
            g.addPath(E(w, x, y - 1, 1.4, 1.2)); g.fillPath()
            t += step
        }
        let r = ridgeHalf
        shape(g, path("M \(-r - 4) \(ridge + 1) L \(r + 4) \(ridge + 1) L \(r + 6) \(ridge - 4) Q \(r + 10) \(ridge - 8) \(r + 14) \(ridge - 12) L \(r + 5) \(ridge - 7) L \(-r - 5) \(ridge - 7) L \(-r - 14) \(ridge - 12) Q \(-r - 10) \(ridge - 8) \(-r - 6) \(ridge - 4) Z", w),
              fill: dark)
    }

    /// 硬山顶（斜着看、右边露出山墙）：前坡一片片瓦，瓦垄顺着进深方向往右上斜；山墙顶上前坡、后坡各一道瓦边；屋脊两头起翘；檐口一排瓦当。
    /// 坐标按宽 100 的单位：l、r 是前墙左右，top 是墙顶，dx、dy 是进深往右上的偏移（dy 是负的），rise 是山尖比山墙顶边中点高多少。
    static func gableRoof(_ g: CGContext, _ w: CGFloat, l: CGFloat, r: CGFloat, top: CGFloat, dx: CGFloat, dy: CGFloat, rise: CGFloat,
                          overhang: CGFloat = 6, curl: CGFloat = 3, spacing: CGFloat = 3.4,
                          colors: (UIColor, UIColor, UIColor) = (C.roof, C.roofDark, C.roofLight)) {
        let (base, dark, lightC) = colors
        let eave = top + 5
        let apex = CGPoint(x: r + dx / 2, y: top + dy / 2 - rise)
        let el = CGPoint(x: l - overhang, y: eave - curl), er = CGPoint(x: r + 2.5, y: eave - curl * 0.4)
        let rl = CGPoint(x: el.x + dx / 2, y: apex.y)
        let ctrl = CGPoint(x: (el.x + er.x) / 2, y: eave + curl)
        let front = path("M \(el.x) \(el.y) Q \(ctrl.x) \(ctrl.y) \(er.x) \(er.y) L \(apex.x) \(apex.y) L \(rl.x) \(rl.y) Z", w)
        tiles(g, front, w, spacing: spacing, base: base, dark: dark, light: lightC, shear: (dx / 2) / (el.y - apex.y))
        shape(g, front, fill: nil)
        let back = CGPoint(x: r + dx + 2.5, y: top + dy + 4)
        for (a, b) in [(apex, back), (er, apex)] {                                    // 山墙顶上的两道瓦边
            let d = "M \(a.x) \(a.y) L \(b.x) \(b.y)"
            line(g, d, w, width: 3.2 * w / 100 + 2 * O, color: ink)
            line(g, d, w, width: 3.2 * w / 100, color: dark)
        }
        g.setFillColor(dark.cgColor)                                                   // 檐口的瓦当
        var t: CGFloat = 0.03
        let step = spacing / max(1, er.x - el.x)
        while t <= 0.97 {
            let u = 1 - t
            let x = u * u * el.x + 2 * u * t * ctrl.x + t * t * er.x, y = u * u * el.y + 2 * u * t * ctrl.y + t * t * er.y
            g.addPath(E(w, x, y - 1, 1.4, 1.2)); g.fillPath()
            t += step
        }
        let a = rl.x + 3, b = apex.x - 1, y = apex.y                                   // 屋脊
        shape(g, path("M \(a) \(y + 1) L \(b) \(y + 1) L \(b + 2) \(y - 4) Q \(b + 6) \(y - 8) \(b + 10) \(y - 12) L \(b + 1) \(y - 7) L \(a - 1) \(y - 7) L \(a - 10) \(y - 12) Q \(a - 6) \(y - 8) \(a - 2) \(y - 4) Z", w),
              fill: dark)
    }

    /// 窗：方格窗或圆窗（x、y 是左上角，ww、wh 是宽高）。
    static func window(_ g: CGContext, _ w: CGFloat, x: CGFloat, y: CGFloat, ww: CGFloat, wh: CGFloat, round: Bool) {
        let frame = color(0x3B3B3B)
        if round {
            let r = min(ww, wh) / 2, cx = x + ww / 2, cy = y + wh / 2
            let p = E(w, cx, cy, r, r)
            shape(g, p, fill: frame, line: D)
            g.saveGState(); g.addPath(p); g.clip()
            line(g, "M \(cx - r) \(cy) L \(cx + r) \(cy) M \(cx) \(cy - r) L \(cx) \(cy + r) M \(cx - r) \(cy - r * 0.5) L \(cx + r) \(cy - r * 0.5) M \(cx - r) \(cy + r * 0.5) L \(cx + r) \(cy + r * 0.5)", w,
                 width: D * 0.8, color: C.wall)
            g.restoreGState()
            shape(g, p, fill: nil, line: D * 1.4, stroke: C.wood)
        } else {
            shape(g, path("M \(x) \(y) L \(x + ww) \(y) L \(x + ww) \(y + wh) L \(x) \(y + wh) Z", w), fill: frame, line: D)
            line(g, "M \(x + ww / 3) \(y) L \(x + ww / 3) \(y + wh) M \(x + ww * 2 / 3) \(y) L \(x + ww * 2 / 3) \(y + wh) M \(x) \(y + wh / 2) L \(x + ww) \(y + wh / 2)", w, width: D * 0.8, color: C.wall)
        }
    }

    /// 红灯笼（金顶、流苏），挂在 y 那根梁下面。
    static func redLantern(_ g: CGContext, _ w: CGFloat, x lx: CGFloat, y: CGFloat) {
        line(g, "M \(lx) \(y) L \(lx) \(y + 4)", w)
        shape(g, path("M \(lx - 5) \(y + 10) Q \(lx - 6.5) \(y + 4) \(lx) \(y + 4) Q \(lx + 6.5) \(y + 4) \(lx + 5) \(y + 10) Q \(lx + 6.5) \(y + 16) \(lx) \(y + 16) Q \(lx - 6.5) \(y + 16) \(lx - 5) \(y + 10) Z", w), fill: C.red, line: D)
        line(g, "M \(lx - 2) \(y + 5) Q \(lx - 3) \(y + 10) \(lx - 2) \(y + 15) M \(lx + 2) \(y + 5) Q \(lx + 3) \(y + 10) \(lx + 2) \(y + 15)", w, width: D * 0.7, color: ArtStyle.shade(C.red, 0.7))
        shape(g, path("M \(lx - 3) \(y + 3) L \(lx + 3) \(y + 3) L \(lx + 3) \(y + 4.5) L \(lx - 3) \(y + 4.5) Z M \(lx - 3) \(y + 15.5) L \(lx + 3) \(y + 15.5) L \(lx + 3) \(y + 17) L \(lx - 3) \(y + 17) Z", w), fill: C.gold, line: D * 0.7)
        line(g, "M \(lx) \(y + 17) L \(lx) \(y + 21)", w, width: D, color: C.red)
    }

    /// 瓦房：斜着看，正面一堵墙、右边露出侧墙和山墙（向阳、亮一点，开一扇小窗）；石基、白墙或木板墙、木柱木梁、
    /// 门（双扇居中或单扇靠左）、方窗或圆窗、硬山瓦顶；进深、山墙高矮、门窗、门口的小东西（灯笼、一串红辣椒、一盆花、扫帚）每家不同。
    /// tea：茶馆，正面敞开（里面一张桌子、茶壶，门楣一道蓝布帘），檐下挂一面画着茶壶的布招。
    static func house(_ g: CGContext, _ w: CGFloat, seed: Int, tea: Bool = false) {
        var v = Vary(seed)
        let top = -7 - v.f(36, 42)
        let plank = !tea && v.chance(0.3)
        let dx = v.f(13, 17), dy = -dx * 0.62, rise = v.f(19, 24)
        let l: CGFloat = -46, r = 42 - dx, cx = (l + r) / 2
        shape(g, path("M \(l - 3) 0 L \(r) 0 L \(r) -7 L \(l - 3) -7 Z", w), fill: C.stone, line: D)                    // 石基：正面、侧面
        var seams = "", sx = l + 12
        while sx < r - 4 { seams += "M \(sx) 0 L \(sx) -7 "; sx += 16 }
        line(g, seams, w, color: C.stoneShade)
        shape(g, path("M \(r) 0 L \(r + dx + 3) \(dy) L \(r + dx + 3) \(dy - 7) L \(r) -7 Z", w), fill: C.stoneLight, line: D)
        let wall = path("M \(l) -7 L \(r) -7 L \(r) \(top) L \(l) \(top) Z", w)
        let wallColor = plank ? tint(color(0xB98A57), &v, 0.05) : tint(C.wall, &v, 0.02)
        shape(g, wall, fill: wallColor, line: 0)
        if plank {
            var d = "", x = l + 6
            while x < r { d += "M \(x) -7 L \(x) \(top) "; x += 6 }
            line(g, d, w, width: D * 0.8, color: ArtStyle.shade(wallColor, 0.72))
        }
        shape(g, path("M \(l) \(top) L \(r) \(top) L \(r) \(top + 6) L \(l) \(top + 6) Z", w), fill: ArtStyle.shade(wallColor, 0.86), line: 0)   // 檐下的阴影
        dots(g, path("M \(l + 3) -7 L \(l + 12) -7 L \(l + 12) \(top + 6) L \(l + 3) \(top + 6) Z", w), alpha: 0.15)                           // 左边背光
        shape(g, wall, fill: nil)
        let side = path("M \(r) -7 L \(r + dx) \(-7 + dy) L \(r + dx) \(top + dy) L \(r + dx / 2) \(top + dy / 2 - rise) L \(r) \(top) Z", w)
        let sideColor = ArtStyle.mix(wallColor, .white, 0.3)
        shape(g, side, fill: sideColor, line: 0)
        if plank {
            var d = ""
            for u in [0.25, 0.5, 0.75] as [CGFloat] { d += "M \(r + u * dx) \(-7 + u * dy) L \(r + u * dx) \(top + u * dy) " }
            line(g, d, w, width: D * 0.8, color: ArtStyle.shade(sideColor, 0.72))
        }
        clipFill(g, side, path("M \(r) \(top) L \(r + dx) \(top + dy) L \(r + dx) \(top + dy + 6) L \(r) \(top + 6) Z", w), ArtStyle.shade(sideColor, 0.88))
        func onSide(_ u: CGFloat, _ y: CGFloat) -> String { "\(r + u * dx) \(y + u * dy)" }                     // 侧墙上的点：u 是进深的几成
        shape(g, path("M \(onSide(0.3, top + 12)) L \(onSide(0.7, top + 12)) L \(onSide(0.7, top + 23)) L \(onSide(0.3, top + 23)) Z", w), fill: color(0x3B3B3B), line: D)
        line(g, "M \(onSide(0.5, top + 12)) L \(onSide(0.5, top + 23)) M \(onSide(0.3, top + 17.5)) L \(onSide(0.7, top + 17.5))", w, width: D * 0.8, color: C.wall)
        shape(g, E(w, r + dx / 2, top + dy / 2 - rise * 0.45, 1.8, 1.8), fill: color(0x3B3B3B), line: D * 0.7)      // 山尖下的气窗
        shape(g, side, fill: nil)
        shape(g, path("M \(l - 1) -7 L \(l + 3) -7 L \(l + 3) \(top) L \(l - 1) \(top) Z M \(r - 2) -7 L \(r + 2) -7 L \(r + 2) \(top) L \(r - 2) \(top) Z", w), fill: C.wood, line: D)
        shape(g, path("M \(r + dx - 1.5) \(-7 + dy) L \(r + dx + 1.5) \(-7 + dy) L \(r + dx + 1.5) \(top + dy) L \(r + dx - 1.5) \(top + dy) Z", w), fill: C.wood, line: D)
        shape(g, path("M \(l - 2) \(top) L \(r + 2) \(top) L \(r + 2) \(top + 3) L \(l - 2) \(top + 3) Z", w), fill: C.wood, line: D)
        shape(g, path("M \(r + 2) \(top) L \(r + dx + 1.5) \(top + dy) L \(r + dx + 1.5) \(top + dy + 3) L \(r + 2) \(top + 3) Z", w), fill: C.wood, line: D)
        var lanterns: [CGFloat] = []
        if tea {
            shape(g, path("M \(cx - 24) -7 L \(cx + 18) -7 L \(cx + 18) \(top + 8) L \(cx - 24) \(top + 8) Z", w), fill: color(0x3A2E26), line: D)
            shape(g, path("M \(cx - 14) -16 L \(cx - 11) -16 L \(cx - 11) -7 L \(cx - 14) -7 Z M \(cx + 8) -16 L \(cx + 11) -16 L \(cx + 11) -7 L \(cx + 8) -7 Z", w), fill: C.wood, line: D)
            shape(g, path("M \(cx - 17) -19 L \(cx + 14) -19 L \(cx + 14) -16 L \(cx - 17) -16 Z", w), fill: C.woodLight, line: D)
            teapot(g, w, x: cx - 5, y: -19, s: 0.9)
            shape(g, path("M \(cx + 5) -19 L \(cx + 10) -19 L \(cx + 11) -23 L \(cx + 4) -23 Z", w), fill: C.porcelain, line: D)
            shape(g, path("M \(cx - 24) \(top + 8) L \(cx + 18) \(top + 8) L \(cx + 18) \(top + 15) L \(cx - 24) \(top + 15) Z", w), fill: C.blueGlaze, line: D)
            line(g, "M \(cx - 10) \(top + 10) L \(cx - 10) \(top + 15) M \(cx + 4) \(top + 10) L \(cx + 4) \(top + 15)", w, color: ArtStyle.shade(C.blueGlaze, 0.6))
            lanterns = [cx - 28, cx + 12]
        } else if v.chance(0.6) {                                                   // 双扇门居中
            shape(g, path("M \(cx - 13) -7 L \(cx + 13) -7 L \(cx + 13) -34 L \(cx - 13) -34 Z", w), fill: C.woodDark, line: D)
            shape(g, path("M \(cx - 11) -7 L \(cx - 0.6) -7 L \(cx - 0.6) -32 L \(cx - 11) -32 Z M \(cx + 0.6) -7 L \(cx + 11) -7 L \(cx + 11) -32 L \(cx + 0.6) -32 Z", w), fill: C.wood, line: D * 0.8)
            g.setFillColor(C.gold.cgColor)
            for x in [cx - 3, cx + 3] { g.addPath(E(w, x, -20, 0.9, 0.9)); g.fillPath() }
            shape(g, path("M \(cx - 16) 0 L \(cx + 16) 0 L \(cx + 16) 3 L \(cx - 16) 3 Z", w), fill: C.stoneLight, line: D)
            let round = v.chance(0.3)
            window(g, w, x: cx + 19, y: top + 11, ww: 12, wh: 15, round: round)
            if v.chance(0.5) { window(g, w, x: cx - 31, y: top + 11, ww: 12, wh: 15, round: round) }
            lanterns = [cx - 17, cx + 17]
        } else {                                                                    // 单扇门靠左
            shape(g, path("M \(l + 6) -7 L \(l + 22) -7 L \(l + 22) -33 L \(l + 6) -33 Z", w), fill: C.woodDark, line: D)
            shape(g, path("M \(l + 7.5) -7 L \(l + 20.5) -7 L \(l + 20.5) -31.5 L \(l + 7.5) -31.5 Z", w), fill: C.wood, line: D * 0.8)
            g.setFillColor(C.gold.cgColor); g.addPath(E(w, l + 18, -19, 0.9, 0.9)); g.fillPath()
            shape(g, path("M \(l + 4) 0 L \(l + 24) 0 L \(l + 24) 3 L \(l + 4) 3 Z", w), fill: C.stoneLight, line: D)
            window(g, w, x: cx + 1, y: top + 10, ww: 26, wh: 15, round: false)
            lanterns = [l + 28]
        }
        gableRoof(g, w, l: l, r: r, top: top, dx: dx, dy: dy, rise: rise)
        let count = tea ? lanterns.count : min(lanterns.count, v.pick([0, 1, 2, 2]))
        for lx in lanterns.prefix(count) { redLantern(g, w, x: lx, y: top + 3) }
        if tea {                                                                    // 檐下挂的布招，画着茶壶
            let bx = cx + 21
            let banner = path("M \(bx) \(top + 4) L \(bx + 10) \(top + 4) L \(bx + 10) \(top + 30) L \(bx + 7.5) \(top + 27) L \(bx + 5) \(top + 30) L \(bx + 2.5) \(top + 27) L \(bx) \(top + 30) Z", w)
            line(g, "M \(bx + 2) \(top + 3) L \(bx + 2) \(top + 4.5) M \(bx + 8) \(top + 3) L \(bx + 8) \(top + 4.5)", w)
            shape(g, banner, fill: color(0xF4EBD5), line: 0)
            g.saveGState(); g.addPath(banner); g.clip()
            g.addPath(banner); g.setStrokeColor(C.red.cgColor); g.setLineWidth(2.6 * w / 100); g.strokePath()
            g.restoreGState()
            shape(g, banner, fill: nil, line: D)
            teapot(g, w, x: bx + 4.6, y: top + 22, s: 0.5)
        } else {
            switch v.f(0, 1) {
            case ..<0.3:                                                            // 一串红辣椒
                line(g, "M \(r - 6) \(top + 3) L \(r - 6) \(top + 24)", w, width: D)
                for i in 0..<6 { shape(g, E(w, r - 6 + (i % 2 == 0 ? -1.4 : 1.4), top + 6 + CGFloat(i) * 3, 1.6, 2.6), fill: C.red, line: D * 0.7) }
            case ..<0.55:                                                           // 一盆花
                let px = r - 8
                shape(g, path("M \(px - 4) 0 L \(px + 4) 0 L \(px + 5.5) -7 L \(px - 5.5) -7 Z", w), fill: color(0xA9714B), line: D)
                shape(g, path("M \(px - 7) -7 Q \(px - 8) -15 \(px) -16 Q \(px + 8) -15 \(px + 7) -7 Z", w), fill: C.leaf, line: D)
                flower(g, CGPoint(x: (px - 2) * w / 100, y: -14 * w / 100), size: w * 0.012, petal: C.pink)
                flower(g, CGPoint(x: (px + 3) * w / 100, y: -12 * w / 100), size: w * 0.012, petal: .white)
            case ..<0.75:                                                           // 扫帚靠墙
                line(g, "M \(r - 10) -2 L \(r - 4) -30", w, width: O * 1.2, color: C.bamboo)
                shape(g, path("M \(r - 14) 0 L \(r - 6) 0 L \(r - 8) -10 L \(r - 11.5) -10 Z", w), fill: C.bamboo, line: D)
            default: break
            }
        }
    }

    /// 铁匠铺：敞开的棚子，斜着看、右边一堵木板山墙，硬山瓦顶；炉膛透出火光、两个铁砧（溅着火星）、风箱，屋后砖烟囱冒一缕灰烟。
    static func smithy(_ g: CGContext, _ w: CGFloat) {
        let dx: CGFloat = 14, dy = -dx * 0.62, l: CGFloat = -46, r = 42 - dx, top: CGFloat = -46
        g.setFillColor(color(0xD8DCD6).withAlphaComponent(0.85).cgColor)
        for (x, y, rr) in [(-24.0, -106.0, 6.0), (-20, -116, 8), (-25, -128, 9), (-19, -140, 8)] as [(CGFloat, CGFloat, CGFloat)] {
            g.addPath(E(w, x, y, rr, rr)); g.fillPath()
        }
        shape(g, path("M -30 -50 L -18 -50 L -18 -100 L -30 -100 Z", w), fill: color(0xB49A7A), line: D)
        line(g, "M -30 -70 L -18 -70 M -30 -80 L -18 -80 M -30 -90 L -18 -90 M -24 -70 L -24 -80 M -27 -80 L -27 -90 M -21 -90 L -21 -100", w, color: color(0x8A7458))
        shape(g, path("M \(l - 3) 0 L \(r) 0 L \(r) -4 L \(l - 3) -4 Z", w), fill: C.stoneLight, line: D)
        shape(g, path("M \(r) 0 L \(r + dx + 3) \(dy) L \(r + dx + 3) \(dy - 4) L \(r) -4 Z", w), fill: C.stone, line: D)
        let inside = path("M \(l + 3) -4 L \(r - 2) -4 L \(r - 2) \(top + 2) L \(l + 3) \(top + 2) Z", w)
        shape(g, inside, fill: color(0x5A4A3C), line: 0)
        dots(g, inside, alpha: 0.25)
        clipFill(g, inside, E(w, -32, -16, 16, 13), color(0xF29A3A).withAlphaComponent(0.45))           // 炉膛的火光
        clipFill(g, inside, E(w, -32, -16, 8, 6), color(0xF7C46A).withAlphaComponent(0.7))
        let side = path("M \(r) -4 L \(r + dx) \(-4 + dy) L \(r + dx) \(top + dy) L \(r + dx / 2) \(top + dy / 2 - 18) L \(r) \(top) Z", w)
        let planks = color(0x9A7048)
        shape(g, side, fill: planks, line: 0)
        var d = ""
        for u in [0.2, 0.4, 0.6, 0.8] as [CGFloat] { d += "M \(r + u * dx) \(-4 + u * dy) L \(r + u * dx) \(top + u * dy - (u < 0.5 ? u : 1 - u) * 36) " }
        line(g, d, w, width: D * 0.8, color: ArtStyle.shade(planks, 0.7))
        shape(g, side, fill: nil)
        shape(g, path("M \(l - 1) -4 L \(l + 3) -4 L \(l + 3) \(top) L \(l - 1) \(top) Z M \(r - 2) -4 L \(r + 2) -4 L \(r + 2) \(top) L \(r - 2) \(top) Z", w), fill: C.wood, line: D)
        shape(g, path("M \(l - 2) \(top) L \(r + 2) \(top) L \(r + 2) \(top + 3) L \(l - 2) \(top + 3) Z", w), fill: C.wood, line: D)
        gableRoof(g, w, l: l, r: r, top: top, dx: dx, dy: dy, rise: 18, curl: 2, spacing: 3.6)
        shape(g, path("M -40 -4 L -28 -4 L -28 -18 L -40 -18 Z", w), fill: C.wood, line: D)
        for ax in [-14.0, 10.0] as [CGFloat] {
            shape(g, path("M \(ax - 6) -4 L \(ax - 3) -4 L \(ax - 3) -12 L \(ax + 6) -12 L \(ax + 6) -4 L \(ax + 9) -4 L \(ax + 7) -15 L \(ax + 13) -19 L \(ax - 12) -19 L \(ax - 6) -15 Z", w), fill: color(0x2B2B2B), line: D)
        }
        g.setFillColor(C.gold.cgColor)
        for (x, y) in [(6.0, -24.0), (12, -27), (17, -23), (9, -30)] as [(CGFloat, CGFloat)] { g.addPath(E(w, x, y, 0.9, 0.9)); g.fillPath() }
    }

    /// 茅屋：土墙、木门、小窗，厚厚的茅草顶（草秆纹、两道草绳），右上亮、左下暗。
    static func hut(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        let mud = tint(color(0xD6BE92), &v, 0.04)
        shape(g, path("M -38 0 L 38 0 L 38 -5 L -38 -5 Z", w), fill: C.stone, line: D)
        let wall = path("M -34 -5 L 34 -5 L 34 -36 L -34 -36 Z", w)
        shape(g, wall, fill: mud, line: 0)
        dots(g, path("M -34 -5 L -24 -5 L -24 -36 L -34 -36 Z", w), alpha: 0.15)
        shape(g, wall, fill: nil)
        shape(g, path("M -36 -5 L -32 -5 L -32 -38 L -36 -38 Z M 32 -5 L 36 -5 L 36 -38 L 32 -38 Z", w), fill: C.wood, line: D)
        let dx: CGFloat = v.chance(0.5) ? -12 : 8
        shape(g, path("M \(dx - 8) -5 L \(dx + 8) -5 L \(dx + 8) -28 L \(dx - 8) -28 Z", w), fill: C.wood, line: D)
        line(g, "M \(dx - 3) -5 L \(dx - 3) -28 M \(dx + 3) -5 L \(dx + 3) -28", w, width: D * 0.8, color: C.woodDark)
        window(g, w, x: dx < 0 ? 10 : -26, y: -28, ww: 12, wh: 11, round: false)
        let straw = tint(color(0xC9A45C), &v, 0.05)
        let roof = path("M -50 -30 Q -44 -34 -38 -40 Q -22 -66 0 -70 Q 22 -66 38 -40 Q 44 -34 50 -30 Q 0 -38 -50 -30 Z", w)
        shape(g, roof, fill: straw, line: 0)
        light(g, roof, lit: ArtStyle.mix(straw, .white, 0.22), shade: ArtStyle.shade(straw, 0.8), litH: 0.4, shadeH: 0.25)
        g.saveGState(); g.addPath(roof); g.clip()
        var d = "", x: CGFloat = -48
        while x <= 48 { d += "M \(x * 0.3) -68 Q \(x * 0.75) -52 \(x) -30 "; x += 4.5 }
        line(g, d, w, width: D * 0.8, color: ArtStyle.shade(straw, 0.7))
        g.restoreGState()
        line(g, "M -40 -40 Q 0 -48 40 -40 M -28 -55 Q 0 -63 28 -55", w, width: D * 1.2, color: C.woodDark)
        shape(g, roof, fill: nil)
    }

    /// 土地庙：石台上一座小庙（瓦顶、红龛里一盏长明灯），前面一只香炉插三炷香，一缕细烟。
    static func shrine(_ g: CGContext, _ w: CGFloat) {
        shape(g, path("M -42 0 L 42 0 L 42 -10 L -42 -10 Z", w), fill: C.stone, line: D)
        line(g, "M -20 0 L -20 -10 M 4 0 L 4 -10 M 26 0 L 26 -10", w, color: C.stoneShade)
        let body = path("M -28 -10 L 28 -10 L 28 -56 L -28 -56 Z", w)
        shape(g, body, fill: C.wall, line: 0)
        dots(g, path("M -28 -10 L -19 -10 L -19 -56 L -28 -56 Z", w), alpha: 0.15)
        shape(g, body, fill: nil)
        shape(g, path("M -15 -16 L 15 -16 L 15 -40 Q 0 -50 -15 -40 Z", w), fill: C.red, line: D)
        shape(g, path("M -11 -16 L 11 -16 L 11 -38 Q 0 -45 -11 -38 Z", w), fill: ArtStyle.shade(C.red, 0.5), line: 0)
        shape(g, E(w, 0, -26, 6, 6), fill: C.gold.withAlphaComponent(0.35), line: 0)
        shape(g, E(w, 0, -26, 2.4, 3.4), fill: C.gold, line: D * 0.7)
        tileRoof(g, w, half: 40, eave: -52, ridge: -72, ridgeHalf: 16, curl: 3, spacing: 4)
        line(g, "M 0 -24 Q -5 -32 1 -40 Q 7 -48 0 -58 Q -5 -64 1 -70", w, width: D, color: color(0xAEB4AF))
        line(g, "M -3 -11 L -4 -22 M 0 -11 L 0 -23 M 3 -11 L 4 -22", w, width: D, color: C.woodDark)
        g.setFillColor(C.red.cgColor)
        for (x, y) in [(-4.0, -22.0), (0, -23), (4, -22)] as [(CGFloat, CGFloat)] { g.addPath(E(w, x, y, 0.9, 0.9)); g.fillPath() }
        shape(g, path("M -10 0 L 10 0 L 8 -5 L 12 -11 L -12 -11 L -8 -5 Z", w), fill: color(0x6B5A3A), line: D)
    }

    /// 石碑：石座，碑身上圆下方（微微歪、颜色每块不同），碑头一对云纹，碑面磨平一块（不刻字），碑脚长青苔。
    static func stele(_ g: CGContext, _ w: CGFloat, seed: Int) {
        var v = Vary(seed)
        let k = w / 100, t = v.f(-2.5, 2.5)
        shape(g, path("M -40 0 L 40 0 L 36 -12 L -36 -12 Z", w), fill: C.stone, line: D)
        line(g, "M -14 0 L -13 -12 M 12 0 L 11 -12", w, color: C.stoneShade)
        let slab = path("M -25 -12 L 25 -12 L \(25 + t) -66 Q \(t) -90 \(-25 + t) -66 Z", w)
        stoneBody(g, slab, &v)
        line(g, "M \(-14 + t) -70 Q \(-19 + t) -76 \(-12 + t) -79 Q \(-6 + t) -79 \(-8 + t) -73 M \(14 + t) -70 Q \(19 + t) -76 \(12 + t) -79 Q \(6 + t) -79 \(8 + t) -73", w,
             width: D, color: ArtStyle.shade(C.rockShade, 0.8))
        shape(g, path("M \(-16 + t * 0.2) -18 L \(16 + t * 0.2) -18 L \(16 + t * 0.8) -60 L \(-16 + t * 0.8) -60 Z", w), fill: ArtStyle.mix(C.rockLight, .white, 0.2), line: D)
        clipFill(g, slab, blob(-17 * k, -13 * k, 12 * k, 4.5 * k, n: 8, wob: 0.25, v: &v), C.moss)
        shape(g, slab, fill: nil)
    }

    // MARK: 水车、桥

    /// 水车：木轮（内外两圈轮辋、六根辐条、一圈刮板），两根木架撑着轮轴，脚下一汪水、溅起白浪。
    static func waterwheel(_ g: CGContext, _ w: CGFloat) {
        let k = w / 100
        let c = CGPoint(x: 0, y: -40 * k)
        shape(g, E(w, 0, -1, 44, 6), fill: C.water, line: D)
        shape(g, path("M -32 0 L -24 0 L -3 -42 L -9 -44 Z", w), fill: C.woodDark, line: D)
        for i in 0..<12 {
            g.saveGState(); g.translateBy(x: c.x, y: c.y); g.rotate(by: CGFloat(i) / 12 * 2 * .pi)
            shape(g, CGPath(rect: CGRect(x: -3 * k, y: -44 * k, width: 6 * k, height: 10 * k), transform: nil), fill: C.woodLight, line: D)
            g.restoreGState()
        }
        for (r, wd) in [(36.0, 4.0), (25.0, 3.0)] as [(CGFloat, CGFloat)] {
            let ring = ellipse(c.x, c.y, r * k, r * k)
            g.addPath(ring); g.setStrokeColor(ink.cgColor); g.setLineWidth(wd * k + 2 * O); g.strokePath()
            g.addPath(ring); g.setStrokeColor(C.wood.cgColor); g.setLineWidth(wd * k); g.strokePath()
        }
        let spokes = CGMutablePath()
        for i in 0..<6 {
            let a = CGFloat(i) / 6 * 2 * .pi + 0.3
            spokes.move(to: c); spokes.addLine(to: CGPoint(x: c.x + cos(a) * 25 * k, y: c.y + sin(a) * 25 * k))
        }
        g.addPath(spokes); g.setStrokeColor(ink.cgColor); g.setLineWidth(2.4 * k + 2 * O); g.strokePath()
        g.addPath(spokes); g.setStrokeColor(C.wood.cgColor); g.setLineWidth(2.4 * k); g.strokePath()
        shape(g, ellipse(c.x, c.y, 5 * k, 5 * k), fill: C.woodDark, line: D)
        shape(g, path("M 32 0 L 24 0 L 3 -42 L 9 -44 Z", w), fill: C.wood, line: D)
        line(g, "M -26 -3 Q -20 -10 -13 -4 M 12 -4 Q 18 -11 26 -3 M -4 -2 Q 0 -6 4 -2", w, width: D * 1.3, color: .white)
    }

    /// 石拱桥：桥身（石块缝）、拱洞（里面暗）、一排栏杆柱和扶手。
    static func stoneBridge(_ g: CGContext, _ w: CGFloat) {
        let body = path("M -50 0 L -50 -18 Q 0 -36 50 -18 L 50 0 L 24 0 Q 0 -30 -24 0 Z", w)
        shape(g, body, fill: color(0xE3DACB), line: 0)
        line(g, "M -46 -9 L -28 -10 M 28 -10 L 46 -9 M -40 -16 L -30 -18 M 30 -18 L 40 -16 M -14 -24 L 14 -24 M -36 0 L -34 -9 M 36 0 L 34 -9", w, color: color(0x9C9077))
        shape(g, path("M -24 0 Q 0 -30 24 0 Z", w), fill: color(0x5B6E73), line: 0)
        shape(g, body, fill: nil)
        shape(g, path("M -50 -30 Q 0 -48 50 -30 L 50 -27 Q 0 -45 -50 -27 Z", w), fill: color(0xE3DACB), line: D)
        for x in stride(from: -46.0, through: 46.0, by: 9.2) {
            let top = -30 - (1 - (x / 50) * (x / 50)) * 18
            shape(g, path("M \(x - 2) \(top + 13) L \(x + 2) \(top + 13) L \(x + 2) \(top - 3) L \(x - 2) \(top - 3) Z", w), fill: color(0xE3DACB), line: D)
            shape(g, path("M \(x - 2.6) \(top - 3) L \(x + 2.6) \(top - 3) L \(x + 2.6) \(top - 5) L \(x - 2.6) \(top - 5) Z", w), fill: color(0xCFC6B4), line: D * 0.8)
        }
        line(g, "M -50 -18 Q 0 -36 50 -18", w, width: O)
    }

    // MARK: 山门一带

    /// 石灯：底座、灯柱、灯室（亮）、灯顶。
    static func lantern(_ g: CGContext, _ w: CGFloat) {
        let stone = color(0xCFC6B4)
        shape(g, path("M -30 0 L 30 0 L 22 -14 L -22 -14 Z", w), fill: stone)
        shape(g, path("M -10 -14 L 10 -14 L 10 -60 L -10 -60 Z", w), fill: stone)
        shape(g, path("M -24 -60 L 24 -60 L 24 -96 L -24 -96 Z", w), fill: stone)
        shape(g, path("M -12 -66 L 12 -66 L 12 -88 L -12 -88 Z", w), fill: color(0xF3D58A))
        shape(g, path("M -40 -96 L 0 -122 L 40 -96 Z", w), fill: color(0xB2A890))
        dots(g, path("M -24 -60 L -10 -60 L -10 -96 L -24 -96 Z", w))
    }

    /// 凉亭：石台、四根柱子、栏杆、墨绿瓦顶（瓦垄）翘檐、宝顶。
    static func pavilion(_ g: CGContext, _ w: CGFloat) {
        shape(g, path("M -50 0 L 50 0 L 50 -10 L -50 -10 Z", w), fill: C.stoneLight)
        line(g, "M -38 0 L -38 -10 M -14 0 L -14 -10 M 10 0 L 10 -10 M 34 0 L 34 -10 M -50 -5 L 50 -5", w, color: C.stoneShade)
        for x in [-40.0, -14.0, 14.0, 40.0] as [CGFloat] {
            shape(g, path("M \(x - 2.6) -10 L \(x + 2.6) -10 L \(x + 2.6) -54 L \(x - 2.6) -54 Z", w), fill: C.wood, line: D)
        }
        shape(g, path("M -40 -22 L 40 -22 L 40 -25 L -40 -25 Z", w), fill: C.woodLight, line: D)
        line(g, "M -32 -25 L -32 -12 M -24 -25 L -24 -12 M -6 -25 L -6 -12 M 6 -25 L 6 -12 M 24 -25 L 24 -12 M 32 -25 L 32 -12", w, color: C.woodDark)
        let roof = path("M -62 -52 Q -52 -54 -46 -62 L -18 -88 L 18 -88 L 46 -62 Q 52 -54 62 -52 Q 0 -57 -62 -52 Z", w)
        tiles(g, roof, w, spacing: 3.4, base: C.greenRoof, dark: C.greenRoofDark, light: C.greenRoofLight)
        clipFill(g, roof, path("M -64 -90 L -6 -90 L -20 -50 L -64 -50 Z", w), UIColor.black.withAlphaComponent(0.1))
        shape(g, roof, fill: nil)
        shape(g, path("M -20 -87 L 20 -87 L 20 -91 L -20 -91 Z", w), fill: C.greenRoofDark, line: D)
        shape(g, E(w, 0, -94, 2.5, 3), fill: C.gold, line: D)
    }

    /// 石阶：一级级横石（踏面浅、立面深），越往上越窄。
    static func steps(_ g: CGContext, _ w: CGFloat) {
        for k in 0..<5 {
            let half = 50 - CGFloat(k) * 5, y = -CGFloat(k) * 9
            shape(g, path("M \(-half) \(y) L \(half) \(y) L \(half) \(y - 4) L \(-half) \(y - 4) Z", w), fill: color(0xC9BFAA), line: D)
            shape(g, path("M \(-half) \(y - 4) L \(half) \(y - 4) L \(half - 2) \(y - 9) L \(-half + 2) \(y - 9) Z", w), fill: color(0xE6DECF), line: D)
        }
    }

    /// 山门：石墩、两根红柱（暗边）、黑梁、空白金匾、墨绿瓦顶（瓦垄、瓦当）翘檐、屋脊。
    static func gate(_ g: CGContext, _ w: CGFloat) {
        shape(g, path("M -40 0 L -22 0 L -22 -8 L -40 -8 Z M 22 0 L 40 0 L 40 -8 L 22 -8 Z", w), fill: C.stoneLight)
        shape(g, path("M -36 -8 L -26 -8 L -26 -66 L -36 -66 Z M 26 -8 L 36 -8 L 36 -66 L 26 -66 Z", w), fill: C.pillar, line: 0)
        shape(g, path("M -36 -8 L -33 -8 L -33 -66 L -36 -66 Z M 26 -8 L 29 -8 L 29 -66 L 26 -66 Z", w), fill: C.pillarShade, line: 0)
        shape(g, path("M -36 -8 L -26 -8 L -26 -66 L -36 -66 Z M 26 -8 L 36 -8 L 36 -66 L 26 -66 Z", w), fill: nil)
        shape(g, path("M -44 -66 L 44 -66 L 44 -73 L -44 -73 Z", w), fill: color(0x3B2A22))
        shape(g, path("M -18 -50 L 18 -50 L 18 -64 L -18 -64 Z", w), fill: C.gold)
        shape(g, path("M -16 -51.5 L 16 -51.5 L 16 -62.5 L -16 -62.5 Z", w), fill: nil, line: D * 0.7, stroke: color(0xB88A2A))
        let roof = path("M -60 -71 Q -46 -73 -40 -84 L 40 -84 Q 46 -73 60 -71 Q 0 -76 -60 -71 Z", w)
        tiles(g, roof, w, spacing: 3.2, base: C.greenRoof, dark: C.greenRoofDark, light: C.greenRoofLight)
        shape(g, roof, fill: nil)
        g.setFillColor(C.greenRoofDark.cgColor)
        var tx: CGFloat = -56
        while tx <= 56 { g.addPath(E(w, tx, -72 - 1.5 * (1 - (tx / 60) * (tx / 60)), 1.2, 1)); g.fillPath(); tx += 3.2 }
        shape(g, path("M -32 -84 L -22 -92 L 22 -92 L 32 -84 Z", w), fill: C.greenRoof)
        shape(g, path("M -34 -91 L 34 -91 L 36 -95 Q 40 -98 43 -101 L 35 -97 L -35 -97 L -43 -101 Q -40 -98 -36 -95 Z", w), fill: C.greenRoofDark)
    }
}
