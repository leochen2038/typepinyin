import UIKit

/// 正式美术人物的部件形状。坐标同 SVG：脚在原点，y 向下；头中心 (3,-141)，半径 14。
/// 每个部件在支点附近多画一截，转动时被身子盖住，不露空。
extension Kit {
    // MARK: 腿

    func leg(front: Bool) -> [FigureArt.Shape] {
        // 支点 (±6,-72) 到脚 (-38,-4) / (34,-4)，裤腿上宽下窄，往支点上方多伸 10
        let top = CGPoint(x: front ? 6 : -6, y: -72), foot = CGPoint(x: front ? 34 : -38, y: -4)
        let len = hypot(foot.x - top.x, foot.y - top.y)
        let d = CGPoint(x: (foot.x - top.x) / len, y: (foot.y - top.y) / len)
        let n = CGPoint(x: -d.y, y: d.x)
        let lw = min(w, 1.15)
        let a = CGPoint(x: top.x - d.x * 10, y: top.y - d.y * 10)
        let b = CGPoint(x: foot.x - d.x * 7, y: foot.y - d.y * 7)
        let ht: CGFloat = 9.5 * lw, hb: CGFloat = 6.5 * lw
        let pts = [CGPoint(x: a.x + n.x * ht, y: a.y + n.y * ht), CGPoint(x: b.x + n.x * hb, y: b.y + n.y * hb),
                   CGPoint(x: b.x - n.x * hb, y: b.y - n.y * hb), CGPoint(x: a.x - n.x * ht, y: a.y - n.y * ht)]
        let pant = "M " + pts.map { "\(fmt($0.x)) \(fmt($0.y))" }.joined(separator: " L ") + " Z"
        let shoe = front ? "M 26 -12 L 41 -12 L 51 -3 L 52 1 L 25 1 Z" : "M -48 -12 L -33 -12 L -24 -3 L -23 1 L -49 1 Z"
        var out = [p(pant, fill: front ? pants : ArtStyle.shade(pants))]
        if !front { out.append(dots(pant)) }
        out.append(p(shoe, fill: ArtStyle.ink, width: ArtStyle.figureDetail))
        return out
    }

    // MARK: 身子（头、帽子、背上的东西都在这个部件里）

    func body() -> [FigureArt.Shape] {
        var out: [FigureArt.Shape] = []
        if s.back == "flag" { out += backFlag() }
        let skirtF = fmt(20 + 12 * w), skirtB = fmt(-(22 + 14 * w))
        let robePath = "M \(x(-14)) -124 Q 0 -129 \(x(14)) -124 L \(x(18)) -88 L \(skirtF) -48 L 12 -55 L 2 -68 L -8 -57 L \(skirtB) -46 L \(x(-18)) -88 Z"
        let shadePath = "M \(x(-14)) -124 L \(x(-18)) -88 L \(skirtB) -46 L -8 -57 L \(x(-5)) -88 L \(x(-7)) -121 Z"
        out.append(p(robePath, fill: robe, stroke: nil))
        out.append(p(shadePath, fill: robeShade, stroke: nil))
        out.append(dots(shadePath))
        out.append(p(robePath))
        if s.weapon == "hammer" {                                  // 铁匠：皮围裙（锤子和围裙是一套行头）
            let apron = "M \(x(-11)) -114 L \(x(11)) -114 L \(x(14)) -52 L \(x(-13)) -52 Z"
            out.append(p(apron, fill: Self.wood))
            out.append(dots("M \(x(-13)) -52 L \(x(-11)) -90 L \(x(-2)) -90 L \(x(0)) -52 Z"))
            out.append(p("M \(x(-11)) -114 L \(x(-7)) -124 M \(x(11)) -114 L \(x(7)) -124", width: 2.5))
            out.append(circle(-7 * w, -108, 1.8, fill: Self.gold, width: 1.5))
            out.append(circle(7 * w, -108, 1.8, fill: Self.gold, width: 1.5))
        }
        out.append(p("M \(x(-19)) -93 L \(x(19)) -93 L \(x(19)) -84 L \(x(-19)) -84 Z", fill: trim, width: 2.5))
        out.append(p("M \(x(10)) -86 L \(x(13)) -66 L \(x(18)) -68 L \(x(15)) -86 Z", fill: trim, width: 2))
        out.append(p("M \(x(-7)) -124 L 0 -108 L \(x(7)) -124", width: 2.5))
        out.append(p("M -4 -131 L 7 -131 L 7 -122 L -4 -122 Z", fill: Self.skin, width: 2.5))
        out.append(circle(3, -141, 14, fill: Self.skin, width: ArtStyle.figureLine))
        out += headwear()
        out += face()
        return out
    }

    private func shortHair() -> FigureArt.Shape {
        p("M -11 -139 Q -12 -156 4 -156 Q 19 -156 17 -145 Q 9 -151 -2 -147 L -4 -132 Q -9 -133 -11 -139 Z", fill: hair, width: 2)
    }

    private func band(_ c: UIColor) -> FigureArt.Shape {
        p("M -12 -148 Q 3 -156 18 -150 L 18 -145 Q 3 -151 -12 -143 Z", fill: c, width: 2)
    }

    private func headwear() -> [FigureArt.Shape] {
        let ear = circle(-4, -140, 3.2, fill: Self.skin)
        switch s.hat {
        case "topknot":
            return [shortHair(), ear, circle(1, -158, 6, fill: hair)]
        case "band":
            let c = s.trim == 0x111111 ? UIColor(hex: 0xA63A2E) : trim
            return [shortHair(), ear, band(c), p("M -11 -146 Q -20 -146 -24 -136 Q -18 -141 -11 -143 Z", fill: c, width: 2)]
        case "conical":                                            // 斗笠：编织纹，帽檐在脸上压出一道网点暗影
            let straw = ArtStyle.mix(UIColor(hex: 0xD9B36A), robe, 0.22)
            let brim = "M -26 -147 L 3 -171 L 32 -147 Q 3 -139 -26 -147 Z"
            return [shortHair(), ear,
                    dots("M -10 -146 Q 3 -141 17 -146 L 17 -139 Q 3 -134 -10 -139 Z"),
                    p(brim, fill: straw),
                    p("M 3 -170 L -13 -146 M 3 -170 L 3 -142 M 3 -170 L 19 -145 M -9 -153 L 15 -153", stroke: ArtStyle.shade(straw, 0.7), width: 1.4),
                    p(brim, width: ArtStyle.figureLine),
                    circle(3, -171, 2.6, fill: ArtStyle.ink, width: 1)]
        case "bun":                                                // 女子：长发、脑后发髻、金簪
            return [p("M -12 -138 Q -13 -157 4 -157 Q 19 -157 17 -145 Q 9 -152 -2 -148 L -6 -126 Q -12 -128 -12 -138 Z", fill: hair, width: 2),
                    circle(-9, -153, 6.5, fill: hair),
                    p("M -16 -158 L -2 -149", stroke: ArtStyle.ink, width: 4), p("M -16 -158 L -2 -149", stroke: Self.gold, width: 2.2),
                    circle(-15, -158, 2.4, fill: Self.red, width: 1.2)]
        case "scholar":                                            // 方巾，脑后两根带子
            let c = s.trim == 0x111111 ? UIColor(hex: 0x2B2B2B) : trim
            return [shortHair(), ear,
                    p("M -11 -150 Q -19 -140 -17 -126", stroke: ArtStyle.ink, width: 5), p("M -11 -150 Q -19 -140 -17 -126", stroke: c, width: 2.6),
                    p("M -12 -146 L -9 -161 L 15 -161 L 18 -146 Q 3 -151 -12 -146 Z", fill: c, width: 2.5)]
        case "helmet":                                             // 头盔，红缨
            let helm = "M -13 -139 Q -13 -163 4 -163 Q 21 -163 20 -139 L 15 -139 L 15 -146 Q 4 -150 -8 -146 L -8 -137 Z"
            return [ear,
                    p("M 4 -163 Q -2 -177 -12 -181 Q -2 -173 9 -164 Z", fill: Self.red, width: 2),
                    p(helm, fill: UIColor(hex: 0x9AA3AE)),
                    dots("M -13 -139 Q -13 -163 4 -163 L 0 -146 L -8 -137 Z"),
                    p("M -13 -146 Q 4 -151 21 -146", width: 2.5)]
        case "opera":                                              // 戏曲头饰：金额子、红绒球、两根翎子
            return [p("M -4 -157 Q -24 -196 -46 -176", stroke: ArtStyle.ink, width: 5), p("M -4 -157 Q -24 -196 -46 -176", stroke: UIColor(hex: 0xC8553D), width: 2.4),
                    p("M 0 -159 Q -16 -201 -40 -191", stroke: ArtStyle.ink, width: 5), p("M 0 -159 Q -16 -201 -40 -191", stroke: UIColor(hex: 0xC8553D), width: 2.4),
                    shortHair(), ear, band(Self.gold),
                    circle(-5, -156, 3.6, fill: Self.red), circle(3, -160, 3.6, fill: Self.red), circle(11, -157, 3.6, fill: Self.red)]
        default:
            return [shortHair(), ear]
        }
    }

    private func face() -> [FigureArt.Shape] {
        var out: [FigureArt.Shape] = [p("M 10 -143 L 13.5 -143", width: 3.2)]
        if s.face == "old" {
            out += [p("M 7.5 -149 L 15 -150", stroke: ArtStyle.ink, width: 5.5), p("M 7.5 -149 L 15 -150", stroke: hair, width: 3)]
        } else {
            out.append(p("M 7.5 -149 L 15 -150", width: 3))
        }
        switch s.face {
        case "mustache":
            out += [p("M 11 -134 L 14.5 -135", width: 2), p("M 8 -136.5 Q 12 -133 17 -136.5 M 9 -136 Q 7 -131 6 -128", width: 2.6)]
        case "beard":
            out += [p("M -1 -139 Q 0 -122 10 -120 Q 18 -122 17.5 -138 Q 13 -132 9 -132 Q 3 -132 -1 -139 Z", fill: hair, width: 2),
                    p("M 9 -132.5 L 14 -133.5", stroke: Self.skin, width: 1.6)]
        case "old":
            out += [p("M 0 -137 Q 2 -116 9 -109 Q 17 -118 17.5 -136 Q 13 -132 9 -132 Q 4 -132 0 -137 Z", fill: hair, width: 2),
                    p("M 8 -136.5 Q 12 -133 17 -136.5", stroke: ArtStyle.ink, width: 2)]
        default:
            out.append(p("M 11 -134 L 14.5 -135", width: 2))
        }
        return out
    }

    private func backFlag() -> [FigureArt.Shape] {
        // 旗杆插在背后，一面三角镖旗（人物身上不放字），红边
        return rod("M -4 -92 L -14 -201", color: Self.wood, width: 2.5) + [
            p("M -14 -199 L -48 -186 L -14 -171 Z", fill: Self.gold, width: 2.5),
            p("M -14 -192 L -34 -185.5 L -14 -178", stroke: Self.red, width: 3),
        ]
    }

    // MARK: 手臂

    /// 袖子按体型变粗：y 以手臂中线 (-111) 为中心缩放。
    private func yv(_ v: CGFloat) -> String { fmt(-111 + (v + 111) * min(w, 1.18)) }

    func frontArm() -> [FigureArt.Shape] {
        var out: [FigureArt.Shape] = []
        let rolled = s.weapon == "hammer"                          // 铁匠挽起袖子，露出小臂
        let sleeve = rolled
            ? "M 4 \(yv(-123)) Q 20 \(yv(-127)) 34 \(yv(-122)) L 36 \(yv(-102)) Q 20 \(yv(-101)) 6 \(yv(-99)) Z"
            : "M 4 \(yv(-123)) Q 30 \(yv(-129)) 54 \(yv(-119)) L 56 \(yv(-103)) Q 32 \(yv(-103)) 6 \(yv(-99)) Z"
        let under = rolled
            ? "M 6 \(yv(-99)) Q 20 \(yv(-101)) 36 \(yv(-102)) L 35 \(yv(-107)) Q 20 \(yv(-107)) 8 \(yv(-105)) Z"
            : "M 6 \(yv(-99)) Q 32 \(yv(-103)) 56 \(yv(-103)) L 55 \(yv(-108)) Q 30 \(yv(-109)) 8 \(yv(-105)) Z"
        let back = weaponBehindHand()
        out += back
        if rolled { out.append(p("M 32 \(yv(-119)) L 58 \(yv(-115)) L 58 \(yv(-105)) L 33 \(yv(-104)) Z", fill: Self.skin, width: 2.5)) }
        out.append(p(sleeve, fill: robe))
        out.append(dots(under))
        out.append(circle(61, -110, s.weapon == "fists" ? 7 : 5 * min(w, 1.15), fill: Self.skin, width: 2.5))
        out += weaponOverHand()
        return out
    }

    func backArm() -> [FigureArt.Shape] {
        let sleeve = "M -4 -125 Q -24 -137 -36 -147 L -28 -132 Q -18 -120 -12 -103 Z"
        return [p(sleeve, fill: robeShade), dots(sleeve), circle(-38, -141, 4.6, fill: Self.skin)]
    }

    // MARK: 兵器（前臂坐标，手在 (61,-110)）

    private func weaponBehindHand() -> [FigureArt.Shape] {
        switch s.weapon {
        case "sword":
            return rod("M 52 -107 L 61 -109", color: Self.wood, width: 4)                // 剑尖到 100：站位按对手兵器伸出 98 算
                + [p("M 52 -107 Q 47 -97 52 -87", stroke: Self.gold, width: 2.6)]
                + rod("M 65 -110 L 100 -119", color: Self.steel, width: 3.5)
        case "saber":
            return [p("M 63 -113 Q 84 -125 97 -158 Q 97 -130 69 -104 Z", fill: Self.steel, width: 2.5),
                    p("M 67 -111 Q 85 -124 95 -153", stroke: UIColor(hex: 0x9AA3AE), width: 1.5),
                    circle(54, -106, 3, fill: Self.gold, width: 1.5)]
        case "hammer":
            return rod("M 64 -100 L 44 -170", color: Self.wood, width: 5)
                + [p("M 26 -176 L 52 -186 L 59 -165 L 33 -155 Z", fill: Self.iron), p("M 31 -174 L 50 -181", stroke: UIColor(hex: 0x9AA3AE), width: 2.4)]
        case "pole":                                               // 竹篙：竹节
            return rod("M 30 -78 L 98 -196", color: UIColor(hex: 0x7FA35A), width: 4)
                + [p("M 47 -115.4 L 54 -111.4 M 64 -144.9 L 71 -140.9 M 81 -174.4 L 88 -170.4", width: 1.8)]
        case "staff":
            return rod("M 34 -78 L 92 -176", color: Self.wood, width: 4.5)
                + [p("M 86 -171 L 99 -180 L 104 -165 L 92 -160 Z", fill: Self.steel, width: 2)]
        case "spear":
            return rod("M 22 -102 L 92 -119", color: Self.wood, width: 3.5)
                + [p("M 92 -126 L 108 -122 L 93 -113 Z", fill: Self.steel, width: 2.5),
                   p("M 90 -119 Q 84 -108 88 -100 Q 92 -110 94 -117 Z", fill: Self.red, width: 1.5)]
        case "brush":
            return rod("M 52 -100 L 88 -130", color: UIColor(hex: 0xC9A227), width: 3)
                + [p("M 88 -130 Q 100 -141 104 -133 Q 98 -126 90 -127 Z", fill: ArtStyle.ink, width: 1.5)]
        default:
            return []
        }
    }

    private func weaponOverHand() -> [FigureArt.Shape] {
        switch s.weapon {
        case "sword": return rod("M 63 -117 L 67 -103", color: Self.gold, width: 4)
        case "saber": return rod("M 59 -118 L 66 -103", color: Self.gold, width: 3.5)
        case "fan":                                                // 打开的折扇
            return [p("M 61 -112 L 64 -142 A 28 28 0 0 1 89 -126 Z", fill: UIColor(hex: 0xF7EBCF), width: 2.5),
                    p("M 61 -112 L 72 -140 M 61 -112 L 80 -136 M 61 -112 L 86 -130", width: 1.4),
                    p("M 64 -142 A 28 28 0 0 1 89 -126", stroke: Self.red, width: 2.4)]
        case "qin":                                                // 琴横托在手上
            return [p("M 36 -122 L 96 -132 Q 100 -126 98 -120 L 38 -110 Z", fill: UIColor(hex: 0x5B3A22), width: 2.5),
                    p("M 40 -118 L 96 -128 M 40 -114 L 97 -124", stroke: UIColor(hex: 0xF7EBCF), width: 1)]
        case "fists": return [p("M 56 -115 L 56 -105", stroke: s.trim == 0x111111 ? Self.red : trim, width: 3)]
        default: return []
        }
    }
}
