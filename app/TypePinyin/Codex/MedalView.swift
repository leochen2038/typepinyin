import LearningCore
import SwiftUI

/// 一枚勋章（docs/calendar-badges.md 3.5，正式版「勋章组件」）：每条台阶一样江湖里的东西，越往上东西越多、装饰越多。
/// 收集词卡是词卡（1→2→3→5 张）、秘籍收集是方印（银起加印钮）、秘籍等级是书（薄册→厚书→两本包金角→三本）、
/// 打几场是剑（一把剑加圆牌→双剑→双剑加盾→三剑加盾）、来了几天是日轮（→带光→日出群山）。
/// 每段多一层：银加两条飘带，金加光芒和两朵云，朱红换火焰光圈、挂流苏。
/// 画在 60 × 64 的格子里，按 size 缩放。三种状态：拿到的、下一枚（虚线加「?」）、空格（淡轮廓）。
struct MedalView: View {
    enum Kind { case card, seal, book, sword, sun }
    enum Status { case got, next, empty }

    var shape: Kind
    var state: Status = .got
    /// 0 铜、1 银、2 金、3 朱红。
    var band: Int
    /// 方印里圈、书的封面色。
    var cover: Color = Color(hex: 0x9C3B4E)
    /// 方印里圈上的字是墨色（封面浅）还是纸色。
    var coverInk = false
    /// 词卡上印的词（「白菜」）。
    var word = ""
    /// 中间写的（「1000」「葫」「8」）。
    var value = ""
    var size: CGFloat = 58
    var isNew = false

    var body: some View {
        Canvas { ctx, sz in
            ctx.scaleBy(x: sz.width / 60, y: sz.height / 64)
            draw(&ctx)
        }
        .frame(width: size, height: size * 64 / 60)
        .overlay(alignment: .topLeading) {
            if isNew && state == .got {
                let d = min(22, max(16, (size * 0.3).rounded()))
                Text("新").font(.system(size: (d * 0.55).rounded(), weight: .black)).foregroundStyle(.white)
                    .frame(width: d, height: d).background(Circle().fill(Palette.red))
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .offset(x: -(d * 0.1).rounded(), y: -(d * 0.2).rounded())
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: 颜色

    private struct Ink {
        var main, light, rib, paper, ink, steel, grip, gold, fOut, fIn, halo, mount, cloud, cover, coverLine, coverText, bind, txt: Color
    }

    private static let bands: [(Color, Color, Color)] = [
        (Color(hex: 0xC08048), Color(hex: 0xE3B98F), Color(hex: 0xC08048)),
        (Color(hex: 0xB9C0CC), Color(hex: 0xDDE1E8), Color(hex: 0x1C2A5C)),
        (Color(hex: 0xF3B52F), Color(hex: 0xFFE7A3), Color(hex: 0xE2432C)),
        (Color(hex: 0xC0392B), Color(hex: 0xF08A7A), Color(hex: 0xF3B52F)),
    ]
    /// 段的颜色（铜、银、金、朱红）。
    static func bandColor(_ b: Int) -> Color { bands[min(3, max(0, b))].0 }

    private var colors: Ink {
        let b = Self.bands[min(3, max(0, band))]
        switch state {
        case .got:
            let paper = Color(hex: 0xFBF7EE)
            let cov = shape == .seal || shape == .book ? cover : b.0
            return Ink(main: b.0, light: b.1, rib: b.2, paper: paper, ink: Palette.ink, steel: Color(hex: 0xE9EDF3), grip: Color(hex: 0x5C3B22),
                       gold: Palette.gold, fOut: Palette.red, fIn: Palette.gold, halo: Color(hex: 0xFFE7A3), mount: Palette.xp, cloud: paper,
                       cover: cov, coverLine: paper, coverText: coverInk ? Palette.ink : paper, bind: Color.black.opacity(0.22), txt: Palette.ink)
        case .empty:
            let e = Color(hex: 0xE6DFCC), ep = Color(hex: 0xF4EFE3), el = Color(hex: 0xCBC3AE)
            return Ink(main: e, light: e, rib: e, paper: ep, ink: el, steel: ep, grip: e, gold: e, fOut: e, fIn: ep, halo: ep, mount: e, cloud: ep,
                       cover: e, coverLine: el, coverText: .clear, bind: .clear, txt: .clear)
        case .next:
            let w = Color(hex: 0xFBF7EE), k = Palette.slate
            return Ink(main: w, light: w, rib: w, paper: w, ink: k, steel: w, grip: w, gold: w, fOut: w, fIn: w, halo: w, mount: w, cloud: w,
                       cover: w, coverLine: k, coverText: Palette.ink, bind: .clear, txt: Palette.ink)
        }
    }

    // MARK: 画

    private var tier: Int { min(3, max(0, band)) + 1 }
    private var got: Bool { state == .got }
    private var mark: String { state == .next ? "?" : "" }
    private var dash: [CGFloat] { state == .next ? [2.4, 1.6] : [] }

    /// 字数多时缩小（两个字以内、三个字、四个字以上）。
    private func vs(_ s: String, _ a: CGFloat, _ b: CGFloat, _ c: CGFloat) -> CGFloat { s.count <= 2 ? a : s.count == 3 ? b : c }

    private func shapeFill(_ ctx: inout GraphicsContext, _ p: Path, _ fill: Color, _ line: CGFloat, ink: Color? = nil, dashed: Bool = true) {
        ctx.fill(p, with: .color(fill))
        ctx.stroke(p, with: .color(ink ?? colors.ink),
                   style: StrokeStyle(lineWidth: line, lineCap: .butt, lineJoin: .round, dash: dashed ? dash : []))
    }

    private func text(_ ctx: inout GraphicsContext, _ s: String, x: CGFloat, baseline y: CGFloat, size: CGFloat, display: Bool, color: Color) {
        guard !s.isEmpty else { return }
        let t = Text(s).font(display ? Fonts.display(size) : .system(size: size, weight: .black)).foregroundStyle(color)
        ctx.draw(t, at: CGPoint(x: x, y: y - size * 0.36), anchor: .center)
    }

    private func rotated(_ ctx: GraphicsContext, _ deg: Double, _ cx: CGFloat, _ cy: CGFloat) -> GraphicsContext {
        var c = ctx
        c.translateBy(x: cx, y: cy)
        c.rotate(by: .degrees(deg))
        c.translateBy(x: -cx, y: -cy)
        return c
    }

    private func draw(_ ctx: inout GraphicsContext) {
        let c = colors
        if tier == 4 {                                                      // 朱红：火焰光圈
            shapeFill(&ctx, Self.poly(Self.flameOut), c.fOut, 1.2)
            shapeFill(&ctx, Self.poly(Self.flameIn), c.fIn, 1)
        }
        if tier == 3 && shape != .sun { shapeFill(&ctx, Self.poly(Self.rays), c.halo, 1.1) }   // 金：光芒
        if shape == .sun && tier == 4 { shapeFill(&ctx, Self.poly("3,48 15,33 22,40 30,29 38,40 45,33 57,48"), c.mount, 1.2) }
        if tier >= 2 {                                                      // 银起：两条飘带
            shapeFill(&ctx, Self.poly("21,36 28,40 23,59 19.5,55 15,58"), c.rib, 1.3)
            shapeFill(&ctx, Self.poly("39,36 32,40 37,59 40.5,55 45,58"), c.rib, 1.3)
        }
        switch shape {
        case .card: drawCards(&ctx, c)
        case .seal: drawSeal(&ctx, c)
        case .book: drawBooks(&ctx, c)
        case .sword: drawSwords(&ctx, c)
        case .sun: drawSun(&ctx, c)
        }
        if tier >= 3 {                                                      // 金起：左右两朵云
            let cloud = Self.cloud
            shapeFill(&ctx, cloud, c.cloud, 1.2)
            shapeFill(&ctx, cloud.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 60, ty: 0)), c.cloud, 1.2)
        }
        if tier == 4 {                                                      // 朱红：流苏
            var line = Path(); line.move(to: CGPoint(x: 30, y: 44)); line.addLine(to: CGPoint(x: 30, y: 53))
            ctx.stroke(line, with: .color(c.ink), lineWidth: 1.6)
            shapeFill(&ctx, Path(ellipseIn: CGRect(x: 27.6, y: 51.6, width: 4.8, height: 4.8)), c.gold, 1)
            shapeFill(&ctx, Self.poly("27,56 33,56 35,64 25,64"), c.fOut, 1)
            var l2 = Path()
            l2.move(to: CGPoint(x: 28.6, y: 57.6)); l2.addLine(to: CGPoint(x: 28, y: 63))
            l2.move(to: CGPoint(x: 31.4, y: 57.6)); l2.addLine(to: CGPoint(x: 32, y: 63))
            ctx.stroke(l2, with: .color(c.ink), lineWidth: 0.7)
        }
    }

    private func drawCards(_ ctx: inout GraphicsContext, _ c: Ink) {
        let back = Path(roundedRect: CGRect(x: 20, y: 11, width: 20, height: 29), cornerRadius: 2)
        var backs: [Double] = []
        if tier == 4 { backs += [-36, 36] }
        if tier >= 3 { backs.append(-18) }
        if tier >= 2 { backs.append(18) }
        for deg in backs {
            var r = rotated(ctx, deg, 30, 44)
            shapeFill(&r, back, c.light, 1.5)
        }
        var f = rotated(ctx, tier == 1 ? -4 : 0, 30, 26)
        shapeFill(&f, back, c.main, 1.8)
        shapeFill(&f, Path(roundedRect: CGRect(x: 23, y: 14, width: 14, height: 23), cornerRadius: 1), c.paper, 1)
        text(&f, got ? word : "", x: 30, baseline: 23.5, size: vs(word, 6.2, 4.8, 3.9), display: false, color: c.txt)
        let v = got ? value : mark
        text(&f, v, x: 30, baseline: 33.6, size: got ? vs(value, 8.5, 7.4, 6.2) : 9, display: true, color: c.txt)
    }

    private func drawSeal(_ ctx: inout GraphicsContext, _ c: Ink) {
        var s = rotated(ctx, -3, 30, 27)
        if tier >= 2 {                                                      // 印钮
            shapeFill(&s, Path(CGRect(x: 26.5, y: 11, width: 7, height: 4)), c.main, 1.2)
            shapeFill(&s, Path(roundedRect: CGRect(x: 23.5, y: 5, width: 13, height: 7.5), cornerRadius: 3.5), c.main, 1.6)
        }
        shapeFill(&s, Path(CGRect(x: 17, y: 14, width: 26, height: 26)), c.main, 1.8)
        shapeFill(&s, Path(CGRect(x: 20.5, y: 17.5, width: 19, height: 19)), c.cover, 1.2, ink: c.coverLine)
        text(&s, got ? value : mark, x: 30, baseline: 31.6, size: 13, display: false, color: c.coverText)
    }

    private func drawBooks(_ ctx: inout GraphicsContext, _ c: Ink) {
        let book = Path(CGRect(x: 19, y: 12, width: 22, height: 30))
        if tier == 4 { var r = rotated(ctx, 14, 30, 44); shapeFill(&r, book, c.light, 1.5) }
        if tier >= 3 { var r = rotated(ctx, -12, 30, 44); shapeFill(&r, book, c.light, 1.5) }
        if tier >= 2 { shapeFill(&ctx, Path(CGRect(x: 40, y: 14, width: 3.6, height: 26)), c.paper, 1) }   // 书页
        shapeFill(&ctx, book, c.cover, 1.8)
        ctx.fill(Path(CGRect(x: 20, y: 13, width: 4, height: 28)), with: .color(c.bind))
        shapeFill(&ctx, Path(CGRect(x: 27, y: 18, width: 11, height: 13)), c.paper, 1)
        text(&ctx, got ? value : mark, x: 32.5, baseline: 27.6, size: got ? vs(value, 8, 6.6, 5.6) : 8, display: true, color: c.txt)
        if tier >= 3 {                                                      // 包金角
            shapeFill(&ctx, Self.poly("41,12 41,18 35,12"), c.gold, 0.9)
            shapeFill(&ctx, Self.poly("41,42 41,36 35,42"), c.gold, 0.9)
        }
        shapeFill(&ctx, Self.poly("33,41 37,41 37,48 35,46 33,48"), c.main, 1)   // 书签
    }

    private func drawSwords(_ ctx: inout GraphicsContext, _ c: Ink) {
        func sword(_ g: inout GraphicsContext) {
            shapeFill(&g, Self.poly("28.4,10 30,4 31.6,10 31.6,35 28.4,35"), c.steel, 1.1)
            shapeFill(&g, Path(roundedRect: CGRect(x: 24.5, y: 35, width: 11, height: 2.8), cornerRadius: 1), c.main, 1)
            shapeFill(&g, Path(CGRect(x: 29, y: 37.8, width: 2, height: 6)), c.grip, 0.8, dashed: false)
            shapeFill(&g, Path(ellipseIn: CGRect(x: 28.3, y: 43.5, width: 3.4, height: 3.4)), c.main, 0.8, dashed: false)
        }
        if tier >= 2 {
            var a = rotated(ctx, -38, 30, 27); sword(&a)
            var b = rotated(ctx, 38, 30, 27); sword(&b)
        }
        if tier == 1 || tier == 4 { sword(&ctx) }
        let v = got ? value : mark
        let fs = got ? vs(value, 8, 6.6, 5.6) : 8
        if tier <= 2 {                                                      // 圆牌
            shapeFill(&ctx, Path(ellipseIn: CGRect(x: 20, y: 17, width: 20, height: 20)), c.main, 1.8)
            shapeFill(&ctx, Path(ellipseIn: CGRect(x: 22.7, y: 19.7, width: 14.6, height: 14.6)), c.paper, 1)
            text(&ctx, v, x: 30, baseline: 30.2, size: fs, display: true, color: c.txt)
        } else {                                                            // 盾牌
            shapeFill(&ctx, Self.shield(outer: true), c.main, 1.8)
            shapeFill(&ctx, Self.shield(outer: false), c.paper, 1)
            text(&ctx, v, x: 30, baseline: 31.4, size: fs, display: true, color: c.txt)
        }
    }

    private func drawSun(_ ctx: inout GraphicsContext, _ c: Ink) {
        if tier >= 2 { shapeFill(&ctx, Self.poly(Self.sunRays), c.light, 1.1) }
        shapeFill(&ctx, Path(ellipseIn: CGRect(x: 18.5, y: 15.5, width: 23, height: 23)), c.main, 1.8)
        shapeFill(&ctx, Path(ellipseIn: CGRect(x: 21.4, y: 18.4, width: 17.2, height: 17.2)), c.paper, 1)
        text(&ctx, got ? value : mark, x: 30, baseline: 30.3, size: got ? vs(value, 8.5, 7, 5.8) : 8.5, display: true, color: c.txt)
    }

    // MARK: 形状

    private static func poly(_ s: String) -> Path {
        let pts = s.split(separator: " ").compactMap { pair -> CGPoint? in
            let xy = pair.split(separator: ",").compactMap { Double($0) }
            return xy.count == 2 ? CGPoint(x: xy[0], y: xy[1]) : nil
        }
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }

    private static func shield(outer: Bool) -> Path {
        var p = Path()
        if outer {
            p.move(to: CGPoint(x: 30, y: 14)); p.addLine(to: CGPoint(x: 42, y: 18.5)); p.addLine(to: CGPoint(x: 41, y: 30))
            p.addQuadCurve(to: CGPoint(x: 30, y: 43), control: CGPoint(x: 39, y: 38.5))
            p.addQuadCurve(to: CGPoint(x: 19, y: 30), control: CGPoint(x: 21, y: 38.5))
            p.addLine(to: CGPoint(x: 18, y: 18.5))
        } else {
            p.move(to: CGPoint(x: 30, y: 17.6)); p.addLine(to: CGPoint(x: 38.6, y: 21)); p.addLine(to: CGPoint(x: 37.9, y: 29.6))
            p.addQuadCurve(to: CGPoint(x: 30, y: 39.2), control: CGPoint(x: 36.4, y: 35.8))
            p.addQuadCurve(to: CGPoint(x: 22.1, y: 29.6), control: CGPoint(x: 23.6, y: 35.8))
            p.addLine(to: CGPoint(x: 21.4, y: 21))
        }
        p.closeSubpath()
        return p
    }

    private static let cloud: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 6, y: 48))
        p.addCurve(to: CGPoint(x: 6.8, y: 44), control1: CGPoint(x: 3.5, y: 48), control2: CGPoint(x: 3.5, y: 44))
        p.addCurve(to: CGPoint(x: 13, y: 42), control1: CGPoint(x: 7, y: 41), control2: CGPoint(x: 11, y: 40))
        p.addCurve(to: CGPoint(x: 20, y: 42), control1: CGPoint(x: 14, y: 39), control2: CGPoint(x: 19, y: 39))
        p.addCurve(to: CGPoint(x: 21.5, y: 48), control1: CGPoint(x: 23, y: 42), control2: CGPoint(x: 24, y: 45.5))
        p.closeSubpath()
        return p
    }()

    private static let flameOut = "30.0,-2.0 34.9,9.6 45.0,2.0 43.4,14.6 56.0,13.0 48.4,23.1 60.0,28.0 48.4,32.9 56.0,43.0 43.4,41.4 45.0,54.0 34.9,46.4 30.0,58.0 25.1,46.4 15.0,54.0 16.6,41.4 4.0,43.0 11.6,32.9 0.0,28.0 11.6,23.1 4.0,13.0 16.6,14.6 15.0,2.0 25.1,9.6"
    private static let flameIn = "36.5,3.9 38.5,13.3 47.7,10.3 44.7,19.5 54.1,21.5 47.0,28.0 54.1,34.5 44.7,36.5 47.7,45.7 38.5,42.7 36.5,52.1 30.0,45.0 23.5,52.1 21.5,42.7 12.3,45.7 15.3,36.5 5.9,34.5 13.0,28.0 5.9,21.5 15.3,19.5 12.3,10.3 21.5,13.3 23.5,3.9 30.0,11.0"
    private static let rays = "30.0,-0.5 33.9,8.4 40.9,1.7 41.1,11.4 50.2,7.8 46.6,16.9 56.3,17.1 49.6,24.1 58.5,28.0 49.6,31.9 56.3,38.9 46.6,39.1 50.2,48.2 41.1,44.6 40.9,54.3 33.9,47.6 30.0,56.5 26.1,47.6 19.1,54.3 18.9,44.6 9.8,48.2 13.4,39.1 3.7,38.9 10.4,31.9 1.5,28.0 10.4,24.1 3.7,17.1 13.4,16.9 9.8,7.8 18.9,11.4 19.1,1.7 26.1,8.4"
    private static let sunRays = "30.0,7.5 33.5,14.0 39.8,10.1 39.5,17.5 46.9,17.2 43.0,23.5 49.5,27.0 43.0,30.5 46.9,36.8 39.5,36.5 39.8,43.9 33.5,40.0 30.0,46.5 26.5,40.0 20.3,43.9 20.5,36.5 13.1,36.8 17.0,30.5 10.5,27.0 17.0,23.5 13.1,17.2 20.5,17.5 20.2,10.1 26.5,14.0"
}
