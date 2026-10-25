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
                SkewBar(value: Double(c.playerHP) / Double(max(1, c.playerMaxHP)), color: Palette.navy, height: 12, skew: -0.25)
                if c.tuning.qiBar {
                    SkewBar(value: Double(c.qi) / 100, color: Palette.gold, height: 7, skew: -0.25, border: 2)
                        .frame(maxWidth: .infinity, alignment: .leading).scaleEffect(x: 0.86, anchor: .leading)
                }
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 3) {
                Text(timeText).font(Fonts.display(22)).monospacedDigit()
                if let last = c.lastDuelSeconds {
                    Text("上一场 " + Self.fmt(last)).font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.slate)
                        .fixedSize()
                } else {
                    Text("比武").font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 5).padding(.vertical, 1).background(Palette.ink)
                }
            }
            .frame(width: 64)
            VStack(alignment: .trailing, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(c.foeTitle).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate)
                    Text(c.foeName).font(Fonts.display(22))
                }
                SkewBar(value: Double(c.foeHP) / Double(max(1, c.foeMaxHP)), color: Palette.life(c.foeLives), height: 12, skew: 0.25,
                        fromTrailing: true, track: c.foeLives > 1 && !c.knockdownHold ? Palette.life(c.foeLives - 1) : .white, anim: 0.6)
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

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: fromTrailing ? .trailing : .leading) {
                Rectangle().fill(track)
                Rectangle().fill(color).frame(width: g.size.width * min(1, max(0, value)))
                    .animation(.easeOut(duration: anim), value: value)
            }
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: border))
            .transformEffect(CGAffineTransform(a: 1, b: 0, c: skew, d: 1, tx: -skew * height / 2, ty: 0))
        }
        .frame(height: height)
    }
}

/// 命数：血条下面一块一块的备用命，每块是那条命的颜色（左边先灭）。打掉一条命熄灭一块。
struct LifePips: View {
    let left: Int
    let total: Int

    var body: some View {
        let spare = total - 1
        HStack(spacing: 5) {
            ForEach(0..<spare, id: \.self) { k in
                let life = spare - k                        // 这一块代表「还剩 life 条」时那条血
                let lit = life <= left - 1
                SkewBar(value: lit ? 1 : 0, color: Palette.life(life), height: 7, skew: 0.25, border: 2, fromTrailing: true)
                    .scaleEffect(lit ? 1 : 0.85)
                    .opacity(lit ? 1 : 0.4)
            }
        }
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
