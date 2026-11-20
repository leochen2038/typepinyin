import LearningCore
import SwiftUI

/// 「拿到秘籍」演出：掌门被打赢的话（有就显示），书卷展开，卷名，这一卷到了第几重。
struct ObtainVolumeView: View {
    let volume: String
    let rank: Int
    /// 秘籍的名字和等级怎么写（按经验升级时是「白梅台秘籍」「1 级」）；nil = 原来的卷名和重数。
    var name: String? = nil
    var level: String? = nil
    /// 打赢掌门：掌门在秘籍上盖印（秘籍进岛时已经拿到）。
    var seal: String? = nil
    /// 掌门的名字和被打赢的话；没有就不显示。
    var boss: (name: String, line: String)? = nil
    /// 盖印演出里印落下那一下、标题出来那一下（响声、震动），旅程给。
    var onStamp: () -> Void = {}
    var onReveal: () -> Void = {}
    let onDone: () -> Void
    @State private var open = false

    var body: some View {
        if let seal { SealCeremony(volume: volume, name: name ?? "《\(Volumes.name(volume))》", level: level ?? "", seal: seal,
                                   boss: boss, onStamp: onStamp, onReveal: onReveal, onDone: onDone) } else { obtain }
    }

    private var obtain: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 14) {
                if let boss {
                    VStack(spacing: 4) {
                        Text(boss.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.gold)
                        Text("「\(boss.line)」").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32).padding(.bottom, 8)
                    .accessibilityIdentifier("bossDefeatLine")
                }
                Text(seal == nil ? "拿到秘籍" : "掌门在秘籍上盖了印").font(.system(size: 18, weight: .black)).foregroundStyle(Palette.gold)
                Text(name ?? "《\(Volumes.name(volume))》").font(Fonts.display(name == nil ? 40 : 34)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 26).padding(.vertical, 14)
                    .background(Color(hex: 0xF7EBCF))
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                    .overlay(alignment: .bottomTrailing) {
                        if let seal {                             // 掌门印：岛名第一个字，和山顶十方印是同一批
                            Text(seal).font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                                .frame(width: 36, height: 36).background(Palette.red)
                                .overlay(Rectangle().stroke(Color(hex: 0xFBF7EE), lineWidth: 2.5))
                                .rotationEffect(.degrees(-8)).offset(x: 14, y: 14)
                                .scaleEffect(open ? 1 : 2.4).opacity(open ? 1 : 0)
                        }
                    }
                    .scaleEffect(x: open ? 1 : 0.1, y: 1)
                Text(level ?? "第\(["", "一", "二", "三", "四", "五"][max(1, min(5, rank))])重").font(Fonts.display(26)).foregroundStyle(.white)
                Button(action: onDone) {
                    Text("收下").font(Fonts.display(22)).padding(.horizontal, 36).padding(.vertical, 10)
                        .background(Palette.gold).foregroundStyle(Palette.ink)
                        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                }
                .buttonStyle(.pop)
                .accessibilityIdentifier("obtainDone")
            }
        }
        .onAppear { withAnimation(.spring(duration: JourneyFlags.fast ? 0.05 : 0.6, bounce: 0.3)) { open = true } }
    }
}

// Motion Prompt #024 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#024
/// 打赢掌门的盖印仪式（2026-11-18）：秘籍封面先出来；印在上方悬起、往后一提（蓄力），再加速砸下（三次方先慢后快，下落时竖着拉长 1.12 倍）；
/// 落下那一下按 Motion Prompt #024 インパクトシェイク：整块震 1.1 秒（x 10 × e^(−5t) × sin(2π·5t)，y 7 × e^(−5t) × cos(2π·6.5t)，
/// 转 0.02 × e^(−5t) × sin(2π·5t + 0.6)），印压扁最多 22% 再弹回（0.3 秒），六道白线、几点朱砂往外溅、0.55 秒散完；
/// 印下面晕开一圈淡红；随后秘籍名和等级出来（响升级音效），最后才出「收下」。
struct SealCeremony: View {
    let volume: String
    let name: String
    let level: String
    let seal: String
    let boss: (name: String, line: String)?
    let onStamp: () -> Void
    let onReveal: () -> Void
    let onDone: () -> Void
    @State private var t0: Date?
    @State private var job: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let hover = 0.6, lift = 1.05, land = 1.38, reveal = 1.95, button = 2.35
    private static func clamp(_ x: Double) -> Double { min(1, max(0, x)) }

    var body: some View {
        TimelineView(.animation(paused: t0.map { Date().timeIntervalSince($0) > 3 } ?? true)) { tl in
            let t = reduceMotion ? 9 : t0.map { tl.date.timeIntervalSince($0) } ?? 0
            content(t)
        }
        .onAppear(perform: run)
        .onDisappear { job?.cancel() }
    }

    private func run() {
        guard !reduceMotion, !JourneyFlags.fast else { t0 = Date().addingTimeInterval(-9); onStamp(); onReveal(); return }
        t0 = Date()
        job = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.land))
            guard !Task.isCancelled else { return }
            onStamp()
            try? await Task.sleep(for: .seconds(Self.reveal - Self.land))
            guard !Task.isCancelled else { return }
            onReveal()
        }
    }

    private func content(_ t: Double) -> some View {
        let tau = t - Self.land
        // 整块震（#024）
        var dx = 0.0, dy = 0.0, rot = 0.0
        if tau > 0, tau < 1.1 {
            let e = exp(-5 * tau), ph = 2 * Double.pi * 5 * tau
            dx = 10 * e * sin(ph); dy = 7 * e * cos(ph * 1.3); rot = 0.02 * e * sin(ph + 0.6)
        }
        let bookIn = Self.clamp(t / 0.45)
        let rv = Self.clamp((t - Self.reveal) / 0.35)
        let bt = Self.clamp((t - Self.button) / 0.3)
        return ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                if let boss {
                    VStack(spacing: 4) {
                        Text(boss.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.gold)
                        Text("「\(boss.line)」").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .accessibilityIdentifier("bossDefeatLine")
                }
                Text("掌门盖印").font(.system(size: 15, weight: .black)).foregroundStyle(Palette.gold)
                    .tracking(6)
                ZStack {
                    BookCover(title: "", seal: "", sealColor: .clear, dim: false, volume: volume)
                        .frame(width: 132, height: 180)
                    stamp(t)
                        .offset(x: 30, y: 46)
                }
                .scaleEffect(0.7 + 0.3 * (1 - pow(1 - bookIn, 3)))
                .opacity(bookIn)
                .offset(x: dx, y: dy).rotationEffect(.radians(rot))
                VStack(spacing: 6) {
                    Text(name).font(Fonts.display(32)).foregroundStyle(.white)
                    if !level.isEmpty {
                        Text(level).font(Fonts.display(22)).foregroundStyle(Palette.gold)
                    }
                }
                .opacity(rv).offset(y: 12 * (1 - rv))
                Button(action: onDone) {
                    Text("收下").font(Fonts.display(22)).padding(.horizontal, 36).padding(.vertical, 10)
                        .background(Palette.gold).foregroundStyle(Palette.ink)
                        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                }
                .buttonStyle(.pop)
                .opacity(bt)
                .allowsHitTesting(bt > 0.5)
                .accessibilityIdentifier("obtainDone")
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// 印：悬起 → 往后一提 → 砸下 → 压扁弹回；落下后底下晕开一圈淡红，四周溅线和朱砂点。
    private func stamp(_ t: Double) -> some View {
        let size = 64.0
        let appear = Self.clamp((t - Self.hover) / 0.25)
        let liftP = Self.clamp((t - Self.hover) / (Self.lift - Self.hover))
        let dropP = Self.clamp((t - Self.lift) / (Self.land - Self.lift))
        let tau = t - Self.land
        let fall = pow(dropP, 3)                                  // 三次方：先慢后快
        let hoverY = -120 - 22 * (1 - pow(1 - liftP, 2))          // 往上提一点蓄力
        let y = tau > 0 ? 0 : hoverY * (1 - fall)
        let scale = tau > 0 ? 1 : 2.3 - 1.3 * fall
        let angle = tau > 0 ? -8 : -20 + 12 * fall
        let sq = tau > 0 && tau < 0.3 ? 1 - 0.22 * sin(tau / 0.3 * .pi) : (dropP > 0 && dropP < 1 ? 1.12 : 1)
        let shadow = Self.clamp(t > Self.hover ? (0.15 + 0.5 * fall) : 0)
        return ZStack {
            // 落点上的影子：越落越实
            Rectangle().fill(Color.black.opacity(tau > 0 ? 0 : shadow * 0.45))
                .frame(width: size * (1.4 - 0.4 * fall), height: size * (1.4 - 0.4 * fall))
                .blur(radius: 6 * (1 - fall))
                .rotationEffect(.degrees(-8))
            // 落下后晕开的一圈淡红
            if tau > 0 {
                let q = Self.clamp(tau / 0.6)
                Rectangle().fill(Color(hex: 0xC0392B).opacity(0.35 * (1 - q)))
                    .frame(width: size * (1 + 0.5 * q), height: size * (1 + 0.5 * q))
                    .rotationEffect(.degrees(-8))
            }
            if tau > 0, tau < 0.55 { splash(tau / 0.55, size: size) }
            SealMark(char: seal, size: size)
                .scaleEffect(x: 2 - sq, y: sq, anchor: .bottom)
                .scaleEffect(scale)
                .rotationEffect(.degrees(angle))
                .shadow(color: .black.opacity(tau > 0 ? 0 : 0.35), radius: 10 * (1 - fall), y: 14 * (1 - fall))
                .offset(y: y)
                .opacity(appear)
        }
    }

    /// 六道白线往外放射、几点朱砂往外溅（#024 的冲击线和尘土，换成白线和朱砂）。
    private func splash(_ p: Double, size: Double) -> some View {
        let q = 1 - pow(1 - p, 3)
        return Canvas { ctx, sz in
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            for i in 0..<6 {
                let a = Double(i) / 6 * 2 * .pi + 0.3
                let r0 = size * 0.62 + 30 * q, r1 = r0 + 18
                var path = Path()
                path.move(to: CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0))
                path.addLine(to: CGPoint(x: c.x + cos(a) * r1, y: c.y + sin(a) * r1))
                ctx.stroke(path, with: .color(.white.opacity(1 - p)), style: StrokeStyle(lineWidth: 5 * (1 - q), lineCap: .round))
            }
            for i in 0..<9 {
                let a = Double(i) * 2.399 + 0.8
                let d = size * 0.5 + q * (26 + Double(i % 3) * 14)
                let r = (4 - Double(i % 3)) * (1 - q * 0.6)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x + cos(a) * d - r, y: c.y + sin(a) * d - r, width: 2 * r, height: 2 * r)),
                         with: .color(Color(hex: 0xC0392B).opacity(1 - p)))
            }
        }
        .frame(width: size * 3, height: size * 3)
        .allowsHitTesting(false)
    }
}

/// 掌门印：朱红方印，白字（宋体最粗），里面一圈细白框；边缘不齐、印面有几处没沾上印泥，像真的石章盖出来的。
/// 每个字的磨损位置固定（按字算），同一个印每次盖出来一样。
struct SealMark: View {
    let char: String
    var size: CGFloat = 64
    static let cinnabar = Color(hex: 0xC0392B)
    static let paper = Color(hex: 0xFBF7EE)

    var body: some View {
        Canvas { ctx, sz in
            let s = Double(sz.width)
            var seed = UInt64(char.unicodeScalars.first?.value ?? 7) &* 2654435761 &+ 1
            func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
            // 外框：四条边上各取几点，往里外抖一点，角略圆
            let m = s * 0.03, j = s * 0.014
            var pts: [CGPoint] = []
            let n = 6
            for side in 0..<4 {
                for k in 0..<n {
                    let f = Double(k) / Double(n)
                    let off = (rnd() - 0.5) * 2 * j
                    switch side {
                    case 0: pts.append(CGPoint(x: m + (s - 2 * m) * f, y: m + off))
                    case 1: pts.append(CGPoint(x: s - m + off, y: m + (s - 2 * m) * f))
                    case 2: pts.append(CGPoint(x: s - m - (s - 2 * m) * f, y: s - m + off))
                    default: pts.append(CGPoint(x: m + off, y: s - m - (s - 2 * m) * f))
                    }
                }
            }
            var outline = Path()
            outline.addLines(pts)
            outline.closeSubpath()
            ctx.fill(outline, with: .color(Self.cinnabar))
            // 里面一圈细白框，有两处断口
            let inset = s * 0.11, lw = max(1, s * 0.03)
            let r = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
            let gapA = 0.15 + rnd() * 0.5, gapB = 0.2 + rnd() * 0.5
            var frame = Path()
            frame.move(to: CGPoint(x: r.minX, y: r.minY)); frame.addLine(to: CGPoint(x: r.minX + r.width * gapA, y: r.minY))
            frame.move(to: CGPoint(x: r.minX + r.width * (gapA + 0.08), y: r.minY)); frame.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            frame.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            frame.addLine(to: CGPoint(x: r.minX + r.width * (gapB + 0.07), y: r.maxY))
            frame.move(to: CGPoint(x: r.minX + r.width * gapB, y: r.maxY)); frame.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            frame.addLine(to: CGPoint(x: r.minX, y: r.minY))
            ctx.stroke(frame, with: .color(Self.paper), style: StrokeStyle(lineWidth: lw, lineCap: .square))
            // 字
            ctx.draw(Text(char).font(.system(size: s * 0.6, weight: .black, design: .serif)).foregroundColor(Self.paper),
                     at: CGPoint(x: s / 2, y: s / 2 + s * 0.01))
            // 没沾上印泥的小点（印面磨损）、边上缺口：挖空，露出底下的纸或封面
            ctx.blendMode = .destinationOut
            for _ in 0..<(s < 40 ? 3 : Int(10 + s / 8)) {                // 小印少几点，不然糊
                let x = m + rnd() * (s - 2 * m), y = m + rnd() * (s - 2 * m), rr = s * (0.004 + rnd() * 0.012)
                ctx.fill(Path(ellipseIn: CGRect(x: x - rr, y: y - rr, width: 2 * rr, height: 2 * rr)), with: .color(.black.opacity(0.85)))
            }
            // 边上几个缺口
            for _ in 0..<(s < 40 ? 1 : 3) {
                let side = Int(rnd() * 4), f = 0.15 + rnd() * 0.7, rr = s * (0.02 + rnd() * 0.02)
                let p: CGPoint = [CGPoint(x: s * f, y: m), CGPoint(x: s - m, y: s * f), CGPoint(x: s * f, y: s - m), CGPoint(x: m, y: s * f)][side]
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: 2 * rr, height: 2 * rr)), with: .color(.black))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(char)印")
    }
}
