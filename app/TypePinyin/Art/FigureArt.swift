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
        /// 正式美术的暗面：在这个形状里铺一层网点（ArtStyle），不填色不描边。
        var dots = false
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
        /// 贴图缓存的键（正式美术按外形生成；旧画法为空，每次重画）。
        var key: String? = nil
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

    /// 主角赶路的样子（长卷上的小人；比武里用 `player()` 的战斗姿势）：剑背在身后，两手垂着。
    /// step：0 = 站着，1 = 迈步（前腿往前、后腿往后），2 = 另一只脚迈步。身子和头和战斗时一样。
    static func playerTravel(step: Int = 0, accent: UIColor = UIColor(hex: 0xE2432C)) -> Figure {
        let fight = player(accent: accent)
        // 两腿：站着并拢一点；迈步时一前一后，手臂反着摆
        let (back, front, swing): (String, String, CGFloat) = switch step {
        case 1: ("M -4 -72 Q -14 -40 -22 -4", "M 4 -72 Q 16 -40 22 -4", 1)
        case 2: ("M -4 -72 Q 4 -40 10 -4", "M 4 -72 Q -2 -40 -8 -4", -1)
        default: ("M -4 -72 Q -8 -40 -11 -4", "M 4 -72 Q 8 -40 11 -4", 0)
        }
        let footX: (String) -> CGFloat = { d in CGFloat(Double(d.split(separator: " ")[d.split(separator: " ").count - 2]) ?? 0) }
        return Figure(
            backArm: Part(shapes: [
                // 背在身后的剑：剑鞘斜挎，剑柄从右肩上露出来
                p("M -20 -80 L 20 -142", stroke: ink, width: 7, cap: .round),
                p("M -20 -80 L 20 -142", stroke: navy, width: 3.5, cap: .round),
                p("M 16 -136 L 25 -142", stroke: gold, width: 4, cap: .round),
                p("M 20 -142 L 26 -152", stroke: ink, width: 4, cap: .round),
                p("M -9 -120 Q \(-16 - 4 * swing) -106 \(-15 - 6 * swing) -92 L \(-8 - 6 * swing) -92 Q -8 -106 -3 -116 Z", fill: white),
                circle(-12 - 6 * swing, -89, 4, fill: skin),
            ], pivot: CGPoint(x: -10, y: -116)),
            backLeg: Part(shapes: leg(back, foot: ellipse(footX(back) - 1, -3, 9, 4.5, fill: ink)), pivot: CGPoint(x: -4, y: -72)),
            frontLeg: Part(shapes: leg(front, foot: ellipse(footX(front) + 2, -3, 9, 4.5, fill: ink)), pivot: CGPoint(x: 4, y: -72)),
            body: fight.body,
            frontArm: Part(shapes: [
                p("M 9 -120 Q \(16 + 4 * swing) -106 \(14 + 6 * swing) -92 L \(7 + 6 * swing) -92 Q 7 -106 3 -116 Z", fill: white),
                circle(11 + 6 * swing, -89, 4, fill: skin),
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

    /// 把形状画进画布；silhouette = 全部填黑（画廊页的剪影模式），网点跳过。
    static func draw(_ shapes: [Shape], in g: CGContext, silhouette: Bool = false) {
        g.setLineJoin(.round)
        for s in shapes {
            if s.dots {
                if !silhouette { ArtStyle.fillDots(g, path: s.path, spacing: ArtStyle.figureDotSpacing, radius: ArtStyle.figureDotRadius) }
                continue
            }
            if let f = s.fill {
                g.addPath(s.path)
                g.setFillColor((silhouette ? ink : f).cgColor)
                g.fillPath()
            }
            if let st = s.stroke, s.width > 0 {
                g.addPath(s.path)
                g.setStrokeColor((silhouette ? ink : st).cgColor)
                g.setLineWidth(s.width)
                g.setLineCap(s.cap)
                g.strokePath()
            }
        }
    }

    /// 整个人站着的样子画成一张图（画廊页、长卷上的小人用）。
    static func image(_ f: Figure, height: CGFloat, silhouette: Bool = false) -> UIImage {
        let all = [f.backArm, f.backLeg, f.frontLeg, f.body, f.frontArm].flatMap(\.shapes)
        var box = CGRect.null
        for s in all { box = box.union(s.path.boundingBoxOfPath.insetBy(dx: -s.width / 2 - 2, dy: -s.width / 2 - 2)) }
        let k = height / box.height
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: box.width * k, height: height), format: format).image { ctx in
            let g = ctx.cgContext
            g.scaleBy(x: k, y: k)
            g.translateBy(x: -box.minX, y: -box.minY)
            draw(all, in: g, silhouette: silhouette)
        }
    }

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
            draw(part.shapes, in: g)
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
    /// 包在 rig 外面的一层，只做预备动作的退、压扁、后仰（rig 自己的位置和转角归待机呼吸、晕眩用）。
    private let pose = SKNode()

    init(_ figure: FigureArt.Figure) {
        super.init()
        // 脚下的影子：贴着地，不跟身体一起晃（在 rig 外面），让人看得出是站在地上
        let shadow = SKSpriteNode(texture: Self.shadowTexture)
        shadow.size = CGSize(width: 116, height: 16)
        shadow.position = CGPoint(x: 0, y: 1)
        shadow.zPosition = -1
        addChild(shadow)
        addChild(pose)
        pose.addChild(rig)
        for (k, (node, part)) in [(backArm, figure.backArm), (backLeg, figure.backLeg), (frontLeg, figure.frontLeg),
                                  (bodyPart, figure.body), (frontArm, figure.frontArm)].enumerated() {
            let (tex, anchor, size) = Self.texture(part, key: figure.key.map { "\($0)#\(k)" })
            node.texture = tex
            node.size = size
            node.anchorPoint = anchor
            node.position = CGPoint(x: part.pivot.x, y: -part.pivot.y)
            rig.addChild(node)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 同一个外形的人第二次出场不重画贴图（正式美术的部件画得细，重画一次要几毫秒）。
    private static var textureCache: [String: (SKTexture, CGPoint, CGSize)] = [:]

    private static func texture(_ part: FigureArt.Part, key: String?) -> (SKTexture, CGPoint, CGSize) {
        if let key, let hit = textureCache[key] { return hit }
        let started = CACurrentMediaTime()
        let made = FigureArt.texture(for: part)
        if key != nil { SceneRenderer.log("人物部件", since: started) }
        if let key { textureCache[key] = made }
        return made
    }

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
        pose.removeAllActions()
        pose.position = .zero
        pose.zRotation = 0
        pose.xScale = 1
        pose.yScale = 1
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
    static func slashTimes(slashes: Int, per: Double, dash: Double = 0.08) -> [Double] {
        (0..<slashes).map { dash + Double($0) * per + per * 0.45 }
    }

    // Motion Prompt #121 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#121
    /// 预备动作（Motion Prompt #121 アンティシペーション）：出招前往反方向退一点、压扁、后仰攒劲，冲出去时拉长、前倾，
    /// 到位后上下一抖收住。原版溜め 0.75 秒、飛び出し 0.43 秒；这里整体按 k = wind / 0.75 等比缩短，
    /// 冲出去那段（0.43k）就是 dashAndSlash 的冲刺时长。back 是退的距离（场景点数）。
    /// 原版是圆角方块角色，压扁到纵 0.76、拉长到横 1.55；放在人身上看着像整个人缩小再还原（试玩反馈），
    /// 所以形变改小（纵最低 0.95、横最高 1.1），攒劲主要靠退得多一点（1.5 倍）和后仰更多（0.26rad）。
    static let windUpFull = 0.75
    static func launchSeconds(wind: Double) -> Double { wind > 0 ? 0.43 * wind / windUpFull : 0.08 }

    func windUp(seconds wind: Double, back: CGFloat) {
        guard wind > 0 else { return }
        let k = wind / Self.windUpFull
        let go = 0.43 * k, settle = 0.8 * k
        let b = 1.5 * back / max(0.01, abs(xScale))                  // pose 在人物里面，距离要按人物的缩放折回去
        let eIO: (CGFloat) -> CGFloat = { x in x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2 }
        let backOut: (CGFloat, CGFloat) -> CGFloat = { x, s in 1 + (s + 1) * pow(x - 1, 3) + s * pow(x - 1, 2) }
        // 溜め：easeInOut（2 次）往后退、横 1→1.03、纵 1→0.95、后仰 0.26rad（原版 1.22 / 0.76 / 0.18）
        let windAct = SKAction.customAction(withDuration: wind) { n, t in
            let w = eIO(min(1, t / CGFloat(wind)))
            n.position.x = -b * w
            n.xScale = 1 + 0.03 * w
            n.yScale = 1 - 0.05 * w
            n.zRotation = 0.26 * w
        }
        // 飛び出し：backOut(s=1.1) 回到原位（略冲过头），前 60% 拉长到横 1.1、纵 0.96（原版 1.55 / 0.72），前倾 0.12rad
        let goAct = SKAction.customAction(withDuration: go) { n, t in
            let g = min(1, t / CGFloat(go))
            n.position.x = -b * (1 - backOut(g, 1.1))
            let st = g < 0.6 ? sin(.pi * g / 0.6) : 0
            n.xScale = 1 + 0.1 * st
            n.yScale = 1 - 0.04 * st
            n.zRotation = -0.12 * st
        }
        // 着地：0.04·e^(−7t)·sin(17t) 纵横反着抖（原版 0.13；t 同样按 k 缩）
        let settleAct = SKAction.customAction(withDuration: settle) { n, t in
            let u = Double(t) / k
            let wob = CGFloat(0.04 * exp(-7 * u) * sin(17 * u))
            n.position.x = 0
            n.zRotation = 0
            n.xScale = 1 + wob
            n.yScale = 1 - wob
        }
        let reset = SKAction.run { [weak self] in
            guard let p = self?.pose else { return }
            p.position = .zero; p.zRotation = 0; p.xScale = 1; p.yScale = 1
        }
        pose.removeAction(forKey: "windUp")
        pose.run(.sequence([windAct, goAct, settleAct, reset]), withKey: "windUp")
    }

    /// 大招后收刀：剑慢慢收到身后，停一拍，再回到平常。
    func sheathe() {
        frontArm.run(.sequence([.wait(forDuration: 0.12), .rotate(toAngle: -1.3, duration: 0.28), .wait(forDuration: 0.45),
                                .rotate(toAngle: 0, duration: 0.25)]), withKey: "swing")
    }

    /// 冲到对手面前、斩 n 刀、退回。返回每一刀落下的时刻（秒）。
    func dashAndSlash(distance: CGFloat, slashes: Int, per: Double = 0.11, dash: Double = 0.08, reduced: Bool) -> [Double] {
        let back = 0.16
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

    // Motion Prompt #123 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#123
    /// 倒地：原地往后倒平（不飞出去，群战里不会撞到后面的人），像被砸下去一样越倒越快；
    /// 触地弹两下（Motion Prompt #123 バウンス：每次反弹速度剩 56%，弹起的高度剩 0.56² ≈ 31%），扬起一小团墨尘，然后淡出（约 0.7 秒演完）。
    /// 原来是往后斜 0.5 弧度、滑 30 点、淡到三成，人没躺到地上，看着像渐渐消失。
    /// fade = false：倒下后躺着不消失（主角输了用）。
    func knockDown(reduced: Bool, fade: Bool = true) {
        rig.removeAllActions()
        pose.removeAllActions()
        pose.position = .zero; pose.zRotation = 0; pose.xScale = 1; pose.yScale = 1
        if reduced {
            run(fade ? .sequence([.fadeAlpha(to: 0.25, duration: 0.3), .wait(forDuration: 0.2), .fadeOut(withDuration: 0.2)])
                     : .fadeAlpha(to: 0.4, duration: 0.3))
            return
        }
        let fallT = 0.3
        let fall = SKAction.rotate(toAngle: 1.42, duration: fallT)       // 本地坐标里 -x 是远离对手的方向，正转就是往后倒
        fall.timingMode = .easeIn
        let h1: CGFloat = 8, h2 = h1 * 0.56 * 0.56
        func hop(_ h: CGFloat, _ t: Double) -> SKAction {
            let up = SKAction.moveBy(x: 0, y: h, duration: t); up.timingMode = .easeOut
            let down = SKAction.moveBy(x: 0, y: -h, duration: t); down.timingMode = .easeIn
            return .sequence([up, down])
        }
        rig.run(.sequence([fall, .run { [weak self] in self?.inkDust() }, hop(h1, 0.07), hop(h2, 0.04)]))
        if fade { run(.sequence([.wait(forDuration: fallT + 0.2), .fadeOut(withDuration: 0.22)])) }
    }

    /// 倒地扬起的一小团墨尘：沿着倒下的身子几团淡墨往外鼓、往上飘、散掉。
    private func inkDust() {
        for i in 0..<5 {
            let r = CGFloat.random(in: 9...15)
            let puff = SKShapeNode(circleOfRadius: r)
            puff.fillColor = Palette.uiInk.withAlphaComponent(0.5)
            puff.strokeColor = .clear
            puff.position = CGPoint(x: -20 - CGFloat(i) * 26 + .random(in: -6...6), y: 6)
            puff.zPosition = -0.5
            puff.setScale(0.4)
            addChild(puff)
            let drift = SKAction.moveBy(x: .random(in: -10...10), y: .random(in: 10...22), duration: 0.45)
            drift.timingMode = .easeOut
            puff.run(.sequence([.group([.scale(to: 1.4, duration: 0.45), drift, .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
        }
    }
}
