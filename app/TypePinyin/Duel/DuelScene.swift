import SpriteKit
import UIKit

/// 战斗区：藏青底、太阳、放射线、网点、黑色地面，双方人物和命中特效。
@MainActor
final class DuelScene: SKScene {
    private let background = SKSpriteNode()
    private let world = SKNode()
    private var player: FigureNode?
    private var foe: FigureNode?
    private let fx = SKNode()
    private let rays = SKNode()
    private let bunting = SKNode()
    /// 二档气势以上主角身后的光晕。用贴图精灵（白圆，染色），不用矢量形状：矢量形状每帧都要单独画，很耗。
    private let aura = SKSpriteNode(texture: SKTexture(image: DuelScene.discImage(radius: 70)))
    private(set) var heat = 0
    var reducedMotion = UIAccessibility.isReduceMotionEnabled

    /// 地面高度随战斗区高度变化：大屏 52 pt，小屏按比例缩小。
    static func groundHeight(for h: CGFloat) -> CGFloat { min(52, max(26, h * 0.16)) }
    private var ground: CGFloat { Self.groundHeight(for: size.height) }

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = Palette.uiNavy
        anchorPoint = .zero
        addChild(background)
        addChild(rays)
        rays.zPosition = -9
        addChild(bunting)
        bunting.zPosition = -8
        bunting.alpha = 0
        addChild(world)
        aura.zPosition = -1
        aura.colorBlendFactor = 1
        aura.alpha = 0
        world.addChild(aura)
        world.addChild(fx)
        fx.zPosition = 10
        let p = FigureNode(FigureArt.player())
        player = p
        world.addChild(p)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 特效用：对手胸口、主角持剑的手、特效层。
    var foeAnchor: CGPoint? { foe.map { CGPoint(x: $0.position.x - 10, y: $0.position.y + 100 * $0.yScale) } }
    /// 主角空着的后手（场景坐标），取字（剑气、绳镖）从这里出手、收回，跟着手一起动。
    var playerHand: CGPoint? { player.map { $0.backArm.convert(FigureNode.backHand, to: self) } }

    /// 绳镖：后手甩出去、拽回；接住字母时后手闪一下。
    func throwDart(wind: Double, out: Double, hold: Double, back: Double = 0) {
        if !reducedMotion { player?.throwDart(wind: wind, out: out, hold: hold, back: back) }
    }
    func yankDart(back: Double) { if !reducedMotion { player?.yankDart(back: back) } }
    func handFlash(big: Bool = false) { player?.flashHand(color: heat >= 3 ? Palette.uiRed : Palette.uiGold, big: big) }

    /// 剑气打进主角身上：胸口亮一圈；一整团（一个音节）打进来时圈更大，再迸一圈火星。
    func bodyAbsorb(big: Bool) {
        guard let p = playerChest else { return }
        let color: UIColor = heat >= 3 ? Palette.uiRed : Palette.uiGold
        let ring = cached("ring|\(color.hashValue)") {
            let n = SKShapeNode(circleOfRadius: 16)
            n.strokeColor = color
            n.lineWidth = 5
            n.fillColor = color.withAlphaComponent(0.3)
            return n
        }
        ring.position = p
        ring.zPosition = 8
        ring.setScale(big ? 0.9 : 0.6)
        fx.addChild(ring)
        ring.run(.sequence([.group([.scale(to: big ? 2.4 : 1.6, duration: big ? 0.28 : 0.2), .fadeOut(withDuration: big ? 0.28 : 0.2)]), .removeFromParent()]))
        guard big else { return }
        let star = cached("sparks|\(color.hashValue)") {
            let n = SKNode()
            for i in 0..<6 {
                let a = CGFloat(i) / 6 * .pi * 2 + 0.3
                let path = CGMutablePath()
                path.move(to: CGPoint(x: cos(a) * 8, y: sin(a) * 8))
                path.addLine(to: CGPoint(x: cos(a) * 18, y: sin(a) * 18))
                let l = SKShapeNode(path: path)
                l.strokeColor = color
                l.lineWidth = 3
                l.lineCap = .round
                n.addChild(l)
            }
            return n
        }
        star.position = p
        star.zPosition = 8
        star.setScale(player?.yScale ?? 1)
        star.zRotation = .random(in: 0...(.pi))
        fx.addChild(star)
        star.run(.sequence([.group([.scale(by: 1.7, duration: 0.16), .fadeOut(withDuration: 0.16)]), .removeFromParent()]))
    }

    /// 主角胸口（场景坐标），剑气打进这里。
    var playerChest: CGPoint? { player.map { CGPoint(x: $0.position.x + 8 * $0.xScale, y: $0.position.y + 100 * $0.yScale) } }

    func setFoe(robe: UIColor) {
        foe?.removeFromParent()
        let f = FigureNode(FigureArt.guardsman(robe: robe))
        f.xScale = -1
        foe = f
        world.addChild(f)
        layoutFigures()
        f.idle(reduced: reducedMotion)
        player?.idle(reduced: reducedMotion)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        background.texture = SKTexture(image: Self.renderBackground(size: size))
        background.size = size
        background.anchorPoint = .zero
        background.position = .zero
        background.zPosition = -10
        buildRays()
        buildBunting()
        layoutFigures()
        prewarm()            // 人物大小变了，剑光和字母的贴图尺寸也跟着变
    }

    /// 放射光：气势越高转得越快、越亮。
    private func buildRays() {
        rays.removeAllChildren()
        let r = max(size.width, size.height) * 1.2
        let path = CGMutablePath()
        for k in 0..<12 {
            let a0 = CGFloat(k) * .pi / 6, a1 = a0 + .pi / 14
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: cos(a0) * r, y: sin(a0) * r))
            path.addLine(to: CGPoint(x: cos(a1) * r, y: sin(a1) * r))
            path.closeSubpath()
        }
        // 放射光画成一张图再转（1 倍分辨率就够，本来就很淡），不用矢量形状：一直在转，矢量形状每帧都要重画
        let img = UIGraphicsImageRenderer(size: CGSize(width: r * 2, height: r * 2), format: {
            let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f
        }()).image { ctx in
            ctx.cgContext.translateBy(x: r, y: r)
            ctx.cgContext.addPath(path)
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillPath()
        }
        let wedges = SKSpriteNode(texture: SKTexture(image: img))
        wedges.colorBlendFactor = 1
        wedges.color = .white
        wedges.alpha = 0.07
        wedges.name = "wedges"
        rays.addChild(wedges)
        rays.position = CGPoint(x: size.width * 0.52, y: size.height * 0.5)
        applyHeat(animated: false)
    }

    /// 彩旗：气势一档起挂出来。
    private func buildBunting() {
        bunting.removeAllChildren()
        let colors: [UIColor] = [Palette.uiRed, Palette.uiGold, .white, UIColor(hex: 0x2E9A6A), Palette.uiGold]
        let rope = SKShapeNode()
        let rp = CGMutablePath()
        rp.move(to: CGPoint(x: 0, y: size.height - 8))
        rp.addQuadCurve(to: CGPoint(x: size.width, y: size.height - 8), control: CGPoint(x: size.width / 2, y: size.height - 30))
        rope.path = rp
        rope.strokeColor = Palette.uiInk
        rope.lineWidth = 2
        bunting.addChild(rope)
        let n = 12
        for k in 0..<n {
            let t = (CGFloat(k) + 0.5) / CGFloat(n)
            let x = t * size.width
            let y = size.height - 8 - 22 * 4 * t * (1 - t) * 0.9
            let tri = CGMutablePath()
            tri.move(to: CGPoint(x: -9, y: 0)); tri.addLine(to: CGPoint(x: 9, y: 0)); tri.addLine(to: CGPoint(x: 0, y: -18)); tri.closeSubpath()
            let flag = SKShapeNode(path: tri)
            flag.fillColor = colors[k % colors.count]
            flag.strokeColor = Palette.uiInk
            flag.lineWidth = 2
            flag.position = CGPoint(x: x, y: y)
            bunting.addChild(flag)
        }
        // 彩旗合成一张贴图（十几个矢量形状每帧单独画很耗）
        let frame = bunting.calculateAccumulatedFrame()
        if let t = view?.texture(from: bunting) {
            bunting.removeAllChildren()
            let sp = SKSpriteNode(texture: t)
            sp.position = CGPoint(x: frame.midX, y: frame.midY)
            bunting.addChild(sp)
        }
    }

    /// 白色实心圆（光晕贴图，用时再染色）。
    static func discImage(radius: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: radius * 2, height: radius * 2)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2))
        }
    }

    /// 气势档位：0 平静，1 彩旗 + 放射光慢转，2 加金色光环和墨点，3 红色光环、转得最快。
    func setHeat(_ level: Int) {
        let up = level > heat
        heat = level
        applyHeat(animated: true)
        if up && level > 0 { levelUpBurst() }
    }

    private func applyHeat(animated: Bool) {
        let d = animated ? 0.4 : 0
        rays.removeAction(forKey: "spin")
        if !reducedMotion && heat > 0 {
            let speed: [CGFloat] = [0, 0.15, 0.35, 0.7]
            rays.run(.repeatForever(.rotate(byAngle: speed[heat] * 2 * .pi, duration: 6)), withKey: "spin")
        }
        if let w = rays.childNode(withName: "wedges") as? SKSpriteNode {
            w.run(.fadeAlpha(to: [0.07, 0.12, 0.18, 0.26][heat], duration: d))
            w.color = heat >= 3 ? Palette.uiGold : .white
        }
        bunting.run(.fadeAlpha(to: heat >= 1 ? 1 : 0, duration: d))
        aura.removeAction(forKey: "pulse")
        if heat >= 2, let p = player {
            aura.color = heat >= 3 ? Palette.uiRed : Palette.uiGold
            aura.position = CGPoint(x: p.position.x, y: p.position.y + 80 * p.yScale)
            aura.setScale(p.yScale)
            aura.run(.fadeAlpha(to: 0.55, duration: d))
            if !reducedMotion {
                aura.run(.repeatForever(.sequence([.scale(to: p.yScale * 1.12, duration: 0.35), .scale(to: p.yScale * 0.95, duration: 0.35)])), withKey: "pulse")
            }
        } else {
            aura.run(.fadeAlpha(to: 0, duration: d))
        }
    }

    /// 升档：满屏彩纸。
    private func levelUpBurst() {
        guard !reducedMotion else { return }
        let colors: [UIColor] = [Palette.uiRed, Palette.uiGold, .white, UIColor(hex: 0x2E9A6A), UIColor(hex: 0x4F6BB0)]
        for k in 0..<36 {
            let piece = SKShapeNode(rectOf: CGSize(width: 7, height: 11), cornerRadius: 1)
            piece.fillColor = colors[k % colors.count]
            piece.strokeColor = Palette.uiInk
            piece.lineWidth = 1
            piece.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + 10)
            piece.zRotation = CGFloat.random(in: 0...(.pi))
            fx.addChild(piece)
            let fall = SKAction.group([
                .moveBy(x: CGFloat.random(in: -40...40), y: -size.height - 30, duration: Double.random(in: 1.0...1.8)),
                .rotate(byAngle: CGFloat.random(in: -6...6), duration: 1.6),
            ])
            piece.run(.sequence([.wait(forDuration: Double(k) * 0.012), fall, .removeFromParent()]))
        }
    }

    /// 每打对一个字母：主角往前一顿。
    func letterTick() {
        guard !reducedMotion, let p = player else { return }
        p.removeAction(forKey: "tick")
        p.run(.sequence([.moveBy(x: 4, y: 0, duration: 0.03), .moveBy(x: -4, y: 0, duration: 0.07)]), withKey: "tick")
    }

    /// 两人站位（占战斗区宽度的比例）。
    private static let playerX: CGFloat = 0.22, foeX: CGFloat = 0.80

    /// 脚踩的高度：在地面那条深色带里往下约一半，像站在地上（踩在地面线上会像悬在空中）。
    private var feet: CGFloat { ground * 0.55 }

    /// 人物大小随战斗区高度缩放（屏幕窄时再按宽度缩），脚踩在地上。
    private func layoutFigures() {
        // 人物从脚到头顶约 165 pt；头顶上方留出约 84 pt 给对手头上的来招框，不让来招框挡住人物
        let tall = (size.height - feet - 84) / 165
        // 再按宽度限制：主角剑往前伸 124、对手刀往前伸 98（人物坐标），两人站在 22% 和 80%，兵器之间至少空 20 pt
        let wide = (size.width * (Self.foeX - Self.playerX) - 20) / (124 + 98)
        let scale = min(1.15, max(0.45, min(tall, wide)))
        groupBaseScale = scale
        player?.setScale(groupMode ? scale * Self.groupBody * Self.heroInGroup : scale)    // 群战时主角缩小，但不比场上最大的敌人小
        player?.position = CGPoint(x: size.width * Self.playerX, y: feet)
        if let f = foe {
            f.yScale = scale
            f.xScale = -scale
            f.position = CGPoint(x: size.width * Self.foeX, y: feet)
        }
    }

    static func renderBackground(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let g = ctx.cgContext
            let w = size.width, h = size.height
            g.setFillColor(Palette.uiNavy.cgColor)
            g.fill(CGRect(origin: .zero, size: size))
            let sun = CGPoint(x: w * 0.81, y: h * 0.24)
            g.setFillColor(Palette.uiGold.cgColor)
            g.fillEllipse(in: CGRect(x: sun.x - 48, y: sun.y - 48, width: 96, height: 96))   // 原来半径 74，太抢眼，缩到三分之二
            g.setFillColor(UIColor.white.withAlphaComponent(0.16).cgColor)
            let groundHeight = Self.groundHeight(for: h)
            var y: CGFloat = h * 0.62
            while y < h - groundHeight {
                var x: CGFloat = 4
                while x < w { g.fillEllipse(in: CGRect(x: x - 1.6, y: y - 1.6, width: 3.2, height: 3.2)); x += 8 }
                y += 8
            }
            g.setFillColor(Palette.uiInk.cgColor)
            g.fill(CGRect(x: 0, y: h - groundHeight, width: w, height: groundHeight))
            g.setStrokeColor(Palette.uiGold.cgColor)
            g.setLineWidth(3)
            g.move(to: CGPoint(x: 0, y: h - groundHeight)); g.addLine(to: CGPoint(x: w, y: h - groundHeight))
            g.strokePath()
        }
    }

    // MARK: - 演出

    /// 剑上聚的气（0…1），随打对的字母增加。
    func setCharge(_ k: CGFloat) {
        let color: UIColor = heat >= 3 ? Palette.uiRed : Palette.uiGold
        player?.setSwordGlow(k, color: color)
    }

    /// 主角出招：冲到对手面前，词有几个字就斩几刀，每一刀的剑光里写出一个字。
    /// `onHit(k)` 在第 k 刀落下时回调（用来放声音、震动和回顾牌的逐字点亮）。返回每一刀落下的时刻。
    @discardableResult
    /// 一个字母一刀：`labels` 是每一刀写在剑光里的字母。字母多时每刀更快，整套不超过一秒左右。
    func heroStrike(labels: [String], damage: Int, heavy: Bool, flaw: Bool, finisher: Bool, lethal: Bool = false, combo: Int, minGap: Double = 0.075, onHit: @escaping (Int) -> Void) -> [Double] {
        guard let p = player, let f = foe else { return [0] }
        let chars = labels
        let n = max(1, chars.count)
        // 冲到剑尖刚好够到对手身体的地方停下（剑长 124），不冲进对手怀里叠在一起
        let gap = f.position.x - p.position.x - 118 * p.yScale
        // 每刀间隔：短词 0.1 秒；长词压缩但不低于 minGap（调参面板可选 0.06 / 0.075 秒）
        let per = chars.count <= 5 ? 0.1 : max(minGap, 0.6 / Double(chars.count))
        // 必杀：先蓄力半秒（场地变暗、剑光拉满、身上气浪外扩），再冲上去连斩
        let pre = finisher && !reducedMotion ? 0.5 : 0
        let times = FigureNode.slashTimes(slashes: n, per: per).map { $0 + pre }
        if pre > 0 {
            finisherCharge()
            run(.wait(forDuration: pre)) { [weak self] in
                guard let self, let p = self.player else { return }
                _ = p.dashAndSlash(distance: max(0, gap), slashes: n, per: per, reduced: self.reducedMotion)
            }
        } else {
            _ = p.dashAndSlash(distance: max(0, gap), slashes: n, per: per, reduced: reducedMotion)
        }
        let color: UIColor = finisher || heat >= 3 ? Palette.uiRed : Palette.uiGold
        for (k, t) in times.enumerated() {
            run(.wait(forDuration: t)) { [weak self] in
                guard let self else { return }
                let ch = k < chars.count ? chars[k] : ""
                let last = k == times.count - 1
                PerfLog.measure("出刀剑光") { self.slash(char: ch, index: k, color: color, big: last) }
                self.foe?.hurt(reduced: self.reducedMotion)
                if last {
                    self.burst(damage: damage, big: heavy || flaw || finisher || combo >= 8, gold: combo >= 8, red: combo >= 15)
                    if self.heat >= 2 { self.inkSplash() }
                    if finisher && self.groupMode { self.groupHurtAll() }   // 群战：必杀打全场
                    if finisher || lethal {
                        self.finisherImpact()           // 必杀和打空对手血条的那一刀：顿帧、白闪、大交叉、击飞
                    } else {
                        self.hitStop(0.05)          // 最后一刀顿一下，和前面几刀区分开
                        if heavy { self.shake(amount: 5) }
                    }
                    self.setCharge(0)
                }
                PerfLog.measure("出刀回调") { onHit(k) }
            }
        }
        return times
    }

    /// 顿帧：场景几乎停住一小会儿，打击感更重。
    private var hitStopDepth = 0
    private var hitStopSpeed: CGFloat = 1
    private func hitStop(_ seconds: Double) {
        guard !reducedMotion else { return }
        if hitStopDepth == 0 { hitStopSpeed = speed }
        hitStopDepth += 1
        speed = hitStopSpeed * 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self else { return }
            self.hitStopDepth -= 1
            if self.hitStopDepth == 0 { self.speed = self.hitStopSpeed }
        }
    }

    /// 必杀蓄力：场地变暗，剑光拉满变红，主角身上一圈圈气浪往外扩。
    private func finisherCharge() {
        let dim = SKSpriteNode(color: .black, size: size)
        dim.anchorPoint = .zero
        dim.zPosition = -3
        dim.alpha = 0
        dim.name = "dim"
        addChild(dim)
        dim.run(.fadeAlpha(to: 0.45, duration: 0.15))
        player?.setSwordGlow(1, color: Palette.uiRed)
        guard let c = playerChest else { return }
        for i in 0..<3 {
            run(.wait(forDuration: Double(i) * 0.14)) { [weak self] in
                guard let self else { return }
                let ring = self.cached("ring|\(Palette.uiRed.hashValue)") {
                    let n = SKShapeNode(circleOfRadius: 16)
                    n.strokeColor = Palette.uiRed
                    n.lineWidth = 5
                    n.fillColor = Palette.uiRed.withAlphaComponent(0.3)
                    return n
                }
                ring.position = c
                ring.zPosition = 8
                ring.setScale(0.8)
                self.fx.addChild(ring)
                ring.run(.sequence([.group([.scale(to: 4, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
            }
        }
    }

    /// 必杀落下：顿帧、全屏白闪、对手身上斩出大交叉、重震、对手被击飞；之后场地亮回来，主角收刀。
    private func finisherImpact() {
        guard let f = foe else { return }
        hitStop(0.18)
        let flash = SKSpriteNode(color: .white, size: size)
        flash.anchorPoint = .zero
        flash.zPosition = 20
        flash.alpha = 0.85
        addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        let c = CGPoint(x: f.position.x - 10 * f.yScale, y: f.position.y + 90 * f.yScale)
        let len = 300 * f.yScale
        for angle in [0.75, -0.75] as [CGFloat] {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -len / 2, y: 0)); path.addLine(to: CGPoint(x: len / 2, y: 0))
            let line = SKShapeNode(path: path)
            line.strokeColor = Palette.uiRed
            line.lineWidth = 14
            line.lineCap = .round
            let core = SKShapeNode(path: path)
            core.strokeColor = .white
            core.lineWidth = 5
            core.lineCap = .round
            line.addChild(core)
            line.position = c
            line.zRotation = angle
            line.zPosition = 12
            line.xScale = 0.2
            fx.addChild(line)
            line.run(.sequence([.scaleX(to: 1, duration: 0.08), .wait(forDuration: 0.15), .fadeOut(withDuration: 0.35), .removeFromParent()]))
        }
        shake(amount: 12)
        f.run(.sequence([.moveBy(x: 40, y: 0, duration: 0.1), .wait(forDuration: 0.1), .moveBy(x: -40, y: 0, duration: 0.35)]))
        run(.wait(forDuration: 0.35)) { [weak self] in
            guard let self else { return }
            self.childNode(withName: "dim")?.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
            self.player?.sheathe()
        }
    }

    private func arcNode(color: UIColor, r: CGFloat) -> SKNode {
        return cached("arc|\(color.hashValue)|\(Int(r))") {
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: r, startAngle: .pi * 0.85, endAngle: .pi * 0.15, clockwise: true)
            let core = SKShapeNode(path: path)
            core.strokeColor = color
            core.lineWidth = 10
            core.lineCap = .round
            let halo = SKShapeNode(path: path)      // 光晕：宽一点的半透明线（不用 glowWidth）
            halo.strokeColor = color.withAlphaComponent(0.35)
            halo.lineWidth = 24
            halo.lineCap = .round
            halo.zPosition = -1
            core.addChild(halo)
            return core
        }
    }

    private func glyphNode(_ char: String, size: CGFloat) -> SKNode {
        return cached("glyph|\(char)|\(Int(size))") {
            let l = SKLabelNode(text: char)
            l.fontName = Fonts.displayName
            l.fontSize = size
            l.fontColor = .white
            l.verticalAlignmentMode = .center
            let outline = SKLabelNode(text: char)
            outline.fontName = Fonts.displayName
            outline.fontSize = size
            outline.fontColor = Palette.uiInk
            outline.verticalAlignmentMode = .center
            outline.position = CGPoint(x: 3, y: -3)
            outline.zPosition = -1
            l.addChild(outline)
            return l
        }
    }

    /// 开场先把 26 个字母和两种颜色的剑光画成贴图：第一次现画会卡一下，正好卡在出刀的时候。
    func prewarm() {
        guard view != nil, let f = foe else { return }
        let r: CGFloat = 70 * f.yScale
        let size = 46 * f.yScale + 6
        for color in [Palette.uiGold, Palette.uiRed] { _ = arcNode(color: color, r: r) }
        for ch in "abcdefghijklmnopqrstuvwxyz" { _ = glyphNode(String(ch), size: size) }
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        prewarm()
    }

    /// 一刀剑光：一道弧线，弧线中间写出这一刀对应的字。
    /// 剑光和字母画成贴图后缓存起来复用：每刀都新建形状、重新排字很耗，一个词连砍七八刀时会卡。
    private var textureCache: [String: SKTexture] = [:]

    /// 取（或第一次画好）缓存贴图，放在一个以 node 原点为中心的容器里，旋转、缩放都绕原点。
    private func cached(_ key: String, build: () -> SKNode) -> SKNode {
        let holder = SKNode()
        if let t = textureCache[key] {
            let sp = SKSpriteNode(texture: t)
            sp.position = textureOffset[key] ?? .zero
            holder.addChild(sp)
            return holder
        }
        let n = build()
        let frame = n.calculateAccumulatedFrame()
        if let t = view?.texture(from: n) {
            textureCache[key] = t
            textureOffset[key] = CGPoint(x: frame.midX, y: frame.midY)
            let sp = SKSpriteNode(texture: t)
            sp.position = CGPoint(x: frame.midX, y: frame.midY)
            holder.addChild(sp)
        } else {
            holder.addChild(n)
        }
        return holder
    }
    private var textureOffset: [String: CGPoint] = [:]

    /// 一刀剑光：一道弧线，弧线中间写出这一刀对应的字母。
    private func slash(char: String, index: Int, color: UIColor, big: Bool = false) {
        guard let f = foe else { return }
        let c = CGPoint(x: f.position.x - 10 * f.yScale, y: f.position.y + 95 * f.yScale)
        let r: CGFloat = 70 * f.yScale
        let flip: CGFloat = index % 2 == 0 ? 1 : -1
        let arc = arcNode(color: color, r: r)
        arc.position = c
        arc.zRotation = flip > 0 ? -0.5 : 0.6
        arc.yScale = flip
        arc.zPosition = 9
        fx.addChild(arc)
        let s0: CGFloat = big ? 1.35 : 1            // 最后一刀的剑光大一圈
        arc.setScale(s0)
        arc.run(.sequence([.group([.scale(to: 1.15 * s0, duration: 0.12), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        guard !char.isEmpty else { return }
        let size = 46 * f.yScale + 6
        let label = glyphNode(char, size: size)
        label.position = CGPoint(x: c.x + flip * 6, y: c.y + 6)
        label.zPosition = 13
        fx.addChild(label)
        label.setScale(big ? 2.1 : 1.6)
        label.run(.sequence([.scale(to: big ? 1.3 : 1, duration: 0.07), .wait(forDuration: 0.18),
                             .group([.moveBy(x: 0, y: 20, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
    }

    func playerStrike(delay: Double, damage: Int, heavy: Bool, flaw: Bool, finisher: Bool, combo: Int) {
        run(.wait(forDuration: max(0, delay - 0.08))) { [weak self] in
            guard let self else { return }
            self.player?.attack(distance: heavy ? 70 : 52, heavy: heavy, reduced: self.reducedMotion)
        }
        run(.wait(forDuration: delay)) { [weak self] in
            guard let self else { return }
            self.foe?.hurt(reduced: self.reducedMotion)
            self.burst(damage: damage, big: heavy || flaw || finisher || combo >= 8, gold: combo >= 8, red: combo >= 15)
            if self.heat >= 2 { self.inkSplash() }
            if heavy || finisher { self.shake(amount: finisher ? 10 : 5) }
        }
    }

    func playerHurt() {
        foe?.attack(distance: 52, heavy: false, reduced: reducedMotion)
        run(.wait(forDuration: 0.07)) { [weak self] in
            guard let self else { return }
            self.player?.hurt(reduced: self.reducedMotion)
            self.shake(amount: 6)
        }
    }

    func parry() {
        player?.attack(distance: 30, heavy: false, reduced: reducedMotion)
        spark(at: CGPoint(x: size.width * 0.5, y: ground + (size.height - ground) * 0.55), color: .white)
        foe?.stunned(true)
    }

    func block() {
        spark(at: CGPoint(x: size.width * 0.45, y: ground + (size.height - ground) * 0.55), color: Palette.uiGold)
    }

    func stunEnded() { foe?.stunned(false) }

    func mistake() { shake(amount: 4) }

    func foeDown() { foe?.knockDown(reduced: reducedMotion) }
    func playerDown() { player?.knockDown(reduced: reducedMotion) }

    // MARK: - 群战（试玩）

    /// 群战里场上的敌人和它们头上的蓄力条（按引擎里的 id）。
    private var group: [Int: FigureNode] = [:]
    private var groupBars: [Int: (bg: SKSpriteNode, fill: SKSpriteNode, hp: SKSpriteNode)] = [:]
    /// 单挑时的人物大小；群战里主角和敌人都按它乘 groupBody。
    private var groupBaseScale: CGFloat = 1
    private static let groupBody: CGFloat = 0.7
    /// 群战里主角相对镖师的大小：和头目差不多，比喽啰、镖师都高一点，始终是场上最显眼的。
    private static let heroInGroup: CGFloat = 1.1
    private var groupSlots: [Int: Int] = [:]
    private var groupTiers: [Int: Int] = [:]
    private(set) var groupMode = false
    /// 单挑的对手：群战时 foe 会指向正被打的那个，这里留着原来的，群战结束换回来。
    private var soloFoe: FigureNode?

    /// 三个站位（占战斗区宽度的比例），0 离主角最近；人比单挑时小一圈。
    private static let groupX: [CGFloat] = [0.58, 0.74, 0.89]
    /// 前后错开：中间那个站得靠后一点（高一点、压在后面），三个人不挤成一排。
    private static let groupLift: [CGFloat] = [-12, 16, 2]     // 都在地面那条深色带里，不会像悬在空中
    private static let groupZ: [CGFloat] = [3, 1, 2]
    /// 敌人大小差距不大，三等主要靠衣服颜色分（灰、红、黑）。
    private func groupScale(_ tier: Int) -> CGFloat { groupBaseScale * Self.groupBody * [0.92, 1.0, 1.08][min(2, tier)] }
    private static let tierRobe: [UIColor] = [UIColor(hex: 0x8A8F9E), Palette.uiRed, UIColor(hex: 0x2B2B2B)]

    /// 开一场群战：单挑的对手先藏起来。
    func groupBegin() {
        groupEnd()
        groupMode = true
        soloFoe = foe
        foe?.isHidden = true
        layoutFigures()
    }

    func groupEnd() {
        for n in group.values { n.removeFromParent() }
        for b in groupBars.values { b.bg.removeFromParent() }
        group = [:]; groupBars = [:]; groupSlots = [:]; groupTiers = [:]
        groupMode = false
        if let s = soloFoe { foe = s }
        soloFoe = nil
        foe?.isHidden = false
        layoutFigures()
    }

    /// 一个敌人上场：从右边走到自己的站位，头上一条小蓄力条。
    func groupAdd(id: Int, tier: Int, slot: Int, walkIn: Bool) {
        let f = FigureNode(FigureArt.guardsman(robe: Self.tierRobe[min(2, tier)]))
        let sc = groupScale(tier)
        f.yScale = sc
        f.xScale = -sc
        let x = size.width * Self.groupX[min(2, slot)]
        f.position = CGPoint(x: walkIn ? size.width + 60 : x, y: feet + Self.groupLift[min(2, slot)])
        f.zPosition = Self.groupZ[min(2, slot)]  // 靠前的压在靠后的前面
        world.addChild(f)
        f.idle(reduced: reducedMotion)
        if walkIn { f.run(.moveTo(x: x, duration: reducedMotion ? 0 : 0.35)) }
        group[id] = f
        groupSlots[id] = slot
        groupTiers[id] = tier
        // 头上一块小牌子：上面金色的是蓄力，下面一条红线是血
        let bg = SKSpriteNode(color: .white, size: CGSize(width: 52, height: 13))
        bg.zPosition = 30
        let edge = SKShapeNode(rectOf: CGSize(width: 52, height: 13))
        edge.strokeColor = Palette.uiInk
        edge.lineWidth = 2
        edge.fillColor = .clear
        bg.addChild(edge)
        let fill = SKSpriteNode(color: Palette.uiGold, size: CGSize(width: 48, height: 5))
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.position = CGPoint(x: -24, y: 2)
        fill.xScale = 0.001
        bg.addChild(fill)
        let hp = SKSpriteNode(color: Palette.uiRed, size: CGSize(width: 48, height: 3))
        hp.anchorPoint = CGPoint(x: 0, y: 0.5)
        hp.position = CGPoint(x: -24, y: -3.5)
        bg.addChild(hp)
        fx.addChild(bg)
        groupBars[id] = (bg, fill, hp)
    }

    /// 每帧：小牌子跟着人走；蓄力按进度填满（快满了变红），红线按剩下的血缩短。
    func groupPressure(_ progress: [Int: Double], hp: [Int: Double]) {
        for (id, b) in groupBars {
            guard let f = group[id] else { continue }
            b.bg.position = CGPoint(x: f.position.x - 6 * f.yScale, y: f.position.y + 182 * f.yScale)
            let k = progress[id] ?? 0
            b.fill.xScale = max(0.001, k)
            b.fill.color = k > 0.75 ? Palette.uiRed : Palette.uiGold
            b.hp.xScale = max(0.001, hp[id] ?? 1)
        }
    }

    /// 出刀前：主角冲向谁（剑光、击飞都对着它）。
    func groupFocus(_ id: Int) { if let f = group[id] { foe = f } }

    /// 必杀打全场：除了正对着的那个，其余的也挨一下。
    func groupHurtAll() { for n in group.values where n !== foe { n.hurt(reduced: reducedMotion) } }

    func groupAttack(_ id: Int) {
        group[id]?.attack(distance: 40, heavy: groupTiers[id] == 2, reduced: reducedMotion)
        run(.wait(forDuration: 0.07)) { [weak self] in
            guard let self else { return }
            self.player?.hurt(reduced: self.reducedMotion)
            self.shake(amount: 5)
        }
    }

    /// 被打倒：倒下、淡出、拿掉。
    func groupDown(_ id: Int) {
        guard let f = group[id] else { return }
        f.knockDown(reduced: reducedMotion)
        groupBars[id]?.bg.removeFromParent()
        group[id] = nil; groupBars[id] = nil; groupSlots[id] = nil; groupTiers[id] = nil
        f.run(.sequence([.wait(forDuration: 0.7), .fadeOut(withDuration: 0.25), .removeFromParent()]))
        if foe === f { foe = group.values.first }
    }

    func reset() {
        fx.removeAllChildren()
        heat = 0
        applyHeat(animated: false)
        player?.idle(reduced: reducedMotion)
        foe?.idle(reduced: reducedMotion)
        foe?.stunned(false)
    }

    private func burst(damage: Int, big: Bool, gold: Bool, red: Bool) {
        guard let f = foe else { return }
        let node = SKShapeNode(path: SVGPath.parse(FigureArt.burst))
        node.fillColor = red ? Palette.uiRed : Palette.uiGold
        node.strokeColor = Palette.uiInk
        node.lineWidth = 3
        node.lineJoin = .round
        node.yScale = -1
        node.position = CGPoint(x: f.position.x - 20, y: f.position.y + 120 * f.yScale)
        let label = SKLabelNode(text: "-\(damage)")
        label.fontName = Fonts.displayName
        label.fontSize = 24
        label.fontColor = red ? .white : Palette.uiInk
        label.verticalAlignmentMode = .center
        label.yScale = -1
        node.addChild(label)
        fx.addChild(node)
        let s: CGFloat = big ? 1.3 : 1.0
        node.setScale(0.4)
        node.yScale = -0.4
        let pop = SKAction.group([.scaleX(to: s, y: -s, duration: 0.08)])
        let rise = SKAction.group([.moveBy(x: 0, y: 26, duration: 0.5), .fadeOut(withDuration: 0.5)])
        node.run(.sequence([pop, .wait(forDuration: 0.12), rise, .removeFromParent()]))
    }

    /// 气势二档起，打中时墨点飞溅（国潮版画的网点感）。
    private func inkSplash() {
        guard let f = foe, !reducedMotion else { return }
        let c = CGPoint(x: f.position.x - 10, y: f.position.y + 110 * f.yScale)
        for k in 0..<10 {
            let r = CGFloat.random(in: 3...8)
            let dot = SKShapeNode(circleOfRadius: r)
            dot.fillColor = k % 3 == 0 ? Palette.uiRed : Palette.uiInk
            dot.strokeColor = .clear
            dot.position = c
            fx.addChild(dot)
            let a = CGFloat.random(in: 0...(2 * .pi)), d = CGFloat.random(in: 30...80)
            dot.run(.sequence([.group([.moveBy(x: cos(a) * d, y: sin(a) * d, duration: 0.25), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
        }
    }

    private func spark(at p: CGPoint, color: UIColor) {
        for k in 0..<8 {
            let line = SKShapeNode(rectOf: CGSize(width: 18, height: 4), cornerRadius: 2)
            line.fillColor = color
            line.strokeColor = Palette.uiInk
            line.lineWidth = 1.5
            line.position = p
            line.zRotation = CGFloat(k) * .pi / 4
            fx.addChild(line)
            let d = CGVector(dx: cos(line.zRotation) * 34, dy: sin(line.zRotation) * 34)
            line.run(.sequence([.group([.move(by: d, duration: 0.22), .fadeOut(withDuration: 0.22)]), .removeFromParent()]))
        }
    }

    private func shake(amount: CGFloat) {
        guard !reducedMotion else { return }
        world.removeAction(forKey: "shake")
        let seq = SKAction.sequence([
            .moveBy(x: amount, y: 0, duration: 0.03), .moveBy(x: -2 * amount, y: 0, duration: 0.05),
            .moveBy(x: amount * 1.4, y: 0, duration: 0.04), .move(to: .zero, duration: 0.04),
        ])
        world.run(seq, withKey: "shake")
    }

    // MARK: - 命数

    /// 丢了一条命：单膝跪地、手撑地。
    func foeKneel() {
        guard let f = foe, !groupMode else { return }
        f.kneel(reduced: reducedMotion)
    }

    /// 站起来，头上冒一句话。
    func foeStandUp(line: String) {
        guard let f = foe, !groupMode else { return }
        f.standUp(reduced: reducedMotion)
        let label = SKLabelNode(text: line)
        label.fontName = Fonts.displayName
        label.fontSize = 28
        label.fontColor = .white
        let shadow = SKLabelNode(text: line)
        shadow.fontName = Fonts.displayName
        shadow.fontSize = 28
        shadow.fontColor = Palette.uiInk
        shadow.position = CGPoint(x: 2, y: -2)
        shadow.zPosition = -1
        label.addChild(shadow)
        label.position = CGPoint(x: f.position.x - 10 * f.yScale, y: f.position.y + 215 * f.yScale)
        label.zPosition = 15
        label.setScale(0.4)
        fx.addChild(label)
        label.run(.sequence([.scale(to: 1.1, duration: 0.12), .scale(to: 1, duration: 0.08), .wait(forDuration: 0.8),
                             .group([.moveBy(x: 0, y: 16, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
    }
}
