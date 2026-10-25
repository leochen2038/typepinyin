import SwiftUI

/// 秘籍重数的爆字母效果（试看版）：主题跟着卷走（每卷一种粒子和一种飞法，取自这片地区的景色），档次跟着重数走。
/// - 零重：默认彩纸；
/// - 一重：换成这一卷的主题粒子，6 片；二重 12 片；三重 20 片（最多）；
/// - 四重：再往上冲；五重：冲得更猛、横向散得更开。
/// 只有粒子跟着卷换，字母颜色统一（每个字一种颜色，同一张牌上会乱）。
/// 现在切片里还没有真的重数，用调参面板的「试看重数」把所有字母设成同一重。
enum RankFx {
    enum Kind { case confetti, plum, drop, tea, kite, moon, willow, spring, peach }

    struct Theme {
        let name: String
        let kind: Kind
        let colors: [Color]
        let accent: Color
    }

    static let order = ["base", "liangzi-shang", "liangzi-xia", "biyin-shang", "biyin-xia", "yw", "shengzi", "lv", "sanpin"]

    static let themes: [String: Theme] = [
        "base": Theme(name: "十里坡 · 彩纸", kind: .confetti, colors: Confetti.paper, accent: Palette.gold),
        "liangzi-shang": Theme(name: "白梅台 · 白梅", kind: .plum,
                               colors: [.white, Color(hex: 0xFFE3EA), .white], accent: Color(hex: 0xF08AA8)),
        "liangzi-xia": Theme(name: "潮头岛 · 浪花", kind: .drop,
                             colors: [Color(hex: 0x8FD3FF), .white, Color(hex: 0x4FA3E8)], accent: Color(hex: 0x3B8BD9)),
        "biyin-shang": Theme(name: "半山镇 · 茶叶", kind: .tea,
                             colors: [Color(hex: 0x5BAA4A), Color(hex: 0x8CC63F), Color(hex: 0x3E7D32)], accent: Color(hex: 0x3E7D32)),
        "biyin-xia": Theme(name: "长风城 · 纸鸢", kind: .kite,
                           colors: [Palette.red, Palette.gold, Color(hex: 0x3FBF8F)], accent: Palette.red),
        "yw": Theme(name: "月牙湾 · 月牙", kind: .moon,
                    colors: [Color(hex: 0xF5C542), Color(hex: 0xFFE07A), Color(hex: 0xE8A317)], accent: Palette.gold),
        "shengzi": Theme(name: "垂柳村 · 柳叶", kind: .willow,
                         colors: [Color(hex: 0xA8D86E), Color(hex: 0x7DBB4A), Color(hex: 0xC9E89A)], accent: Color(hex: 0x5E9E34)),
        "lv": Theme(name: "绿泉居 · 泉水", kind: .spring,
                    colors: [Color(hex: 0x3FBF8F), Color(hex: 0x8FE3C8), Color(hex: 0x2A9D8F)], accent: Color(hex: 0x2A9D8F)),
        "sanpin": Theme(name: "小桥乡 · 桃花", kind: .peach,
                        colors: [Color(hex: 0xFF9CC0), Color(hex: 0xFFC4D8), Color(hex: 0xFF7AA8)], accent: Color(hex: 0xFF5C93)),
    ]

    static func theme(_ volume: String) -> Theme { themes[volume] ?? themes["base"]! }

    /// 一个音节属于哪一卷：词表里有就用词表的，没有（比如诗文里的字）就按同一套规则现算。
    @MainActor static func volume(of s: String) -> String {
        if let v = AppResources.bank.syllableTable[s]?.volume { return v }
        guard let first = s.first else { return "base" }
        let initials = ["zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "r", "z", "c", "s", "y", "w"]
        let ini = initials.first { s.hasPrefix($0) && s.count > $0.count } ?? ""
        let rest = String(s.dropFirst(ini.count))
        if first == "y" || first == "w" { return "yw" }
        if s.contains("v") || (["j", "q", "x"].contains(ini) && rest.hasPrefix("u")) { return "lv" }
        if ["iu", "ui", "un"].contains(rest) { return "shengzi" }
        if !ini.isEmpty, ["iang", "iong", "iao", "ian", "ia", "ie", "uang", "uai", "uan", "ua", "uo"].contains(rest) { return "sanpin" }
        if ["an", "en", "in"].contains(rest) { return "biyin-shang" }
        if ["ang", "eng", "ing", "ong"].contains(rest) { return "biyin-xia" }
        if ["ai", "ei"].contains(rest) { return "liangzi-shang" }
        if ["ao", "ou"].contains(rest) { return "liangzi-xia" }
        return "base"
    }

    // MARK: 符号

    /// 主题粒子的符号编号：base + 卷序号 × 10 + 颜色序号（0…2），镶金版再 + 5。一卷占 10 个号。
    static func symbolIDs(volumes: Set<String>, base: Int) -> [Int] {
        var ids: [Int] = []
        for v in volumes {
            let k = order.firstIndex(of: v) ?? 0
            for c in 0..<3 { ids.append(base + k * 10 + c); ids.append(base + k * 10 + 5 + c) }
        }
        return ids
    }

    @ViewBuilder static func symbol(_ id: Int, base: Int) -> some View {
        let n = id - base
        let v = order[min(order.count - 1, n / 10)]
        let t = theme(v)
        let gold = n % 10 >= 5
        let c = t.colors[(n % 10) % 5 % t.colors.count]
        let edge = gold ? Palette.gold : Palette.ink
        let w: CGFloat = gold ? 1.6 : 1.4
        switch t.kind {
        case .confetti:
            Rectangle().fill(c).overlay(Rectangle().stroke(edge, lineWidth: w)).frame(width: 11, height: 7)
        case .plum:
            ZStack {
                ForEach(0..<5, id: \.self) { i in
                    Circle().fill(c).overlay(Circle().stroke(edge, lineWidth: w * 0.8))
                        .frame(width: 7, height: 7).offset(y: -4).rotationEffect(.degrees(Double(i) * 72))
                }
                Circle().fill(Color(hex: 0xF5C542)).frame(width: 4, height: 4)
            }
            .frame(width: 18, height: 18)
        case .drop:
            DropShape().fill(c).overlay(DropShape().stroke(edge, lineWidth: w)).frame(width: 9, height: 13)
        case .tea:
            LeafShape(thin: 0.42).fill(c).overlay(LeafShape(thin: 0.42).stroke(edge, lineWidth: w)).frame(width: 8, height: 15)
        case .kite:
            DiamondShape().fill(c).overlay(DiamondShape().stroke(edge, lineWidth: w)).frame(width: 11, height: 15)
        case .moon:
            CrescentShape().fill(c).overlay(CrescentShape().stroke(edge, lineWidth: w)).frame(width: 15, height: 15)
        case .willow:
            LeafShape(thin: 0.26).fill(c).overlay(LeafShape(thin: 0.26).stroke(edge, lineWidth: w)).frame(width: 6, height: 20)
        case .spring:
            Circle().fill(c).overlay(Circle().stroke(edge, lineWidth: w))
                .overlay(Circle().fill(.white.opacity(0.85)).frame(width: 3, height: 3).offset(x: -2, y: -2))
                .frame(width: 10, height: 10)
        case .peach:
            PetalShape().fill(c).overlay(PetalShape().stroke(edge, lineWidth: w)).frame(width: 11, height: 13)
        }
    }

    // MARK: 粒子的动作

    /// 每种粒子怎么飞（花瓣重力小、寿命长、慢慢翻；泡泡重力是负的、往上浮）。
    struct Motion {
        var grav = 900.0          // 重力（负的往上浮）
        var drag = 2.2            // 空气阻力
        var life = 1.0            // 寿命倍数
        var speed = 1.0           // 初速度倍数
        var up = 140.0            // 往上挑的初速度
        var spread = 1.0          // 迸出去的角度范围（1 = 四面八方，小 = 集中往上）
        var sway = 0.0            // 左右飘的幅度（pt）
        var swayHz = 3.0
        var wind = 0.0            // 横向一直吹的加速度（正的往右）
        var spin = 1.0            // 自转快慢倍数
        var flipHz = 12.0         // 翻面快慢（0 = 不翻）
        var tilt = false          // 跟着飘的方向斜过去（柳叶、纸鸢）
    }

    static func motion(_ kind: Kind) -> Motion {
        switch kind {
        case .confetti: return Motion()
        case .plum:   return Motion(grav: 160, drag: 1.6, life: 1.5, sway: 14, swayHz: 4, spin: 0.3, flipHz: 4)          // 白梅：轻飘飘地落
        case .peach:  return Motion(grav: 140, drag: 1.5, life: 1.5, sway: 18, swayHz: 3.5, spin: 0.3, flipHz: 3.5)      // 桃花：飘得更开
        case .willow: return Motion(grav: 200, drag: 1.8, life: 1.5, sway: 22, swayHz: 2.6, spin: 0, flipHz: 2, tilt: true) // 柳叶：像钟摆一样荡着落
        case .tea:    return Motion(grav: 500, drag: 2.0, life: 1.1, spin: 2.2, flipHz: 10)                              // 茶叶：翻滚着落
        case .drop:   return Motion(grav: 1500, drag: 1.2, life: 0.8, speed: 1.25, up: 260, spin: 0, flipHz: 0)          // 浪花：溅起来、很快落下
        case .spring: return Motion(grav: 1100, drag: 1.0, life: 0.95, speed: 1.1, up: 320, spread: 0.35, spin: 0, flipHz: 0) // 泉水：往上喷一股再落
        case .kite:   return Motion(grav: 250, drag: 1.4, life: 1.3, sway: 10, swayHz: 2, wind: 520, spin: 0.2, flipHz: 3, tilt: true) // 纸鸢：被风吹向一边
        case .moon:   return Motion(grav: -170, drag: 1.8, life: 1.3, up: 60, sway: 6, swayHz: 2, spin: 0, flipHz: 0)   // 月牙：慢慢往上浮
        }
    }

    /// 第 j 片在 t 秒时的位置、旋转、翻面、淡出（按这一卷的动作算，位置由时间直接算出来，不存状态）。
    /// `lift` 是额外往上冲的初速度（五重用，往上的爆发力更强）。
    static func particle(_ kind: Kind, seed: Int, j: Int, t: Double, speed: Double, lift: Double = 0)
        -> (x: Double, y: Double, rot: Double, flip: Double, fade: Double, life: Double)? {
        if kind == .confetti, lift == 0 { return Confetti.particle(seed: seed, j: j, t: t, speed: speed) }
        guard t >= 0 else { return nil }
        let m = motion(kind)
        let r1 = Confetti.rand(seed, j, 1), r2 = Confetti.rand(seed, j, 2), r3 = Confetti.rand(seed, j, 3)
        let life = (0.55 + 0.35 * r3) * m.life
        guard t < life else { return nil }
        let a = -Double.pi / 2 + (r1 - 0.5) * 2 * .pi * m.spread
        let v = 300 * speed * m.speed * (0.35 + 0.65 * r2)
        let vx = cos(a) * v, vy = sin(a) * v - m.up - lift * (0.6 + 0.4 * r2)
        let e = (1 - exp(-m.drag * t)) / m.drag
        let phase = r3 * 6.28
        let swing = sin(m.swayHz * 2 * .pi * t + phase)
        let x = vx * e + m.sway * swing + 0.5 * m.wind * t * t
        let y = (vy - m.grav / m.drag) * e + m.grav * t / m.drag
        let fade = t / life > 0.7 ? 1 - (t / life - 0.7) / 0.3 : 1
        var rot = r1 * 6 + (r2 - 0.5) * 24 * t * m.spin
        if m.tilt { rot = (m.wind > 0 ? 0.6 : 0) + 0.5 * swing }
        let flip = m.flipHz > 0 ? max(0.15, abs(cos(r3 * 6 + m.flipHz * t))) : 1
        return (x, y, rot, flip, fade, life)
    }

    // MARK: 粒子

    /// 每一重迸几片、往上冲多猛、横向散多开：一重少，三重最多，四重起往上冲，五重冲得更猛。
    static func level(_ rank: Int) -> (count: Int, lift: Double, speed: Double) {
        switch rank {
        case ...1: return (6, 0, 1)
        case 2: return (12, 0, 1)
        case 3: return (20, 0, 1)
        case 4: return (20, 230, 1.3)
        default: return (28, 420, 1.7)
        }
    }

    /// 一个字母迸出的主题粒子：每卷按自己的动作飞（见 motion），片数和冲力按重数（见 level）。
    /// 打字时迸的那几片传 `count` 和 `speed`，不跟重数走。
    static func draw(_ g: GraphicsContext, at p: CGPoint, seed: Int, t: Double, volume: String, rank: Int,
                     base: Int, count: Int? = nil, speed: Double? = nil) {
        let k = order.firstIndex(of: volume) ?? 0
        let kind = theme(volume).kind
        let flips = motion(kind).flipHz > 0
        let lv = level(rank)
        let n = count ?? lv.count
        let lift = count == nil ? lv.lift : 0
        let sp = speed ?? lv.speed
        for j in 0..<n {
            guard let q = particle(kind, seed: seed, j: j, t: t, speed: sp, lift: lift) else { continue }
            var c = g
            c.opacity = q.fade
            c.translateBy(x: p.x + q.x, y: p.y + q.y)
            c.rotate(by: .radians(q.rot))
            if flips { c.scaleBy(x: 1, y: q.flip) }
            if let sym = c.resolveSymbol(id: base + k * 10 + (seed * 7 + j) % 3) { c.draw(sym, at: .zero) }
        }
    }
}

/// 打字时的词牌要不要用主题粒子（试看重数一重及以上时打开），由 CardsView 往下传。
private struct RankFxOnKey: EnvironmentKey { static let defaultValue = false }
private struct RankFxThemeKey: EnvironmentKey { static let defaultValue = "" }
extension EnvironmentValues {
    var rankFxOn: Bool {
        get { self[RankFxOnKey.self] }
        set { self[RankFxOnKey.self] = newValue }
    }
    /// 试看时固定的主题（空 = 按字所属的卷）。
    var rankFxTheme: String {
        get { self[RankFxThemeKey.self] }
        set { self[RankFxThemeKey.self] = newValue }
    }
}

// MARK: - 粒子形状

struct DropShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.maxX + r.width * 0.15, y: r.midY + r.height * 0.1),
                   control2: CGPoint(x: r.maxX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.minX, y: r.maxY),
                   control2: CGPoint(x: r.minX - r.width * 0.15, y: r.midY + r.height * 0.1))
        return p
    }
}

/// 叶子：两头尖的橄榄形，`thin` 越小越细长（柳叶比茶叶细）。
struct LeafShape: Shape {
    var thin: CGFloat
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width * thin * 2
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.midX + w, y: r.midY))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.midX - w, y: r.midY))
        return p
    }
}

struct DiamondShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.38))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.38))
        p.closeSubpath()
        return p
    }
}

/// 月牙：一个圆减去偏到右上的另一个圆。
struct CrescentShape: Shape {
    func path(in r: CGRect) -> Path {
        let R = min(r.width, r.height) / 2
        let big = Path(ellipseIn: CGRect(x: r.midX - R, y: r.midY - R, width: R * 2, height: R * 2))
        let cut = Path(ellipseIn: CGRect(x: r.midX - R * 0.45, y: r.midY - R * 1.15, width: R * 1.9, height: R * 1.9))
        return Path(big.cgPath.subtracting(cut.cgPath))
    }
}

/// 桃花瓣：圆圆的一片，顶上一个小缺口。
struct PetalShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX + r.width * 0.3, y: r.minY), control1: CGPoint(x: r.minX - r.width * 0.2, y: r.midY + r.height * 0.2),
                   control2: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + r.height * 0.18))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.3, y: r.minY))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.minY),
                   control2: CGPoint(x: r.maxX + r.width * 0.2, y: r.midY + r.height * 0.2))
        return p
    }
}
