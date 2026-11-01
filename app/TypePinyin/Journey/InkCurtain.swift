import SwiftUI

// Motion Prompt #019 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#019
/// 水墨转场（Motion Prompt #019 リキッドトランジション，颜料换成墨）：墨从上往下流下来盖满画面，
/// 边缘是两道正弦波（振幅 13 和 8，按原版 539 宽的卡片换算），挂着 7 道圆头墨滴，波和墨滴在中途最大；
/// 盖满时换画面，墨再往下退，新画面从上面露出来。原版两层各 1.1 秒左右、easeInOut（2 次）；这里各 0.6 秒，不拖慢走路的节奏。
/// 原版用模糊加阈值做出液体粘连的质感，这里省掉，墨滴直接画圆头。
struct InkCurtain: Shape {
    static let cover = 0.6
    static let reveal = 0.6

    /// 盖的时候 0→1，墨面往下走到底；退的时候 1→0，墨的上沿往下走到底（进度接着上一段，不归零，免得动画被合并掉）。
    var level: Double
    var revealing: Bool

    private static let drips: [(x: Double, w: Double, len: Double)] =
        [(0.08, 38, 70), (0.21, 30, 110), (0.36, 54, 45), (0.5, 34, 90), (0.63, 46, 30), (0.78, 32, 100), (0.92, 44, 60)]

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let k = w / 539
        let t = revealing ? 1 - level : level
        let strength = sin(.pi * t)                           // 波和墨滴在中途最大，两头平
        // 墨面从 −110 走到底部 +130（原版的数值，按比例换算）
        let y0 = -110 * k, y1 = h + 130 * k
        let surface = y0 + (y1 - y0) * t
        func edge(_ x: Double) -> Double {
            surface + strength * k * (13 * sin(x / w * 2 * .pi * 1.6 + t * 5) + 8 * sin(x / w * 2 * .pi * 3.7 + 1.3 - t * 3))
        }
        var p = Path()
        let steps = 48
        if !revealing {
            p.move(to: CGPoint(x: 0, y: rect.minY - 200))
            p.addLine(to: CGPoint(x: w, y: rect.minY - 200))
            for i in stride(from: steps, through: 0, by: -1) {
                let x = w * Double(i) / Double(steps)
                p.addLine(to: CGPoint(x: x, y: edge(x)))
            }
            p.closeSubpath()
            for d in Self.drips {                                  // 墨滴：从墨面往下挂，圆头
                let x = d.x * w, dw = d.w * k
                let len = d.len * k * (0.25 + 0.9 * strength)
                let top = edge(x) - 4
                p.addRoundedRect(in: CGRect(x: x - dw / 2, y: top, width: dw, height: len + dw / 2),
                                 cornerSize: CGSize(width: dw / 2, height: dw / 2))
            }
        } else {
            p.move(to: CGPoint(x: 0, y: rect.maxY + 200))
            p.addLine(to: CGPoint(x: w, y: rect.maxY + 200))
            for i in stride(from: steps, through: 0, by: -1) {
                let x = w * Double(i) / Double(steps)
                p.addLine(to: CGPoint(x: x, y: edge(x)))
            }
            p.closeSubpath()
        }
        return p
    }
}

/// 跟着 JourneyController.inkPhase 演：1 盖下来，2 退下去，0 不显示；进度按这一段开始的时刻算（easeInOut 2 次）。演的时候挡住点按。
struct InkCurtainHost: View {
    let phase: Int
    let since: Date

    var body: some View {
        if phase != 0 {
            TimelineView(.animation) { tl in
                let dur = phase == 1 ? InkCurtain.cover : InkCurtain.reveal
                let x = min(1, max(0, tl.date.timeIntervalSince(since) / dur))
                let e = x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
                InkCurtain(level: phase == 1 ? e : 1 - e, revealing: phase == 2)
                    .fill(Palette.ink)
            }
            .contentShape(Rectangle())
        }
    }
}
