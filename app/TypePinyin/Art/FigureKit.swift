import LearningCore
import UIKit

/// 正式美术的人物组装器：按对手的外形描述拼出五个部件。人物身上不放字。
/// 主角不用它，保持原来的画法 `FigureArt.player()`（2026-11-01 产品负责人定）。
/// 支点和锚点和旧画法 `FigureArt.player()` 完全一样（前臂 (10,-112)、后臂 (-10,-116)、两腿 (±4,-72)、
/// 剑线 M65 -110 L124 -124、后手 (-38,-141)），所以动作和特效一行不用改，只换部件的样子。
enum FigureKit {
    struct Spec: Hashable {
        var robe: UInt32
        var trim: UInt32
        var hat: String
        var build: String
        var weapon: String
        var face: String
        var back: String?

        var key: String { "kit|\(robe)|\(trim)|\(hat)|\(build)|\(weapon)|\(face)|\(back ?? "")" }
    }

    /// 对手的外形（内容里的 look；没写的字段用默认）。
    static func spec(_ look: Look) -> Spec {
        Spec(robe: hex(look.robe) ?? 0x8A8F9E, trim: look.trim.flatMap(hex) ?? 0x111111, hat: look.hat,
             build: look.build ?? "normal", weapon: look.weapon ?? "saber", face: look.face ?? "plain",
             back: look.back)
    }

    static func hex(_ s: String) -> UInt32? {
        let t = s.hasPrefix("#") ? String(s.dropFirst()) : s
        return t.count == 6 ? UInt32(t, radix: 16) : nil
    }

    static func figure(_ s: Spec) -> FigureArt.Figure {
        let k = Kit(s)
        return FigureArt.Figure(
            backArm: FigureArt.Part(shapes: k.backArm(), pivot: CGPoint(x: -10, y: -116)),
            backLeg: FigureArt.Part(shapes: k.leg(front: false), pivot: CGPoint(x: -4, y: -72)),
            frontLeg: FigureArt.Part(shapes: k.leg(front: true), pivot: CGPoint(x: 4, y: -72)),
            body: FigureArt.Part(shapes: k.body(), pivot: .zero),
            frontArm: FigureArt.Part(shapes: k.frontArm(), pivot: CGPoint(x: 10, y: -112)),
            key: s.key)
    }
}

/// 一个人物的画法数据：颜色、体型宽度，部件的形状在 FigureKit+Parts.swift。
struct Kit {
    let s: FigureKit.Spec
    let robe: UIColor
    let robeShade: UIColor
    let trim: UIColor
    let hair: UIColor
    let pants: UIColor
    /// 体型：身子、袖子按这个比例变宽变粗（头不变）。
    let w: CGFloat

    init(_ s: FigureKit.Spec) {
        self.s = s
        robe = UIColor(hex: s.robe)
        robeShade = ArtStyle.shade(robe)
        trim = UIColor(hex: s.trim)
        hair = s.face == "old" ? UIColor(hex: 0xE9E6DF) : ArtStyle.ink
        pants = UIColor(hex: 0x3A4260)
        w = s.build == "burly" ? 1.24 : s.build == "slim" ? 0.88 : 1
    }

    static let skin = UIColor(hex: 0xFFE2C2)
    static let steel = UIColor(hex: 0xE6ECF2)
    static let gold = UIColor(hex: 0xF3B52F)
    static let red = UIColor(hex: 0xE2432C)
    static let wood = UIColor(hex: 0x8A5A32)
    static let iron = UIColor(hex: 0x4A4F57)

    func p(_ d: String, fill: UIColor? = nil, stroke: UIColor? = ArtStyle.ink, width: CGFloat = ArtStyle.figureLine,
           cap: CGLineCap = .round) -> FigureArt.Shape {
        FigureArt.Shape(path: SVGPath.parse(d), fill: fill, stroke: stroke, width: width, cap: cap)
    }

    func dots(_ d: String) -> FigureArt.Shape {
        FigureArt.Shape(path: SVGPath.parse(d), fill: nil, stroke: nil, dots: true)
    }

    func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, fill: UIColor, width: CGFloat = ArtStyle.figureDetail) -> FigureArt.Shape {
        FigureArt.circle(x, y, r, fill: fill, width: width)
    }

    /// 一根两层的线（先粗黑，再细的颜色）：兵器的杆、剑身。
    func rod(_ d: String, color: UIColor, width: CGFloat) -> [FigureArt.Shape] {
        [p(d, stroke: ArtStyle.ink, width: width + 3), p(d, stroke: color, width: width)]
    }

    /// 体型：x 按 w 缩放（以 x = 0 为中心）。
    func x(_ v: CGFloat) -> String { fmt(v * w) }
    func fmt(_ v: CGFloat) -> String { String(format: "%.1f", v) }
}
