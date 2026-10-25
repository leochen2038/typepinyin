import SwiftUI

/// 取字：把刚按的字母从键上取到主角身上。两种演出：
///
/// 绳镖（style 1）：
/// - 每个字母一次（grabs）：扬手 → 甩出（绳子边飞边抖）→ 钉住（键上一闪、绳子绷直颤一下）→ 拽回。
/// - 一个音节一次（chains）：镖头先飞到第一个字母，后面每个字母镖头在键之间跳过去，字母串在绳上；
///   音节打完，整串顺着绳子收回手里（离手近的先到）。
///
/// 剑气（style 0）：没有线、人不用动，字母自己化成一团光打进主角身上（绳镖是实物、有墨线描边；剑气是光，没有描边）。
/// - 每个字母一次：键上炸开一圈光芒，字母发着光从键里升起、聚气 → 化成一道剑气，拖着又长又宽的光尾越飞越快，
///   打进主角胸口，胸口亮一圈。
/// - 一个音节一次：字母一个个被震出来，发着光悬在键上；音节打完先聚到一起合成一大团（带着整个音节），
///   再整团打进主角身上，亮一大圈、迸一圈火星。
struct GrabLayer: View {
    let grabs: [DuelController.Grab]
    let chains: [DuelController.Chain]
    /// 后手（"duel" 坐标，绳镖从这里出手）。每帧取一次，因为出手时手在动。
    let hand: () -> CGPoint
    /// 主角胸口（"duel" 坐标，剑气打进这里）。
    let chest: () -> CGPoint
    /// 字母键中心点（"duel" 坐标）。
    let key: (Character) -> CGPoint?
    var style = 1
    var hot = false

    private typealias C = DuelController
    private var color: Color { hot ? Palette.red : Palette.gold }

    var body: some View {
        TimelineView(.animation(paused: grabs.isEmpty && chains.isEmpty)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate      // 用时间线的时刻，不然 SwiftUI 可能不重画
            Canvas { ctx, _ in
                let h = hand(), b = chest()
                for g in grabs {
                    guard let k = key(g.letter) else { continue }
                    if style == 0 { qiSingle(ctx, g, target: b, key: k, t: now - g.start) } else { single(ctx, g.letter, hand: h, key: k, t: now - g.start) }
                }
                for c in chains {
                    if style == 0 { qiChain(ctx, c, target: b, now: now) } else { chain(ctx, c, hand: h, now: now) }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: 每个字母甩一次

    private func single(_ ctx: GraphicsContext, _ letter: Character, hand: CGPoint, key: CGPoint, t: Double) {
        let t1 = C.ropeWind, t2 = t1 + C.ropeOut, t3 = t2 + C.ropeHold
        guard t >= t1 else { return }                              // 还在扬手，镖在手里
        let d = unit(hand, key)
        if t < t2 {
            let u = 1 - pow(1 - (t - t1) / C.ropeOut, 2)
            let head = lerp(hand, key, u)
            cord(ctx, points(hand, head, wave: 9 * (1 - u), phase: t * 40, sag: 12 * (1 - u)))
            dart(ctx, tip: head, dir: d)
        } else if t < t3 {
            let v = (t - t2) / C.ropeHold
            cord(ctx, points(hand, key, wave: 5 * (1 - v) * sin(v * .pi * 3), phase: .pi / 2, sag: 0))   // 绷直，颤一下
            dart(ctx, tip: key, dir: d)
            hit(ctx, at: key, age: t - t2)
            badge(ctx, letter, at: CGPoint(x: key.x, y: key.y - 16 * v), r: 9 + 4 * v)
        } else {
            let v = min(1, pow((t - t3) / C.ropeBack, 2))          // 越拽越快
            let head = lerp(key, hand, v)
            cord(ctx, points(hand, head, wave: 0, phase: 0, sag: 3))
            dart(ctx, tip: head, dir: d)
            hit(ctx, at: key, age: t - t2)
            badge(ctx, letter, at: CGPoint(x: head.x, y: head.y - 16 * (1 - v)), r: 13 - 5 * v)
        }
    }

    // MARK: 一个音节甩一次

    private func chain(_ ctx: GraphicsContext, _ c: C.Chain, hand: CGPoint, now: Double) {
        // 已经钉住的字母（串在绳上，浮在键上方一点）和还在飞的镖头
        var nodes: [CGPoint] = [hand]
        var beads: [(letter: Character, at: CGPoint, key: CGPoint, age: Double)] = []
        var head: CGPoint?
        for (n, hk) in c.hooks.enumerated() {
            guard now >= hk.from, let k = key(hk.letter) else { break }
            if now >= hk.at {
                let age = now - hk.at
                let p = CGPoint(x: k.x, y: k.y - 18 * min(1, age / 0.08))
                nodes.append(p)
                beads.append((hk.letter, p, k, age))
            } else {
                let u = 1 - pow(1 - (now - hk.from) / (hk.at - hk.from), 2)
                let a = nodes.last!
                let lift = n == 0 ? 0 : 22 * sin(.pi * u)          // 键之间跳：往上拱一下
                head = CGPoint(x: a.x + (k.x - a.x) * u, y: a.y + (k.y - a.y) * u - lift)
                break
            }
        }
        guard nodes.count > 1 || head != nil else { return }      // 还在扬手

        if let y = c.yankAt, now >= y {
            // 收回：整条绳往手里抽，绳上的字母顺着绳子滑进手里
            var acc: [Double] = [0]
            for i in 1..<nodes.count { acc.append(acc[i - 1] + hypot(nodes[i].x - nodes[i - 1].x, nodes[i].y - nodes[i - 1].y)) }
            let total = acc.last!
            let pulled = total * min(1, pow((now - y) / C.chainBack, 1.6))
            func along(_ a: Double) -> CGPoint {
                guard a > 0 else { return nodes[0] }
                for i in 1..<nodes.count where acc[i] >= a {
                    let f = (a - acc[i - 1]) / max(0.001, acc[i] - acc[i - 1])
                    return lerp(nodes[i - 1], nodes[i], f)
                }
                return nodes.last!
            }
            let end = total - pulled
            var path = [nodes[0]]
            for i in 1..<nodes.count where acc[i] < end { path.append(nodes[i]) }
            let tip = along(end)
            path.append(tip)
            cord(ctx, path)
            for (i, b) in beads.enumerated() {
                let a = acc[i + 1] - pulled
                if a > 0 { badge(ctx, b.letter, at: along(a), r: 13) }
            }
            dart(ctx, tip: tip, dir: unit(path.count > 1 ? path[path.count - 2] : hand, tip == hand ? CGPoint(x: hand.x + 1, y: hand.y) : tip))
            return
        }

        // 串着：每段绳微微下垂；第一下甩出去时绳子在抖
        let flying = nodes.count == 1
        var pts: [CGPoint] = []
        let all = nodes + (head.map { [$0] } ?? [])
        for i in 1..<all.count {
            let len = hypot(all[i].x - all[i - 1].x, all[i].y - all[i - 1].y)
            let seg = flying ? points(all[0], all[1], wave: 9, phase: now * 40, sag: 12)
                             : points(all[i - 1], all[i], wave: 0, phase: 0, sag: min(14, 4 + 0.05 * len))
            pts += i == 1 ? seg : Array(seg.dropFirst())
        }
        cord(ctx, pts)
        for b in beads {
            hit(ctx, at: b.key, age: b.age)
            badge(ctx, b.letter, at: b.at, r: 9 + 4 * min(1, b.age / 0.08))
        }
        let tip = all.last!
        dart(ctx, tip: tip, dir: unit(all[all.count - 2], tip))
    }

    // MARK: 剑气：每个字母一次

    private func qiSingle(_ ctx: GraphicsContext, _ g: C.Grab, target: CGPoint, key: CGPoint, t: Double) {
        burst(ctx, at: key, age: t)
        if t < C.qiCharge {
            // 在键上聚气：字母发着光从键里升起来、越聚越大
            let k = t / C.qiCharge
            glow(ctx, String(g.letter), at: CGPoint(x: key.x, y: key.y - 10 * k), r: 9 + 7 * k)
            return
        }
        // 化成一道剑气：越飞越快，拖一条又长又宽的光尾，打进主角身上
        let v = min(1, pow((t - C.qiCharge) / C.qiFly, 1.6))
        let arc = arcPath(CGPoint(x: key.x, y: key.y - 10), target, bend: g.bend)
        streak(ctx, arc, head: v, tail: 0.45, width: 1)
        glow(ctx, String(g.letter), at: arc(v), r: 16 - 6 * v)
    }

    // MARK: 剑气：一个音节一次

    private func qiChain(_ ctx: GraphicsContext, _ c: C.Chain, target: CGPoint, now: Double) {
        var held: [(letter: Character, at: CGPoint, age: Double)] = []
        for hk in c.hooks {
            guard now >= hk.pressed, let k = key(hk.letter) else { break }
            let age = now - hk.pressed
            burst(ctx, at: k, age: age)
            held.append((hk.letter, CGPoint(x: k.x, y: k.y - popLift(age)), age))
        }
        guard !held.isEmpty else { return }
        // 聚成一团的地方：这些字母的中间，再往上一点
        let mid = CGPoint(x: held.map(\.at.x).reduce(0, +) / Double(held.count),
                          y: held.map(\.at.y).reduce(0, +) / Double(held.count) - 40)

        guard let y = c.yankAt, now >= y else {
            // 悬在键上，发着光微微跳动
            for (i, h) in held.enumerated() {
                let r = 9 + 4 * min(1, h.age / 0.07) + 1.5 * sin(now * 18 + Double(i))
                glow(ctx, String(h.letter), at: h.at, r: r)
            }
            return
        }
        let e = now - y
        if e < C.qiMerge {
            // 聚：各自带一小段光尾冲向中间
            let v = pow(e / C.qiMerge, 2)
            for h in held {
                let at = lerp(h.at, mid, v)
                var line = Path()
                line.move(to: lerp(h.at, mid, max(0, v - 0.35)))
                line.addLine(to: at)
                ctx.stroke(line, with: .color(color.opacity(0.5)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                ctx.stroke(line, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                glow(ctx, String(h.letter), at: at, r: 13 - 3 * v)
            }
            return
        }
        // 合成一团大剑气，带着整个音节打进主角身上
        let v = min(1, pow((e - C.qiMerge) / C.qiFly, 1.6))
        let arc = arcPath(mid, target, bend: c.hooks[0].bend)
        streak(ctx, arc, head: v, tail: 0.5, width: 1.6)
        let text = String(held.map(\.letter))
        let k = (e - C.qiMerge) / C.qiFly
        glow(ctx, text, at: arc(v), r: (24 - 10 * v) * (k < 0.15 ? 0.8 + 1.4 * k : 1))      // 合成的一下先鼓一鼓
    }

    /// 字母被震出键：往上弹 20 pt，冲过头一点再落稳。
    private func popLift(_ age: Double) -> Double {
        let k = min(1, age / 0.07)
        return 20 * (1 + 0.25 * sin(k * .pi)) * (1 - pow(1 - k, 3))
    }

    /// 从 a 到 b 的弧线：控制点在中点往垂直方向偏，bend 定方向和大小（弯一点就好）。
    private func arcPath(_ a: CGPoint, _ b: CGPoint, bend: Double) -> (Double) -> CGPoint {
        let d = unit(a, b), len = hypot(b.x - a.x, b.y - a.y)
        let off = bend * (14 + 0.1 * len)
        let ctrl = CGPoint(x: (a.x + b.x) / 2 - d.y * off, y: (a.y + b.y) / 2 + d.x * off)
        return { t in
            let u = 1 - t
            return CGPoint(x: u * u * a.x + 2 * u * t * ctrl.x + t * t * b.x, y: u * u * a.y + 2 * u * t * ctrl.y + t * t * b.y)
        }
    }

    /// 剑气光尾：头在 head，尾巴拖在后面 tail 段，越往尾越细越淡。没有墨线描边，是一道光。
    /// 每层画成一整块收尖的形状（分段描线的话，半透明的圆头会叠出一颗颗亮点）。
    private func streak(_ ctx: GraphicsContext, _ at: (Double) -> CGPoint, head: Double, tail: Double, width: CGFloat) {
        let from = max(0, head - tail), steps = 14
        guard head > from else { return }
        let pts = (0...steps).map { at(from + (head - from) * Double($0) / Double(steps)) }
        func band(_ half: CGFloat) -> Path {
            var left: [CGPoint] = [], right: [CGPoint] = []
            for (i, p) in pts.enumerated() {
                let a = pts[max(0, i - 1)], b = pts[min(steps, i + 1)]
                let d = unit(a, b), w = half * width * CGFloat(i) / CGFloat(steps)
                left.append(CGPoint(x: p.x - d.y * w, y: p.y + d.x * w))
                right.append(CGPoint(x: p.x + d.y * w, y: p.y - d.x * w))
            }
            var path = Path()
            path.addLines(left + right.reversed())
            path.closeSubpath()
            path.addEllipse(in: CGRect(x: pts[steps].x - half * width, y: pts[steps].y - half * width, width: 2 * half * width, height: 2 * half * width))
            return path
        }
        ctx.fill(band(13), with: .color(color.opacity(0.25)))
        ctx.fill(band(5.5), with: .color(color.opacity(0.9)))
        ctx.fill(band(2), with: .color(.white))
    }

    /// 发光的字：外面一圈柔光、里面亮芯、白字，没有墨线，看得出是一团气。
    private func glow(_ ctx: GraphicsContext, _ text: String, at p: CGPoint, r: CGFloat) {
        let w = r * (1 + 0.45 * CGFloat(max(0, text.count - 1)))      // 一整个音节时拉成椭圆
        func oval(_ k: CGFloat) -> Path { Path(ellipseIn: CGRect(x: p.x - w * k, y: p.y - r * k, width: 2 * w * k, height: 2 * r * k)) }
        ctx.fill(oval(1.8), with: .color(color.opacity(0.22)))
        ctx.fill(oval(1.25), with: .color(color.opacity(0.55)))
        ctx.fill(oval(0.9), with: .color(color))
        ctx.fill(oval(0.55), with: .color(.white.opacity(0.85)))
        if r > 8 {
            ctx.draw(Text(text).font(Fonts.mono(r * 1.2, weight: .black)).foregroundStyle(hot ? Palette.ink : Palette.red), at: p)
        }
    }

    /// 键上炸开一下：白圈往外散，加一圈短光芒。
    private func burst(_ ctx: GraphicsContext, at p: CGPoint, age: Double) {
        let e = age / 0.16
        guard e < 1 else { return }
        hit(ctx, at: p, age: age)
        for i in 0..<8 {
            let a = Double(i) / 8 * .pi * 2
            let r0 = 10 + 14 * e, r1 = r0 + 10 * (1 - e)
            var ray = Path()
            ray.move(to: CGPoint(x: p.x + cos(a) * r0, y: p.y + sin(a) * r0))
            ray.addLine(to: CGPoint(x: p.x + cos(a) * r1, y: p.y + sin(a) * r1))
            ctx.stroke(ray, with: .color(color.opacity(1 - e)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    // MARK: 画

    /// 从 a 到 b 的绳子取样点：wave 是甩出去时的抖动幅度（两端为 0），sag 是往下垂多少。
    private func points(_ a: CGPoint, _ b: CGPoint, wave: Double, phase: Double, sag: Double) -> [CGPoint] {
        let d = unit(a, b), n = CGPoint(x: -d.y, y: d.x)
        return (0...12).map { i in
            let s = Double(i) / 12
            let w = wave * sin(s * .pi * 3 + phase) * sin(s * .pi)
            return CGPoint(x: a.x + (b.x - a.x) * s + n.x * w, y: a.y + (b.y - a.y) * s + n.y * w + sag * 4 * s * (1 - s))
        }
    }

    private func cord(_ ctx: GraphicsContext, _ pts: [CGPoint]) {
        guard pts.count > 1 else { return }
        var p = Path()
        p.addLines(pts)
        ctx.stroke(p, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        ctx.stroke(p, with: .color(Color(hex: 0xC89B5B)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
    }

    /// 镖头：尖在 tip，朝 dir 方向，后面一撮红缨。
    private func dart(_ ctx: GraphicsContext, tip: CGPoint, dir d: CGPoint) {
        let n = CGPoint(x: -d.y, y: d.x)
        let mid = CGPoint(x: tip.x - d.x * 10, y: tip.y - d.y * 10)
        let back = CGPoint(x: tip.x - d.x * 18, y: tip.y - d.y * 18)
        var shape = Path()
        shape.move(to: tip)
        shape.addLine(to: CGPoint(x: mid.x + n.x * 6, y: mid.y + n.y * 6))
        shape.addLine(to: back)
        shape.addLine(to: CGPoint(x: mid.x - n.x * 6, y: mid.y - n.y * 6))
        shape.closeSubpath()
        for s: CGFloat in [-1, 1] {
            var tassel = Path()
            tassel.move(to: back)
            tassel.addLine(to: CGPoint(x: back.x - d.x * 12 + n.x * 6 * s, y: back.y - d.y * 12 + n.y * 6 * s))
            ctx.stroke(tassel, with: .color(Palette.red), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        ctx.fill(shape, with: .color(Color(hex: 0xD9DEE8)))
        ctx.stroke(shape, with: .color(Palette.ink), lineWidth: 2)
    }

    /// 钉中字母键的一下：键上一圈白光往外散。
    private func hit(_ ctx: GraphicsContext, at p: CGPoint, age: Double) {
        let e = age / 0.14
        guard e < 1 else { return }
        let r = 8 + 16 * e
        ctx.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                   with: .color(.white.opacity(1 - e)), lineWidth: 3 * (1 - e) + 1)
    }

    private func badge(_ ctx: GraphicsContext, _ letter: Character, at p: CGPoint, r: CGFloat) {
        let disc = CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: disc), with: .color(color))
        ctx.stroke(Path(ellipseIn: disc), with: .color(Palette.ink), lineWidth: 2)
        if r > 8 { ctx.draw(Text(String(letter)).font(Fonts.mono(r * 1.3, weight: .black)).foregroundStyle(Palette.ink), at: p) }
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private func unit(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let len = max(0.001, hypot(b.x - a.x, b.y - a.y))
        return CGPoint(x: (b.x - a.x) / len, y: (b.y - a.y) / len)
    }
}

struct KeyboardFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    // 没报位置的兄弟视图给的是 .zero，不能盖掉真正的位置
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { let v = nextValue(); if v != .zero { value = v } }
}

struct CardFrameKey: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) { value.merge(nextValue()) { $1 } }
}

struct BattleFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    // 没报位置的兄弟视图给的是 .zero，不能盖掉真正的位置
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { let v = nextValue(); if v != .zero { value = v } }
}
