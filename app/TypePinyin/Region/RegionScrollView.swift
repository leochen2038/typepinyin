import LearningCore
import SwiftUI

/// 一片地区的竖长卷（简化版）：山路从山脚画到掌门所在的地方，站牌立在路边，小人站在当前一站。
/// 用粗墨线、平涂撞色画；景物按地区换（葫芦集：葫芦架、大石、古树；半山镇：石阶、山门、竹林）。
struct RegionScrollView: View {
    let region: Region
    let route: Route
    /// 已经走过（打完）的站数，也就是当前这一站的下标。
    let cleared: Int
    /// 小人的位置（可以是两站之间的小数，走路时用）。
    let hero: Double
    let width: CGFloat
    /// 正式美术的场景：有就用画好的长卷图、站点沿弯路排；nil = 旧画法。
    var scene: RegionScene? = nil
    /// 小人正在走（换走路的帧）。
    var walking = false

    static let height: CGFloat = SceneRenderer.scrollHeight
    var theme: RegionTheme { RegionTheme.of(region.id) }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 第 i 站在长卷上的位置：有正式美术场景时沿弯路等距；否则从下往上、左右交错。
    static func point(_ i: Double, count: Int, width: CGFloat, scene: RegionScene?) -> CGPoint {
        if let scene { return SceneRenderer.station(i, count: count, scene: scene, width: width) }
        return point(i, count: count, width: width)
    }

    static func point(_ i: Double, count: Int, width: CGFloat) -> CGPoint {
        if i < 0 {                                                 // 从山脚走到第一站
            let a = CGPoint(x: width * 0.5, y: SceneRenderer.startY), b = point(0, count: count, width: width)
            let f = CGFloat(1 + max(i, -1))
            return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
        }
        let n = Double(max(1, count - 1))
        let k = min(max(i, 0), n)
        let y = SceneRenderer.firstStationY - (SceneRenderer.firstStationY - 230) * CGFloat(k / n)   // 第一站下面留一段山脚的路
        let lo = Int(k.rounded(.down)), hi = min(Int(k.rounded(.up)), count - 1)
        func x(_ j: Int) -> CGFloat { j == count - 1 ? 0.5 : (j % 2 == 0 ? 0.3 : 0.7) }
        let f = CGFloat(k - Double(lo))
        return CGPoint(x: width * (x(lo) * (1 - f) + x(hi) * f), y: y)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let scene {
                Image(uiImage: SceneRenderer.scroll(regionId: region.id, scene: scene, theme: theme, width: width))
                    .frame(width: width, height: Self.height)
                if let mist = SceneRenderer.mist(regionId: region.id, scene: scene, width: width) {
                    MistLayer(image: mist, drift: !reduceMotion)
                        .frame(width: width, height: Self.height)
                }
            } else {
                Canvas { ctx, size in draw(ctx, size: size) }
                    .frame(width: width, height: Self.height)
            }
            ForEach(Array(route.stations.enumerated()), id: \.offset) { i, st in
                sign(i, st)
                    .position(signPoint(i))
            }
            HeroMarker(walking: walking)
                .modifier(OnRoad(t: hero, at: { Self.point($0, count: route.stations.count, width: width, scene: scene) }))
        }
        .frame(width: width, height: Self.height)
    }

    func signPoint(_ i: Int) -> CGPoint {
        let p = Self.point(Double(i), count: route.stations.count, width: width, scene: scene)
        let side: CGFloat = scene != nil || i == route.stations.count - 1 ? 0 : (i % 2 == 0 ? -58 : 58)   // 新画法站牌就在路上
        return CGPoint(x: p.x + side, y: p.y - (scene == nil && i == route.stations.count - 1 ? 70 : 8))   // 新画法掌门的标记也在路上
    }

    // MARK: 站牌

    @ViewBuilder func sign(_ i: Int, _ st: Station) -> some View {
        let done = i < cleared
        switch st.kind {
        case .boss where scene != nil:                             // 掌门：和别的站一样是圆的，黑底金字，一眼分得开
            badge("掌", fill: Palette.ink, text: Palette.gold)
        case .boss:
            VStack(spacing: 3) {
                Text("掌").font(Fonts.display(20)).foregroundStyle(Palette.gold)
                    .frame(width: 36, height: 36).background(Palette.ink)
                    .overlay(Rectangle().stroke(Palette.gold, lineWidth: 2))
                Text(st.foe?.name ?? "").font(Fonts.hanzi(14)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 5).background(Color.white.opacity(0.85))
            }
        case .encounter where done || i == cleared:
            badge("遇", fill: Palette.gold, text: Palette.ink)
        default:
            if done {
                badge("胜", fill: Palette.red, text: .white)
            } else {
                Circle().fill(Color.white).overlay(Circle().stroke(Palette.ink, lineWidth: 3)).frame(width: 18, height: 18)
            }
        }
    }

    func badge(_ t: String, fill: Color, text: Color) -> some View {
        Text(t).font(Fonts.display(17)).foregroundStyle(text)
            .frame(width: 30, height: 30).background(Circle().fill(fill))
            .overlay(Circle().stroke(Palette.ink, lineWidth: 2.5))
    }

    // MARK: 画卷

    func draw(_ ctx: GraphicsContext, size: CGSize) {
        let t = theme
        let w = size.width, h = size.height
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(t.color(t.sky)))
        var rng = SplitMix64(seed: UInt64(region.id.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) & 0xFFFFFF }))
        // 远山：一层层往上叠
        for band in 0..<Int(h / 300) {
            let base = h - CGFloat(band) * 300 - 120
            var p = Path()
            p.move(to: CGPoint(x: 0, y: base + 200))
            var x: CGFloat = 0
            while x <= w + 30 {
                let peak = base - CGFloat(rng.next() % 90) - 30
                p.addLine(to: CGPoint(x: x + 30, y: peak))
                x += 70
            }
            p.addLine(to: CGPoint(x: w, y: base + 200))
            p.closeSubpath()
            ctx.fill(p, with: .color(t.color(band % 2 == 0 ? t.farHill : t.nearHill).opacity(0.55)))
            ctx.stroke(p, with: .color(Palette.ink.opacity(0.35)), lineWidth: 1.5)
        }
        // 山路：穿过每一站
        let n = route.stations.count
        var road = Path()
        road.move(to: CGPoint(x: w * 0.5, y: h))
        for i in 0..<n {
            let a = Self.point(Double(i), count: n, width: w)
            road.addLine(to: a)
        }
        ctx.stroke(road, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 34, lineCap: .round, lineJoin: .round))
        ctx.stroke(road, with: .color(t.color(t.road)), style: StrokeStyle(lineWidth: 28, lineCap: .round, lineJoin: .round))
        if region.id == "banshanzhen" {          // 石阶
            ctx.stroke(road, with: .color(Palette.ink.opacity(0.4)), style: StrokeStyle(lineWidth: 24, dash: [2, 12]))
        }
        // 景物
        for k in 0..<Int((h - 120) / 95) {
            let y = h - 120 - CGFloat(k) * 95
            let left = k % 2 == 0
            let x = left ? CGFloat(rng.next() % 50) + 20 : w - CGFloat(rng.next() % 50) - 30
            switch region.id {
            case "banshanzhen": k % 3 == 0 ? teaBush(ctx, CGPoint(x: x, y: y), t) : stoneLantern(ctx, CGPoint(x: x, y: y), t)
            default: k % 3 == 1 ? stone(ctx, CGPoint(x: x, y: y)) : tree(ctx, CGPoint(x: x, y: y), t)
            }
        }
        if region.id == "huluji" {
            teaStall(ctx, CGPoint(x: w * 0.82, y: h - 260), t)
            for k in 0..<5 { gourdTrellis(ctx, CGPoint(x: k % 2 == 0 ? w * 0.14 : w * 0.86, y: h - 420 - CGFloat(k) * 210)) }
        }
        if region.id == "banshanzhen" { gate(ctx, Self.point(Double(n - 1), count: n, width: w).applying(.init(translationX: 0, y: 60)), t) }
    }

    func tree(_ ctx: GraphicsContext, _ p: CGPoint, _ t: RegionTheme) {
        let trunk = Path(CGRect(x: p.x - 4, y: p.y - 30, width: 8, height: 30))
        ctx.fill(trunk, with: .color(Color(hex: 0x6B4A2E)))
        ctx.stroke(trunk, with: .color(Palette.ink), lineWidth: 2)
        let crown = Path(ellipseIn: CGRect(x: p.x - 24, y: p.y - 66, width: 48, height: 42))
        ctx.fill(crown, with: .color(t.color(t.nearHill)))
        ctx.stroke(crown, with: .color(Palette.ink), lineWidth: 2.5)
    }

    func stone(_ ctx: GraphicsContext, _ p: CGPoint) {
        var s = Path()
        s.move(to: CGPoint(x: p.x - 22, y: p.y))
        s.addLine(to: CGPoint(x: p.x - 14, y: p.y - 22))
        s.addLine(to: CGPoint(x: p.x + 8, y: p.y - 28))
        s.addLine(to: CGPoint(x: p.x + 22, y: p.y))
        s.closeSubpath()
        ctx.fill(s, with: .color(Color(hex: 0xA8A49A)))
        ctx.stroke(s, with: .color(Palette.ink), lineWidth: 2.5)
    }

    func teaBush(_ ctx: GraphicsContext, _ p: CGPoint, _ t: RegionTheme) {
        for d in [-14, 0, 14] as [CGFloat] {
            let b = Path(ellipseIn: CGRect(x: p.x + d - 12, y: p.y - 18, width: 24, height: 18))
            ctx.fill(b, with: .color(t.color(t.accent)))
            ctx.stroke(b, with: .color(Palette.ink), lineWidth: 2)
        }
    }

    func stoneLantern(_ ctx: GraphicsContext, _ p: CGPoint, _ t: RegionTheme) {
        let body = Path(CGRect(x: p.x - 6, y: p.y - 26, width: 12, height: 26))
        ctx.fill(body, with: .color(Color(hex: 0xB9B3A6)))
        ctx.stroke(body, with: .color(Palette.ink), lineWidth: 2)
        var roof = Path()
        roof.move(to: CGPoint(x: p.x - 13, y: p.y - 26))
        roof.addLine(to: CGPoint(x: p.x, y: p.y - 38))
        roof.addLine(to: CGPoint(x: p.x + 13, y: p.y - 26))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(Palette.ink))
    }

    func teaStall(_ ctx: GraphicsContext, _ p: CGPoint, _ t: RegionTheme) {
        let hut = Path(CGRect(x: p.x - 26, y: p.y - 34, width: 52, height: 34))
        ctx.fill(hut, with: .color(Color(hex: 0xD9B57A)))
        ctx.stroke(hut, with: .color(Palette.ink), lineWidth: 2.5)
        var roof = Path()
        roof.move(to: CGPoint(x: p.x - 36, y: p.y - 34))
        roof.addLine(to: CGPoint(x: p.x, y: p.y - 56))
        roof.addLine(to: CGPoint(x: p.x + 36, y: p.y - 34))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(t.color(t.accent)))
        ctx.stroke(roof, with: .color(Palette.ink), lineWidth: 2.5)
        let flag = Path(CGRect(x: p.x + 30, y: p.y - 70, width: 14, height: 22))
        ctx.fill(flag, with: .color(.white))
        ctx.stroke(flag, with: .color(Palette.ink), lineWidth: 2)
    }

    /// 葫芦架：两根竹竿一根横梁，下面挂几个葫芦。
    func gourdTrellis(_ ctx: GraphicsContext, _ p: CGPoint) {
        for d in [-26, 26] as [CGFloat] {
            var pole = Path(); pole.move(to: CGPoint(x: p.x + d, y: p.y)); pole.addLine(to: CGPoint(x: p.x + d, y: p.y - 56))
            ctx.stroke(pole, with: .color(Palette.ink), lineWidth: 3)
        }
        var beam = Path(); beam.move(to: CGPoint(x: p.x - 34, y: p.y - 56)); beam.addLine(to: CGPoint(x: p.x + 34, y: p.y - 56))
        ctx.stroke(beam, with: .color(Palette.ink), lineWidth: 4)
        for d in [-14, 2, 16] as [CGFloat] {
            let top = Path(ellipseIn: CGRect(x: p.x + d - 4, y: p.y - 50, width: 8, height: 8))
            let bottom = Path(ellipseIn: CGRect(x: p.x + d - 7, y: p.y - 44, width: 14, height: 14))
            for g in [bottom, top] {
                ctx.fill(g, with: .color(Color(hex: 0xE3B04B)))
                ctx.stroke(g, with: .color(Palette.ink), lineWidth: 1.5)
            }
        }
    }

    func gate(_ ctx: GraphicsContext, _ p: CGPoint, _ t: RegionTheme) {
        for d in [-40, 40] as [CGFloat] {
            let pillar = Path(CGRect(x: p.x + d - 5, y: p.y - 70, width: 10, height: 70))
            ctx.fill(pillar, with: .color(Palette.red))
            ctx.stroke(pillar, with: .color(Palette.ink), lineWidth: 2)
        }
        let beam = Path(CGRect(x: p.x - 56, y: p.y - 84, width: 112, height: 14))
        ctx.fill(beam, with: .color(Palette.ink))
    }
}

/// 长卷上的雾和阳光：比长卷左右各宽 mistPad 的一张透明图，用 Core Animation 左右慢慢飘
/// （16 秒一趟、来回，动画在渲染进程里跑，不占主线程）；减弱动态效果时不动。
struct MistLayer: UIViewRepresentable {
    let image: UIImage
    let drift: Bool

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        host.isUserInteractionEnabled = false
        let iv = UIImageView(image: image)
        iv.frame = CGRect(x: -SceneRenderer.mistPad, y: 0, width: image.size.width, height: image.size.height)
        host.addSubview(iv)
        if drift {
            let a = CABasicAnimation(keyPath: "transform.translation.x")
            a.fromValue = -10
            a.toValue = 10
            a.duration = 16
            a.autoreverses = true
            a.repeatCount = .infinity
            a.isRemovedOnCompletion = false                                 // 切到后台再回来还接着飘
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            iv.layer.add(a, forKey: "drift")
        }
        return host
    }

    func updateUIView(_ host: UIView, context: Context) {
        (host.subviews.first as? UIImageView)?.image = image
    }
}

/// 小人沿路走：动画按「第几站」插值，每一帧重新算路上的位置，所以沿弯路走而不是走直线。
struct OnRoad: ViewModifier, @preconcurrency Animatable {
    var t: Double
    let at: (Double) -> CGPoint
    var animatableData: Double {
        get { t }
        set { t = newValue }
    }

    func body(content: Content) -> some View {
        let p = at(t)
        let ahead = at(t + 0.02)                                  // 往左走就朝左
        content
            .scaleEffect(x: ahead.x < p.x - 0.05 ? -1 : 1, y: 1)
            .position(p.applying(.init(translationX: 0, y: -26)))
    }
}

/// 长卷上的小人：主角赶路的样子（剑背在身后）；比武里才是战斗姿势。
struct HeroMarker: View {
    var walking = false
    static let height: CGFloat = 60                    // 定稿的比例瘦长，比原来的 52 高一点才看得清

    var body: some View {
        Group {
            if walking {
                TimelineView(.animation) { tl in
                    WalkingHero(t: tl.date.timeIntervalSinceReferenceDate)
                }
            } else {
                WalkingHero(t: 0)                                  // 站着：摆角为 0，和走路时同一套画法，切换时不跳
            }
        }
        .accessibilityHidden(true)
    }
}

// Motion Prompt #029 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#029
/// 走路的主角：照跟拍（#029）里走路的人，腿和手按正弦前后摆、手和腿反着摆，每迈一步身子往上一点（脚着地时最低）。
/// 原版摆幅 0.42 弧度、sin(t×7)；试玩觉得步子太大，改成小步：摆幅 0.22、sin(t×11)（走得快，腿也倒得快）。部件绕各自的关节转，画法和站着时一样。
struct WalkingHero: View {
    let t: Double
    @MainActor static let figure = FigureArt.catalog("herotravel")
    @MainActor static let box: CGRect = {
        var b = CGRect.null
        for p in figure.layers { b = b.union(p.bounds) }
        return b.insetBy(dx: -8, dy: -4)                        // 腿摆开、身子上下时留点边
    }()

    var body: some View {
        let f = Self.figure, box = Self.box
        let k = HeroMarker.height / box.height
        let swing = sin(t * 11) * 0.22
        let bob = -abs(sin(t * 11)) * 1.4                           // 两腿分开时身子最高
        Canvas { ctx, _ in
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -box.minX, y: -box.minY)
            func draw(_ part: FigureArt.Part, angle: Double, lift: CGFloat) {
                var c = ctx
                c.translateBy(x: part.pivot.x, y: part.pivot.y + lift)
                c.rotate(by: .radians(angle))
                c.translateBy(x: -part.pivot.x, y: -part.pivot.y)
                if let a = part.asset { c.draw(Image(a), in: part.box) }
                for s in part.shapes {
                    let path = Path(s.path)
                    if let fill = s.fill { c.fill(path, with: .color(Color(uiColor: fill))) }
                    if let st = s.stroke, s.width > 0 {
                        c.stroke(path, with: .color(Color(uiColor: st)), style: StrokeStyle(lineWidth: s.width, lineCap: s.cap, lineJoin: .round))
                    }
                }
            }
            if let back = f.back { draw(back, angle: 0, lift: bob) }
            draw(f.backArm, angle: swing * 0.6, lift: bob)
            draw(f.backLeg, angle: swing, lift: bob)
            draw(f.frontLeg, angle: -swing, lift: bob)
            draw(f.body, angle: 0, lift: bob)
            draw(f.frontArm, angle: -swing * 0.6, lift: bob)
        }
        .frame(width: box.width * k, height: HeroMarker.height)
    }
}

/// 长卷景物的随机数（固定种子，每次画得一样）。
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
