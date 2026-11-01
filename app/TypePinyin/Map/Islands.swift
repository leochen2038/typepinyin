import LearningCore
import ProgressStore
import SwiftUI
import UIKit

/// 一座浮岛：顶上一片地，下面倒挂一块分层的石头，脚下两缕云；左上一枚圆章，右上漂「N 张」；岛下地名。
/// 有美术图（素材里的 island-<地区 id>）就用图，没有先用形状画（颜色按地区）。
struct IslandView: View {
    let region: Region
    let phase: RegionPhase
    let obtained: Bool
    let recent: Bool
    let count: Int
    var start = false
    var picked = false
    var bobDelay = 0.0
    var reduceMotion = false
    @State private var bob = false

    /// 岛顶的颜色（没有美术图时用）。
    static let top: [String: Color] = [
        "huluji": Color(hex: 0xB2CF84), "baimeitai": Color(hex: 0xCFDCB0), "yueyawan": Color(hex: 0xB8D0A6),
        "chaotoudao": Color(hex: 0xE6D6A4), "banshanzhen": Color(hex: 0x9CC77E), "chuiliucun": Color(hex: 0xBDDC93),
        "changfengcheng": Color(hex: 0xC4C9A2), "xiaoqiaoxiang": Color(hex: 0xBCD9A3), "lvquanju": Color(hex: 0xA6D3A0),
        "huanghuaguan": Color(hex: 0xD3D08F),
    ]

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { g in
                let s = min(g.size.width / 120, g.size.height / 104, 0.92)   // 岛宽最多约 110 点，岛和岛之间留出空
                let w = 120 * s, h = 104 * s
                ZStack(alignment: .topLeading) {
                    if recent {
                        Ellipse().fill(RadialGradient(colors: [Color(hex: 0xFFFBE9).opacity(0.95), Color(hex: 0xFFF6D8).opacity(0)],
                                                      center: .center, startRadius: 0, endRadius: 70 * s))
                            .frame(width: 140 * s, height: 92 * s).offset(x: -10 * s, y: 0)
                    }
                    art(s)
                        .frame(width: w, height: h)
                    badge.scaleEffect(s).frame(width: 36, height: 36).position(x: 26 * s, y: 18 * s)
                    if phase != .untouched && count > 0 {
                        chip.fixedSize().position(x: 26 * s + 50, y: 12 * s)   // 圆章右上方、高一点、隔开一点
                    }
                }
                .frame(width: w, height: h)
                .scaleEffect(picked ? 1.06 : 1)
                .offset(y: bob ? -4 : 0)
                .frame(width: g.size.width, height: g.size.height, alignment: .bottom)   // 岛贴着下面的地名
            }
            Text(region.name).font(Fonts.display(18)).foregroundStyle(Palette.ink).lineLimit(1)
            if start { Text("起点").font(.system(size: 11, weight: .black)).foregroundStyle(Palette.red) }
        }
        .animation(.easeOut(duration: 0.2), value: picked)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true).delay(bobDelay.truncatingRemainder(dividingBy: 3))) { bob = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(region.name)，\(["未挑战", "挑战中", "已挑战"][phase == .untouched ? 0 : phase == .inProgress ? 1 : 2])\(phase != .untouched && count > 0 ? "，已集 \(count) 张词卡" : "")")
        .accessibilityAddTraits(.isButton)
    }

    /// 岛身：有图用图，没图画形状。
    @ViewBuilder func art(_ s: CGFloat) -> some View {
        if let img = UIImage(named: "island-\(region.id)") {
            Image(uiImage: img).resizable().scaledToFit().padding(.top, 14 * s)
        } else {
            ZStack {
                IslandRock().fill(Color(hex: 0xB49A7A))
                IslandRock().stroke(Palette.ink, style: StrokeStyle(lineWidth: 2.4 * s, lineJoin: .round))
                IslandStrata().stroke(Palette.ink.opacity(0.35), lineWidth: 1.2 * s)
                Canvas { ctx, _ in                                   // 石头上垂下的两根藤
                    ctx.stroke(Path(SVGPath.parse("M30 75 Q28 82 31 88 M88 78 Q90 84 87 90")).applying(CGAffineTransform(scaleX: s, y: s)),
                               with: .color(Color(hex: 0x5E8A3A)), style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round))
                }
                IslandTop().fill(Self.top[region.id] ?? Color(hex: 0xB2CF84))
                IslandTop().stroke(Palette.ink, lineWidth: 2.4 * s)
                Canvas { ctx, _ in IslandScenery.draw(region.id, in: ctx, scale: s) }
                Ellipse().fill(.white.opacity(0.95)).frame(width: 36 * s, height: 10 * s).position(x: 20 * s, y: 100 * s * 0.84)
                Ellipse().fill(.white.opacity(0.95)).frame(width: 32 * s, height: 9 * s).position(x: 100 * s, y: 104 * s * 0.88)
            }
        }
    }

    /// 圆章：拿到秘籍画这一卷的主题粒子，没拿到画灰问号；最后进去过的地区边是红的。
    var badge: some View {
        ZStack {
            Circle().fill(Color(hex: 0xFFF6E0))
            if obtained {
                let k = RankFx.order.firstIndex(of: region.volume) ?? 0
                if RankFx.theme(region.volume).kind == .confetti {   // 一片小纸条认不出：画三片
                    ZStack {
                        RankFx.symbol(1000 + k * 10, base: 1000).rotationEffect(.degrees(-20)).offset(x: -5, y: -4)
                        RankFx.symbol(1000 + k * 10 + 1, base: 1000).rotationEffect(.degrees(25)).offset(x: 5, y: -2)
                        RankFx.symbol(1000 + k * 10 + 2, base: 1000).rotationEffect(.degrees(-5)).offset(x: 0, y: 6)
                    }
                    .scaleEffect(0.85)
                } else {
                    RankFx.symbol(1000 + k * 10, base: 1000).scaleEffect(1.35)
                }
            } else {
                Text("?").font(.system(size: 15, weight: .black, design: .rounded)).foregroundStyle(Color(hex: 0x5C6178))
            }
            Circle().stroke(recent ? Palette.red : Palette.ink, lineWidth: recent ? 2.8 : 2.2)
        }
        .frame(width: 30, height: 30)
    }

    /// 「N 张」：还在路上是交叉的剑，拿到秘籍是红色秘籍印。
    var chip: some View {
        HStack(spacing: 3) {
            if phase == .cleared {
                Image(systemName: "book.closed.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 15, height: 15).background(RoundedRectangle(cornerRadius: 3).fill(Palette.red))
            } else {
                Image(systemName: "xmark").font(.system(size: 8, weight: .black)).foregroundStyle(.white)
                    .frame(width: 15, height: 15).background(Circle().fill(Color(hex: 0x3E8A4F)))
            }
            Text("\(count)").font(.system(size: 13, weight: .black)).foregroundStyle(phase == .cleared ? Palette.red : Color(hex: 0x3E8A4F))
            Text("张").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.slate2)
        }
        .padding(.leading, 3).padding(.trailing, 6).padding(.vertical, 2)
        .background(Capsule().fill(.white))
        .overlay(Capsule().stroke(Palette.ink, lineWidth: 1.8))
        .fixedSize()
    }
}

/// 岛顶（120×104 的格子里，顶面在 y 20–45 之间）。
struct IslandTop: Shape {
    func path(in r: CGRect) -> Path {
        let sx = r.width / 120, sy = r.height / 104
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + (y + 12) * sy) }
        var path = Path()
        path.move(to: p(8, 44))
        path.addQuadCurve(to: p(34, 28), control: p(10, 30))
        path.addQuadCurve(to: p(86, 28), control: p(60, 22))
        path.addQuadCurve(to: p(112, 44), control: p(110, 30))
        path.addQuadCurve(to: p(60, 53), control: p(110, 51))
        path.addQuadCurve(to: p(8, 44), control: p(10, 51))
        path.closeSubpath()
        return path
    }
}

/// 岛下倒挂的石头。
struct IslandRock: Shape {
    func path(in r: CGRect) -> Path {
        let sx = r.width / 120, sy = r.height / 104
        let pts: [(CGFloat, CGFloat)] = [(12, 46), (22, 58), (30, 64), (40, 70), (48, 80), (56, 88), (64, 80), (72, 74), (84, 70), (94, 62), (102, 54), (108, 46)]
        var path = Path()
        for (i, q) in pts.enumerated() {
            let pt = CGPoint(x: r.minX + q.0 * sx, y: r.minY + (q.1 + 12) * sy)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

struct IslandStrata: Shape {
    func path(in r: CGRect) -> Path {
        let sx = r.width / 120, sy = r.height / 104
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + (y + 12) * sy) }
        var path = Path()
        path.move(to: p(22, 56)); path.addQuadCurve(to: p(100, 54), control: p(60, 62))
        path.move(to: p(36, 68)); path.addQuadCurve(to: p(86, 66), control: p(60, 72))
        return path
    }
}

/// 天空和云海：上面淡蓝灰，往下渐渐变暖；几条云带。
struct SkyBackground: View {
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(hex: 0xE6EBF3), Color(hex: 0xEEF0F0), Color(hex: 0xF3ECDF), Color(hex: 0xEFE2C9)],
                               startPoint: .top, endPoint: .bottom)
                ForEach([0.36, 0.55, 0.74, 0.92], id: \.self) { f in
                    CloudBand().frame(width: g.size.width * 1.2, height: 40).position(x: g.size.width / 2, y: g.size.height * f)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct CloudBand: View {
    var body: some View {
        GeometryReader { g in
            ForEach(0..<6, id: \.self) { k in
                Ellipse().fill(.white.opacity(0.75))
                    .frame(width: 90 + CGFloat(k % 3) * 18, height: 26 + CGFloat(k % 2) * 6)
                    .position(x: g.size.width * (0.08 + 0.17 * CGFloat(k)), y: g.size.height * (k % 2 == 0 ? 0.55 : 0.45))
            }
        }
    }
}

/// 云顶的山和武林大会的楼；集齐十卷时楼前挂的旗是红的、山尖发亮。
struct PeakArt: View {
    let open: Bool
    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / 176, sy = size.height / 80
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
            var m = Path()
            m.move(to: p(14, 74)); m.addLine(to: p(56, 26)); m.addLine(to: p(70, 40)); m.addLine(to: p(88, 8))
            m.addLine(to: p(112, 40)); m.addLine(to: p(124, 30)); m.addLine(to: p(162, 74)); m.closeSubpath()
            ctx.fill(m, with: .color(Color(hex: 0xCFD5E2)))
            ctx.stroke(m, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            var snow = Path()
            snow.move(to: p(80, 22)); snow.addLine(to: p(88, 8)); snow.addLine(to: p(98, 22)); snow.addLine(to: p(92, 19))
            snow.addLine(to: p(88, 25)); snow.addLine(to: p(84, 20)); snow.closeSubpath()
            ctx.fill(snow, with: .color(.white)); ctx.stroke(snow, with: .color(Palette.ink), lineWidth: 1.6)
            var roof = Path()
            roof.move(to: p(68, 50)); roof.addLine(to: p(72, 41)); roof.addLine(to: p(104, 41)); roof.addLine(to: p(108, 50)); roof.closeSubpath()
            ctx.fill(roof, with: .color(Palette.red)); ctx.stroke(roof, with: .color(Palette.ink), lineWidth: 2)
            let hall = Path(CGRect(x: 74 * sx, y: 50 * sy, width: 28 * sx, height: 12 * sy))
            ctx.fill(hall, with: .color(Color(hex: 0xF7EBCF))); ctx.stroke(hall, with: .color(Palette.ink), lineWidth: 2)
            ctx.fill(Path(CGRect(x: 84 * sx, y: 54 * sy, width: 8 * sx, height: 8 * sy)), with: .color(Palette.ink))
            var pole = Path(); pole.move(to: p(88, 41)); pole.addLine(to: p(88, 26))
            ctx.stroke(pole, with: .color(Palette.ink), lineWidth: 1.8)
            var flag = Path(); flag.move(to: p(88, 26)); flag.addLine(to: p(100, 30)); flag.addLine(to: p(88, 34)); flag.closeSubpath()
            ctx.fill(flag, with: .color(open ? Palette.red : Palette.faint)); ctx.stroke(flag, with: .color(Palette.ink), lineWidth: 1.4)
            for (cx, rx) in [(30.0, 36.0), (146.0, 38.0), (88.0, 30.0)] {
                ctx.fill(Path(ellipseIn: CGRect(x: (cx - rx) * sx, y: (cx == 88 ? 73 : 66) * sy, width: rx * 2 * sx, height: (cx == 88 ? 10 : 16) * sy)), with: .color(.white))
            }
        }
    }
}

/// 练功房：右下角一枚圆印，里面一个木人桩，下面「练功房」和词卡总数。固定在屏幕上，不随地图动。
struct PracticeSeal: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Canvas { ctx, size in
                    let s = size.width / 40
                    func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * s, y: y * s, width: w * s, height: h * s) }
                    let post = Path(roundedRect: r(16, 6, 8, 26), cornerRadius: 3.5 * s)
                    ctx.fill(post, with: .color(Color(hex: 0xA0724A))); ctx.stroke(post, with: .color(Palette.ink), lineWidth: 2)
                    var arms = Path()
                    arms.move(to: CGPoint(x: 8 * s, y: 14 * s)); arms.addLine(to: CGPoint(x: 16 * s, y: 14 * s))
                    arms.move(to: CGPoint(x: 24 * s, y: 12 * s)); arms.addLine(to: CGPoint(x: 32 * s, y: 12 * s))
                    arms.move(to: CGPoint(x: 10 * s, y: 22 * s)); arms.addLine(to: CGPoint(x: 16 * s, y: 22 * s))
                    ctx.stroke(arms, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
                    ctx.stroke(arms, with: .color(Color(hex: 0xA0724A)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                    let base = Path(ellipseIn: r(11, 30.5, 18, 5))
                    ctx.fill(base, with: .color(Color(hex: 0x8A6A47))); ctx.stroke(base, with: .color(Palette.ink), lineWidth: 1.3)
                }
                .frame(width: 40, height: 40)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color(hex: 0xFFF6E0)))
                .overlay(Circle().stroke(Palette.ink, lineWidth: 2.5))
                .background(Circle().fill(Palette.ink).offset(x: 3, y: 3))
                Text("练功房").font(Fonts.display(16)).foregroundStyle(Palette.ink)
                Text("\(count) 张").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("练功房，你的词卡 \(count) 张")
    }
}
