import SpriteKit
import UIKit

/// 国潮版画人物：部件是矢量路径，启动时画成 @3x 贴图，在 SpriteKit 里按骨骼拼装。
/// 坐标系同 SVG：原点在两脚中间，y 向下；人物高约 160。
enum FigureArt {
    struct Shape {
        var path: CGPath
        var fill: UIColor?
        var stroke: UIColor?
        var width: CGFloat = 0
        var cap: CGLineCap = .butt
    }

    struct Part {
        var shapes: [Shape]
        var pivot: CGPoint
    }

    struct Figure {
        var backArm: Part
        var backLeg: Part
        var frontLeg: Part
        var body: Part
        var frontArm: Part
    }

    static let ink = UIColor(hex: 0x111111)
    static let skin = UIColor(hex: 0xFFE2C2)
    static let white = UIColor.white
    static let gold = UIColor(hex: 0xF3B52F)
    static let navy = UIColor(hex: 0x1C2A5C)

    static func p(_ d: String, fill: UIColor? = nil, stroke: UIColor? = ink, width: CGFloat = 3, cap: CGLineCap = .butt) -> Shape {
        Shape(path: SVGPath.parse(d), fill: fill, stroke: stroke, width: width, cap: cap)
    }

    static func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, fill: UIColor, stroke: UIColor? = ink, width: CGFloat = 2) -> Shape {
        Shape(path: CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r), transform: nil), fill: fill, stroke: stroke, width: width)
    }

    static func ellipse(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, fill: UIColor) -> Shape {
        Shape(path: CGPath(ellipseIn: CGRect(x: x - rx, y: y - ry, width: 2 * rx, height: 2 * ry), transform: nil), fill: fill, stroke: nil)
    }

    static func leg(_ d: String, foot: Shape) -> [Shape] {
        [p(d, stroke: ink, width: 14, cap: .round), p(d, stroke: white, width: 8, cap: .round), foot]
    }

    /// 玩家：白衫、红腰带、蓝领、持剑。
    static func player(accent: UIColor = UIColor(hex: 0xE2432C)) -> Figure {
        Figure(
            backArm: Part(shapes: [
                p("M -9 -118 Q -26 -132 -37 -140 L -31 -130 Q -21 -120 -12 -106 Z", fill: white),
                circle(-38, -141, 4, fill: skin),
            ], pivot: CGPoint(x: -10, y: -116)),
            backLeg: Part(shapes: leg("M -6 -72 Q -22 -40 -38 -4", foot: ellipse(-39, -3, 10, 5, fill: ink)), pivot: CGPoint(x: -4, y: -72)),
            frontLeg: Part(shapes: leg("M 6 -72 Q 30 -48 34 -4", foot: ellipse(37, -3, 10, 5, fill: ink)), pivot: CGPoint(x: 4, y: -72)),
            body: Part(shapes: [
                p("M -20 -86 L -8 -70 L -2 -62 L -18 -46 L -46 -42 Z", fill: gold),
                p("M -13 -121 L 13 -121 Q 19 -100 17 -86 L 32 -46 L 10 -50 L -2 -62 L -8 -70 L -20 -86 Q -18 -104 -13 -121 Z", fill: white),
                p("M -19 -90 L 18 -90 L 18 -82 L -20 -82 Z", fill: accent, width: 2.5),
                p("M -20 -86 Q -36 -82 -50 -70 M -20 -84 Q -34 -74 -42 -62", stroke: ink, width: 6, cap: .round),
                p("M -20 -86 Q -36 -82 -50 -70 M -20 -84 Q -34 -74 -42 -62", stroke: accent, width: 3, cap: .round),
                p("M -6 -121 L 0 -110 L 6 -121", stroke: navy, width: 3),
                p("M 1 -121 L 2 -126", stroke: ink, width: 8, cap: .round),
                circle(2, -136, 12, fill: skin, width: 3),
                p("M -10 -136 A 12 12 0 0 1 14 -136 Z", fill: ink, stroke: nil),
                circle(-3, -151, 5.5, fill: ink, stroke: nil),
                circle(8, -131, 1.8, fill: ink, stroke: nil),
                p("M -6 -151 Q -24 -154 -36 -144 M -6 -149 Q -22 -142 -30 -134", stroke: accent, width: 3, cap: .round),
            ], pivot: .zero),
            frontArm: Part(shapes: [
                p("M 9 -118 Q 34 -125 57 -115 L 58 -105 Q 36 -106 11 -103 Z", fill: white),
                circle(61, -110, 4.5, fill: skin),
                p("M 65 -110 L 124 -124", stroke: ink, width: 6, cap: .round),
                p("M 65 -110 L 124 -124", stroke: white, width: 2.6, cap: .round),
                p("M 63 -116 L 66 -104", stroke: ink, width: 4, cap: .round),
                p("M 53 -108 L 62 -110", stroke: accent, width: 4, cap: .round),
                p("M 53 -108 Q 48 -98 53 -88", stroke: gold, width: 3, cap: .round),
            ], pivot: CGPoint(x: 10, y: -112))
        )
    }

    /// 镖师：斗笠、持刀，衣服用 `robe` 色。画的时候朝右，放到右边时整体水平翻转。
    static func guardsman(robe: UIColor) -> Figure {
        Figure(
            backArm: Part(shapes: [
                p("M -9 -118 Q -26 -132 -37 -140 L -31 -130 Q -21 -120 -12 -106 Z", fill: robe),
                circle(-38, -141, 4, fill: skin),
            ], pivot: CGPoint(x: -10, y: -116)),
            backLeg: Part(shapes: leg("M -6 -72 Q -22 -40 -38 -4", foot: ellipse(-39, -3, 10, 5, fill: ink)), pivot: CGPoint(x: -4, y: -72)),
            frontLeg: Part(shapes: leg("M 6 -72 Q 30 -48 34 -4", foot: ellipse(37, -3, 10, 5, fill: ink)), pivot: CGPoint(x: 4, y: -72)),
            body: Part(shapes: [
                p("M -20 -86 L -8 -70 L -2 -62 L -18 -46 L -46 -42 Z", fill: ink),
                p("M -13 -121 L 13 -121 Q 19 -100 17 -86 L 32 -46 L 10 -50 L -2 -62 L -8 -70 L -20 -86 Q -18 -104 -13 -121 Z", fill: robe),
                p("M -19 -90 L 18 -90 L 18 -82 L -20 -82 Z", fill: ink, stroke: nil),
                p("M -20 -86 Q -36 -82 -50 -70 M -20 -84 Q -34 -74 -42 -62", stroke: ink, width: 6, cap: .round),
                p("M -20 -86 Q -36 -82 -50 -70 M -20 -84 Q -34 -74 -42 -62", stroke: gold, width: 3, cap: .round),
                p("M -6 -121 L 0 -110 L 6 -121", stroke: ink, width: 2.5),
                p("M 1 -121 L 2 -126", stroke: ink, width: 8, cap: .round),
                circle(2, -136, 12, fill: skin, width: 3),
                circle(8, -131, 1.8, fill: ink, stroke: nil),
                p("M -22 -140 L 2 -160 L 26 -140 Q 2 -134 -22 -140 Z", fill: gold),
                p("M -12 -146 L 2 -158 L 16 -146", stroke: ink, width: 1.5),
            ], pivot: .zero),
            frontArm: Part(shapes: [
                p("M 9 -118 Q 34 -125 57 -115 L 58 -105 Q 36 -106 11 -103 Z", fill: robe),
                circle(61, -110, 4.5, fill: skin),
                p("M 62 -112 Q 82 -128 98 -156 Q 90 -128 66 -104 Z", fill: white, width: 2.5),
                p("M 54 -106 L 61 -110", stroke: ink, width: 4, cap: .round),
                ellipse(62, -110, 3.5, 6.5, fill: ink),
            ], pivot: CGPoint(x: 10, y: -112))
        )
    }

    // MARK: - 贴图

    @MainActor
    static func texture(for part: Part, scale: CGFloat = 3) -> (SKTexture, CGPoint, CGSize) {
        var box = CGRect.null
        for s in part.shapes {
            let pad = s.width / 2 + 2
            box = box.union(s.path.boundingBoxOfPath.insetBy(dx: -pad, dy: -pad))
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: box.size, format: format).image { ctx in
            let g = ctx.cgContext
            g.translateBy(x: -box.minX, y: -box.minY)
            g.setLineJoin(.round)
            for s in part.shapes {
                if let f = s.fill {
                    g.addPath(s.path)
                    g.setFillColor(f.cgColor)
                    g.fillPath()
                }
                if let st = s.stroke, s.width > 0 {
                    g.addPath(s.path)
                    g.setStrokeColor(st.cgColor)
                    g.setLineWidth(s.width)
                    g.setLineCap(s.cap)
                    g.strokePath()
                }
            }
        }
        let anchor = CGPoint(x: (part.pivot.x - box.minX) / box.width, y: 1 - (part.pivot.y - box.minY) / box.height)
        return (SKTexture(image: img), anchor, box.size)
    }

    /// 命中星形（Print.dc.html 里的爆点）。
    static let burst = "M0 -42 L10 -14 L38 -22 L18 0 L42 18 L12 16 L8 44 L-6 20 L-32 32 L-18 8 L-42 -8 L-14 -8 Z"
}

/// 拼装好的人物节点：可以待机、出招、受击、倒地。
@MainActor
final class FigureNode: SKNode {
    let backArm = SKSpriteNode()
    let backLeg = SKSpriteNode()
    let frontLeg = SKSpriteNode()
    let bodyPart = SKSpriteNode()
    let frontArm = SKSpriteNode()
    private let rig = SKNode()

    init(_ figure: FigureArt.Figure) {
        super.init()
        // 脚下的影子：贴着地，不跟身体一起晃（在 rig 外面），让人看得出是站在地上
        let shadow = SKSpriteNode(texture: Self.shadowTexture)
        shadow.size = CGSize(width: 116, height: 16)
        shadow.position = CGPoint(x: 0, y: 1)
        shadow.zPosition = -1
        addChild(shadow)
        addChild(rig)
        for (node, part) in [(backArm, figure.backArm), (backLeg, figure.backLeg), (frontLeg, figure.frontLeg),
                             (bodyPart, figure.body), (frontArm, figure.frontArm)] {
            let (tex, anchor, size) = FigureArt.texture(for: part)
            node.texture = tex
            node.size = size
            node.anchorPoint = anchor
            node.position = CGPoint(x: part.pivot.x, y: -part.pivot.y)
            rig.addChild(node)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private static let shadowTexture: SKTexture = {
        let size = CGSize(width: 116, height: 16)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            ctx.cgContext.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: img)
    }()

    func idle(reduced: Bool) {
        rig.removeAllActions()
        rig.position = .zero
        rig.zRotation = 0
        rig.alpha = 1          // 倒地时 rig 淡到 0.3，下一场要恢复
        alpha = 1
        guard !reduced else { return }
        let up = SKAction.moveBy(x: 0, y: 2.5, duration: 0.6)
        up.timingMode = .easeInEaseOut
        rig.run(.repeatForever(.sequence([up, up.reversed()])), withKey: "idle")
    }

    private var swordGlow: SKShapeNode?

    /// 剑上的气：0 = 没有，1 = 最亮。只给玩家用（剑在前手部件上，跟着手转）。
    func setSwordGlow(_ k: CGFloat, color: UIColor) {
        if swordGlow == nil {
            let g = SKShapeNode()
            let p = CGMutablePath()
            p.move(to: Self.swordHilt); p.addLine(to: Self.swordTip)   // 剑身（前手部件的坐标）
            g.path = p
            g.lineCap = .round
            g.zPosition = 1
            // 光晕用一道更宽的半透明线，不用 glowWidth（那个每帧都要做模糊，很耗）
            let halo = SKShapeNode(path: p)
            halo.lineCap = .round
            halo.zPosition = -1
            halo.name = "halo"
            g.addChild(halo)
            frontArm.addChild(g)
            swordGlow = g
        }
        guard let g = swordGlow else { return }
        g.strokeColor = color
        g.lineWidth = 3 + 6 * k
        if let halo = g.childNode(withName: "halo") as? SKShapeNode {
            halo.strokeColor = color.withAlphaComponent(0.35)
            halo.lineWidth = 3 + 22 * k
        }
        g.alpha = k <= 0 ? 0 : 0.35 + 0.65 * k
    }

    /// 剑柄和剑尖（前手部件的坐标），从 player() 里剑身那条线 M 65 -110 L 124 -124 换算：
    /// 原点在部件支点 (10, -112)，y 轴翻成向上。
    static let swordHilt = CGPoint(x: 65 - 10, y: -(-110 + 112))
    static let swordTip = CGPoint(x: 124 - 10, y: -(-124 + 112))
    /// 空着的后手（后手部件的坐标），从 player() 里的手 circle(-38, -141) 换算，支点 (-10, -116)。绳镖从这里甩出、收回。
    static let backHand = CGPoint(x: -38 + 10, y: -(-141 + 116))

    /// 绳镖：后手往后一扬（wind），往前甩出（out），停住（hold）；back > 0 时接着往回一拽再放松。
    func throwDart(wind: Double, out: Double, hold: Double, back: Double) {
        backArm.removeAction(forKey: "dart")
        var s: [SKAction] = [.rotate(toAngle: 0.35, duration: wind), .rotate(toAngle: -1.0, duration: out), .wait(forDuration: hold)]
        if back > 0 { s += [.rotate(toAngle: 0.5, duration: back * 0.5), .rotate(toAngle: 0, duration: back)] }
        backArm.run(.sequence(s), withKey: "dart")
    }

    /// 绳镖：往回一拽，再放松。
    func yankDart(back: Double) {
        backArm.removeAction(forKey: "dart")
        backArm.run(.sequence([.rotate(toAngle: 0.5, duration: back * 0.5), .rotate(toAngle: 0, duration: back)]), withKey: "dart")
    }

    /// 接住字母的一下：后手闪一团光，大的一串时闪得更大。
    func flashHand(color: UIColor, big: Bool) {
        let f = SKShapeNode(circleOfRadius: big ? 11 : 8)
        f.fillColor = color
        f.strokeColor = .clear
        f.position = Self.backHand
        f.zPosition = 2
        backArm.addChild(f)
        f.run(.sequence([.group([.scale(to: big ? 2.8 : 2.2, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
    }

    /// 每一刀落下的时刻（和 dashAndSlash 一致），出刀前就能算好。
    static func slashTimes(slashes: Int, per: Double) -> [Double] {
        (0..<slashes).map { 0.08 + Double($0) * per + per * 0.45 }
    }

    /// 大招后收刀：剑慢慢收到身后，停一拍，再回到平常。
    func sheathe() {
        frontArm.run(.sequence([.wait(forDuration: 0.12), .rotate(toAngle: -1.3, duration: 0.28), .wait(forDuration: 0.45),
                                .rotate(toAngle: 0, duration: 0.25)]), withKey: "swing")
    }

    /// 冲到对手面前、斩 n 刀、退回。返回每一刀落下的时刻（秒）。
    func dashAndSlash(distance: CGFloat, slashes: Int, per: Double = 0.11, reduced: Bool) -> [Double] {
        let dash = 0.08, back = 0.16
        removeAction(forKey: "dash")
        frontArm.removeAction(forKey: "swing")
        var times: [Double] = []
        var arm: [SKAction] = [.wait(forDuration: dash)]
        for k in 0..<slashes {
            times.append(dash + Double(k) * per + per * 0.45)
            let up: CGFloat = k % 2 == 0 ? 0.9 : -0.5, down: CGFloat = k % 2 == 0 ? -0.8 : 0.7
            arm += [.rotate(toAngle: up, duration: per * 0.4), .rotate(toAngle: down, duration: per * 0.45), .wait(forDuration: per * 0.15)]
        }
        arm.append(.rotate(toAngle: 0, duration: 0.12))
        frontArm.run(.sequence(arm), withKey: "swing")
        guard !reduced else { return times }
        let go = SKAction.moveBy(x: distance, y: 0, duration: dash)
        go.timingMode = .easeOut
        let ret = SKAction.moveBy(x: -distance, y: 0, duration: back)
        ret.timingMode = .easeInEaseOut
        run(.sequence([go, .wait(forDuration: Double(slashes) * per), ret]), withKey: "dash")
        frontLeg.run(.sequence([.rotate(toAngle: -0.35, duration: dash), .wait(forDuration: Double(slashes) * per), .rotate(toAngle: 0, duration: back)]))
        return times
    }

    func attack(distance: CGFloat, heavy: Bool, reduced: Bool) {
        frontArm.removeAction(forKey: "swing")
        let swing = SKAction.sequence([
            .rotate(toAngle: 0.6, duration: 0.05),
            .rotate(toAngle: heavy ? -0.9 : -0.6, duration: 0.07),
            .rotate(toAngle: 0, duration: 0.16),
        ])
        frontArm.run(swing, withKey: "swing")
        guard !reduced else { return }
        let dash = SKAction.sequence([.moveBy(x: distance, y: 0, duration: 0.06), .moveBy(x: -distance, y: 0, duration: 0.18)])
        dash.timingMode = .easeOut
        run(dash)
        let legs = SKAction.sequence([.rotate(toAngle: -0.25, duration: 0.06), .rotate(toAngle: 0, duration: 0.18)])
        frontLeg.run(legs)
    }

    func hurt(reduced: Bool) {
        let flash = SKAction.sequence([.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.02), .wait(forDuration: 0.06),
                                       .colorize(withColorBlendFactor: 0, duration: 0.12)])
        for n in [backArm, backLeg, frontLeg, bodyPart, frontArm] { n.run(flash) }
        guard !reduced else { return }
        run(.sequence([.moveBy(x: -10, y: 0, duration: 0.04), .moveBy(x: 12, y: 0, duration: 0.06), .moveBy(x: -2, y: 0, duration: 0.05)]))
    }

    func stunned(_ on: Bool) {
        rig.removeAction(forKey: "stun")
        if on {
            rig.run(.repeatForever(.sequence([.rotate(toAngle: 0.08, duration: 0.15), .rotate(toAngle: -0.08, duration: 0.15)])), withKey: "stun")
        } else {
            rig.run(.rotate(toAngle: 0, duration: 0.1))
        }
    }

    /// 丢了一条命：身子沉下去、弯腰往前栽，两腿微微叉开撑住，剑垂到地上（腿是一节的，做不出真跪，用弯腰撑住来表现）。
    func kneel(reduced: Bool) {
        rig.removeAction(forKey: "idle")
        guard !reduced else { rig.run(.fadeAlpha(to: 0.6, duration: 0.2)); return }
        let t = 0.18
        let drop = SKAction.group([.moveTo(y: -20, duration: t), .rotate(toAngle: -0.32, duration: t)])
        drop.timingMode = .easeOut
        rig.run(drop)
        frontLeg.run(.rotate(toAngle: 0.5, duration: t))
        backLeg.run(.rotate(toAngle: -0.2, duration: t))
        frontArm.run(.rotate(toAngle: -0.7, duration: t))
    }

    /// 站起来，回到站姿。
    func standUp(reduced: Bool) {
        let t = 0.22
        for leg in [frontLeg, backLeg, frontArm] { leg.run(.rotate(toAngle: 0, duration: t)) }
        rig.run(.sequence([.group([.move(to: .zero, duration: t), .rotate(toAngle: 0, duration: t), .fadeAlpha(to: 1, duration: t)]),
                           .run { [weak self] in self?.idle(reduced: reduced) }]))
    }

    func knockDown(reduced: Bool) {
        rig.removeAllActions()
        if reduced {
            run(.fadeAlpha(to: 0.25, duration: 0.3))
            return
        }
        // 往后倒：本地坐标里 -x 是远离对手的方向（镜像的对手同样成立）
        let fall = SKAction.group([.rotate(toAngle: 0.5, duration: 0.45), .moveBy(x: -30, y: 0, duration: 0.45), .fadeAlpha(to: 0.3, duration: 0.6)])
        fall.timingMode = .easeOut
        rig.run(fall)
    }
}
