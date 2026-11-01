import SwiftUI

/// 状态栏：双方血条（斜切）、玩家气条、计时；下面一行是每招一个小圆点（最近 10 招，调参里可以关掉）。
struct StatusBarView: View {
    let c: DuelController

    var body: some View {
        VStack(spacing: 8) {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("你").font(Fonts.display(22))
                    Text("渐入佳境").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate)
                }
                SkewBar(value: Double(c.playerHP) / Double(max(1, c.playerMaxHP)), color: Palette.navy, height: 12, skew: -0.25, hitTrail: true)
                    .overlay(alignment: .trailing) { HurtFloat(hurt: c.hurt) }
                if c.tuning.qiBar {
                    SkewBar(value: Double(c.qi) / 100, color: Palette.gold, height: 7, skew: -0.25, border: 2, anim: DuelController.qiFlight)
                        .overlay { if c.qiReady { QiReadyGlow() } }
                        .background(GeometryReader { g in Color.clear.preference(key: QiBarFrameKey.self, value: g.frame(in: .named("duel"))) })
                        .frame(maxWidth: .infinity, alignment: .leading).scaleEffect(x: 0.86, anchor: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 3) {
                Text(timeText).font(Fonts.display(22)).monospacedDigit()
                // 不写「上一场 1:17」：对手血量按手速换算，一场总在 75 秒上下，比用时没有意义
                Text("比武").font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 1).background(Palette.ink)
            }
            .frame(width: 64)
            VStack(alignment: .trailing, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(c.foeTitle).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate)
                    Text(c.foeName).font(Fonts.display(22))
                }
                SkewBar(value: Double(c.foeHP) / Double(max(1, c.foeMaxHP)), color: Palette.life(c.foeLives), height: 12, skew: 0.25,
                        fromTrailing: true, track: c.foeLives > 1 && !c.knockdownHold ? Palette.life(c.foeLives - 1) : .white, anim: 0.6,
                        hitTrail: true)
                    .overlay { if c.foeMaxLives > 1 && c.foeLives == 1 { LastBreath() } }
                if c.foeMaxLives > 1 {
                    LifePips(left: c.foeLives, total: c.foeMaxLives)
                        .frame(maxWidth: .infinity, alignment: .trailing).scaleEffect(x: 0.86, anchor: .trailing)
                }
            }
            .frame(maxWidth: .infinity)
        }
            if c.tuning.moveDots {
                MoveDots(marks: c.moveMarks, total: c.movesPerDuel, finishers: c.finisherMoves)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(Palette.mist)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("你的血量 \(c.playerHP)，\(c.foeName) 的血量 \(c.foeHP)")
    }

    private var timeText: String { Self.fmt(c.elapsed) }

    static func fmt(_ t: Double) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct SkewBar: View {
    var value: Double
    var color: Color
    var height: CGFloat
    var skew: CGFloat
    var border: CGFloat = 2.5
    var fromTrailing = false
    var track: Color = .white
    var anim: Double = 0.25
    /// 血条受击（参考 pixelfx 的 ui/health-bar-hit）：掉血时血条马上落到新值、整条往下一顿，
    /// 掉的那一截是血条自己颜色的浅色：先亮一下、再稍深一点停 0.42 秒，然后用 0.43 秒缩回去。连着几刀掉血时，等最后一刀之后才缩。
    /// （先试过闪白，掌门多条命时白色夹在本色和下一条命的颜色中间，看着像血条空了一块。）
    var hitTrail = false
    @State private var trail: Double?
    @State private var flash = false
    @State private var jolt: CGFloat = 0
    @State private var hits = 0

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: fromTrailing ? .trailing : .leading) {
                Rectangle().fill(track)
                if let trail, trail > value {                  // 掉的那一截：血条自己颜色的浅色（不透明），不用白，免得看着像血条空了
                    ZStack { color; Color.white.opacity(flash ? 0.65 : 0.45) }
                        .frame(width: g.size.width * min(1, max(0, trail)))
                }
                Rectangle().fill(color).frame(width: g.size.width * min(1, max(0, value)))
                    .animation(.easeOut(duration: hitTrail ? 0.08 : anim), value: value)
            }
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: border))
            .transformEffect(CGAffineTransform(a: 1, b: 0, c: skew, d: 1, tx: -skew * height / 2, ty: 0))
        }
        .frame(height: height)
        .offset(y: jolt)
        .onChange(of: value) { old, new in
            guard hitTrail else { return }
            guard new < old else { trail = nil; return }        // 回血、换下一条命：不留残影
            trail = max(trail ?? old, old)
            flash = true
            hits += 1
            let mine = hits
            jolt = 2.5
            withAnimation(.spring(duration: 0.18, bounce: 0.6)) { jolt = 0 }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.1))
                guard mine == hits else { return }
                flash = false
                try? await Task.sleep(for: .seconds(0.32))
                guard mine == hits else { return }
                withAnimation(.easeInOut(duration: 0.43)) { trail = value }
                try? await Task.sleep(for: .seconds(0.45))
                if mine == hits { trail = nil }
            }
        }
    }
}

/// 命数：血条下面一块一块的备用命，每块是那条命的颜色（左边先灭）。打掉一条命熄灭一块。
/// 每块一样长（血条的四分之一，五条命正好排满），靠右排：三条命两块，两条命只有一小块。
struct LifePips: View {
    let left: Int
    let total: Int
    static let spacing: CGFloat = 5

    var body: some View {
        let spare = total - 1
        GeometryReader { g in
            let w = min((g.size.width - 3 * Self.spacing) / 4, (g.size.width - CGFloat(max(0, spare - 1)) * Self.spacing) / CGFloat(max(1, spare)))   // 超过五条命才缩短
            HStack(spacing: Self.spacing) {
                ForEach(0..<spare, id: \.self) { k in
                    let life = spare - k                        // 这一块代表「还剩 life 条」时那条血
                    let lit = life <= left - 1
                    SkewBar(value: lit ? 1 : 0, color: Palette.life(life), height: 7, skew: 0.25, border: 2, fromTrailing: true)
                        .frame(width: w)
                        .scaleEffect(lit ? 1 : 0.85)
                        .opacity(lit ? 1 : 0.4)
                }
            }
            .frame(width: g.size.width, alignment: .trailing)
        }
        .frame(height: 7)
        .animation(.spring(duration: 0.35, bounce: 0.6), value: left)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("对手还剩 \(left) 条命")
    }
}

/// 最后一条命：血条边框一闪一闪。
struct LastBreath: View {
    @State private var on = false

    var body: some View {
        Rectangle().stroke(Palette.red, lineWidth: 3)
            .transformEffect(CGAffineTransform(a: 1, b: 0, c: 0.25, d: 1, tx: -0.25 * 6, ty: 0))
            .opacity(on ? 1 : 0)
            .onAppear { withAnimation(.easeInOut(duration: 0.45).repeatForever()) { on = true } }
            .allowsHitTesting(false)
    }
}

/// 每招一个小圆点：完美的一招金色，普通招深蓝，必杀红底「杀」。
/// 固定招数时（total > 0）摆满 total 个，最后一个空位写「杀」；按血量打时只显示最近 10 招，多了就往左滚，最旧的一个淡出。
struct MoveDots: View {
    let marks: [Bool]
    let total: Int
    var finishers: Set<Int> = []
    private let window = 10

    var body: some View {
        let slots = total > 0 ? total : window
        let start = total > 0 ? 0 : max(0, marks.count - window)
        let shown = Array(start..<marks.count)
        HStack(spacing: 7) {
            ForEach(shown, id: \.self) { i in
                let finisher = finishers.contains(i)
                Circle()
                    .fill(finisher ? Palette.red : marks[i] ? Palette.gold : Palette.navy)
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
                    .overlay {
                        if finisher { Text("杀").font(.system(size: 8, weight: .black)).foregroundStyle(.white) }
                    }
                    .frame(width: 16, height: 16)
                    .scaleEffect(i == marks.count - 1 ? 1.25 : 1)
                    .transition(.asymmetric(insertion: .scale(scale: 0.2).combined(with: .opacity),
                                            removal: .scale(scale: 0.4).combined(with: .opacity)))
            }
            ForEach(shown.count..<slots, id: \.self) { k in
                Circle()
                    .fill(Color.white)
                    .overlay(Circle().stroke(Palette.ink.opacity(total > 0 ? 1 : 0.35), lineWidth: 2))
                    .overlay {
                        if total > 0 && k == slots - 1 {
                            Text("杀").font(.system(size: 8, weight: .black)).foregroundStyle(Palette.red)
                        }
                    }
                    .frame(width: 16, height: 16)
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.6), value: marks.count)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(total > 0 ? "第 \(marks.count) 招，共 \(total) 招"
                                      : "最近 \(shown.count) 招里 \(shown.filter { marks[$0] }.count) 招完美")
    }
}

/// 玩家掉血：血条闪一下红，旁边飘起一个红色「-N」再淡掉。
struct HurtFloat: View {
    let hurt: (amount: Int, token: Int)?
    @State private var shown: (amount: Int, token: Int)?
    @State private var rise = false

    var body: some View {
        ZStack(alignment: .trailing) {
            if let h = shown {
                Rectangle().fill(Palette.red.opacity(rise ? 0 : 0.55))
                    .allowsHitTesting(false)
                Text("-\(h.amount)")
                    .font(Fonts.display(22)).foregroundStyle(Palette.red)
                    .shadow(color: .white, radius: 0, x: 1, y: 1)
                    .offset(x: 4, y: rise ? -22 : 0)
                    .opacity(rise ? 0 : 1)
                    .id(h.token)
            }
        }
        .onChange(of: hurt?.token) { _, _ in
            guard let h = hurt else { return }
            shown = h
            rise = false
            withAnimation(.easeOut(duration: 0.9)) { rise = true }
        }
        .accessibilityHidden(true)
    }
}

// Motion Prompt #022 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#022
/// 气满了（还没送到牌上）：气条整条变朱红，按 Motion Prompt #022 ライトスイープ 扫光——一道柔和的白光带
/// （宽度是气条的 29%，中间透明度 0.72、两边渐隐）后面隔 20% 跟一道细光（3%，透明度 0.5），斜 24°，
/// 从气条左边外面扫到右边外面（easeInOut 2 次，1.05 秒），扫完在右端闪一颗四角星（0.6 秒，转 0.9 弧度），一轮 2.35 秒。不用字。
struct QiReadyGlow: View {
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { tl in
            let u = tl.date.timeIntervalSince(start).truncatingRemainder(dividingBy: 2.35)
            let x = min(1, max(0, (u - 0.1) / 1.05))
            let e = x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
            let q = (u - 1.0) / 0.6
            SkewBar(value: 1, color: Palette.red, height: 7, skew: -0.25, border: 2)
                .overlay {
                    GeometryReader { g in
                        let w = g.size.width
                        let cx = -0.33 * w + (1.66 * w) * e
                        ZStack(alignment: .leading) {
                            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.72), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                                .frame(width: w * 0.29).offset(x: cx - w * 0.145)
                            Rectangle().fill(Color.white.opacity(0.5))
                                .frame(width: max(2, w * 0.03)).offset(x: cx + w * 0.2)
                        }
                        .frame(width: w, height: g.size.height)
                        // 斜 24°：用斜切，不整体旋转（转了的话越往右越偏出这 7 点高的条，扫到三分之二就看不见了）
                        .transformEffect(CGAffineTransform(a: 1, b: 0, c: -tan(0.42), d: 1, tx: tan(0.42) * g.size.height / 2, ty: 0))
                    }
                    .clipped()
                }
                .overlay(alignment: .trailing) {
                    if q > 0 && q < 1 {                                        // 右端闪一颗四角星
                        Star4().fill(Color.white).overlay(Star4().stroke(Palette.ink, lineWidth: 1))
                            .frame(width: 18 * sin(.pi * q) * (1 + 0.2 * (1 - q)), height: 18 * sin(.pi * q) * (1 + 0.2 * (1 - q)))
                            .rotationEffect(.radians(0.9 * q))
                            .offset(x: 6)
                    }
                }
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }
}

/// 四角星。
struct Star4: Shape {
    func path(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY), R = min(r.width, r.height) / 2, i = R * 0.28
        var p = Path()
        for k in 0..<8 {
            let a = Double(k) / 8 * 2 * .pi - .pi / 2
            let d = k % 2 == 0 ? R : i
            let pt = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d)
            k == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

struct QiBarFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { let v = nextValue(); if v != .zero { value = v } }
}
