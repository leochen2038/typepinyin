import SwiftUI

/// 招式牌：左上轻中重和蓄势倍数，中间是字，每个字的拼音对齐写在它下面（像课本注音）。
/// 打完的音节黑色，正在打的音节蓝色加下划线，还没打到的字下面空着。
/// 场上只有一张牌时，牌放大居中。
struct CardsView: View {
    let c: DuelController

    var body: some View {
        let big = c.cards.count == 1
        HStack(spacing: 10) {
            ForEach(Array(c.cards.enumerated()), id: \.element.id) { i, card in
                let covered = c.coveredSlots.contains(i)
                CardView(card: card, big: big)
                    .opacity(covered ? 0 : 1)
                    .scaleEffect(covered ? 0.8 : 1)
                    .animation(.spring(duration: 0.25, bounce: 0.45), value: covered)
                    .background(GeometryReader { g in
                        Color.clear.preference(key: CardFrameKey.self, value: [i: g.frame(in: .named("duel"))])
                    })
                    .transition(.asymmetric(insertion: .modifier(active: FlipIn(angle: 90), identity: FlipIn(angle: 0)),
                                            removal: .opacity))
                    .accessibilityIdentifier("card\(i)")
                    .accessibilityValue(AppResources.isUITest ? c.letters(ofCard: i) : "")
            }
        }
        .animation(.spring(duration: 0.32, bounce: 0.35), value: c.cards.map(\.id))
        .environment(\.rankFxOn, c.tuning.rankFx >= 1)
        .environment(\.rankFxTheme, c.tuning.rankFxTheme)      // 试看重数时，打完一个字也迸这一卷的主题粒子
        .padding(.horizontal, big ? 48 : 16)
        .padding(.top, 8)
        .frame(height: big ? 128 : 104)
    }
}

/// 新牌像发牌一样翻进来。
struct FlipIn: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View {
        content.rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .opacity(angle >= 89 ? 0 : 1)
    }
}

/// 字和拼音：每个字一列，拼音对齐在字下面，列间距很小。
/// 一个字的拼音打完时，这一列放大弹一下、迸出小点，字和拼音变成红色，表示「这个字拿下了」。
struct WordColumns: View {
    let card: DuelController.CardVM
    var scale: CGFloat = 1
    /// 给了宽度时（打文字）：按每个字的拼音长短算出正好填满这么宽的字号（18–40pt），每个字按完整拼音占位，长拼音不压到旁边的字。
    var fitWidth: CGFloat? = nil
    @ScaledMetric(relativeTo: .title) private var base: CGFloat = 30

    /// 拼音是字号的一半，等宽字母约 0.6 个字号宽：一列宽 = max(1, 0.3 × 字母数) × 字号。
    static func fitSize(_ syllables: [String], width: CGFloat, gap: CGFloat) -> CGFloat {
        let units = syllables.reduce(0) { $0 + max(1, 0.3 * CGFloat($1.count)) }
        return min(40, max(18, (width - gap * CGFloat(max(0, syllables.count - 1))) / max(1, units)))
    }

    var body: some View {
        let chars = Array(card.text)
        let n = chars.count
        let fitted = fitWidth.map { Self.fitSize(card.syllables, width: $0, gap: 4) }
        let charSize = fitted ?? max(18, n >= 4 ? base * 0.68 : n == 3 ? base * 0.86 : max(26, base)) * scale
        let pySize: CGFloat = fitted.map { $0 * 0.5 } ?? (n >= 4 ? 10.5 : 13) * scale
        let parts = typedParts()
        HStack(alignment: .top, spacing: fitted != nil ? 4 : n >= 4 ? 1 : 3) {
            ForEach(0..<n, id: \.self) { k in
                CharColumn(char: chars[k], syllable: k < card.syllables.count ? card.syllables[k] : "",
                           pinyin: parts[k].text, current: parts[k].current, done: parts[k].done,
                           charSize: charSize, pySize: pySize, reserve: fitted != nil)
            }
        }
        .minimumScaleFactor(0.7)
    }

    /// 已打出的字母按音节分到每个字下面；标出正在打的音节和已经打完的音节。
    private func typedParts() -> [(text: String, current: Bool, done: Bool)] {
        var left = card.typed.count
        var marked = false
        var out: [(String, Bool, Bool)] = []
        for s in card.syllables {
            let take = min(left, s.count)
            left -= take
            let current = !marked && !card.typed.isEmpty && take < s.count
            if current { marked = true }
            out.append((String(s.prefix(take)), current, take == s.count))
        }
        while out.count < card.text.count { out.append(("", false, false)) }
        return out
    }
}

struct CharColumn: View {
    let char: Character
    var syllable = ""
    let pinyin: String
    let current: Bool
    let done: Bool
    let charSize: CGFloat
    let pySize: CGFloat
    /// 按完整拼音占好宽度（打文字时用）。
    var reserve = false
    @State private var pop = false
    @State private var burst: Int = 0
    @Environment(\.rankFxOn) private var rankFxOn
    @Environment(\.rankFxTheme) private var rankFxTheme

    var body: some View {
        VStack(spacing: 0) {
            Text(String(char))
                .font(Fonts.hanzi(charSize))
                .foregroundStyle(done ? Palette.red : Palette.ink)
            Text(pinyin.isEmpty ? " " : pinyin)
                .background(alignment: .center) { if reserve { Text(syllable).opacity(0) } }
                .frame(minWidth: reserve ? CGFloat(syllable.count) * pySize * 0.62 : nil)
                .font(Fonts.mono(pySize, weight: .bold))
                .foregroundStyle(current ? Palette.navy : done ? Palette.red : Palette.ink)
                .underline(current, color: Palette.navy)
                .lineLimit(1)
                .fixedSize()
        }
        .scaleEffect(pop ? 1.35 : 1)
        .overlay(Burst(trigger: burst, volume: !rankFxOn ? nil : !rankFxTheme.isEmpty ? rankFxTheme : RankFx.volume(of: syllable)))      // 盖在字上面，不然字把纸屑最密的中间挡掉
        .onChange(of: done) { _, now in
            guard now else { return }
            burst += 1
            withAnimation(.spring(duration: 0.12, bounce: 0.6)) { pop = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.13))
                withAnimation(.spring(duration: 0.2, bounce: 0.4)) { pop = false }
            }
        }
    }
}

/// 一圈小点向四周迸开再消失；`trigger` 每变一次迸一次。
/// 打完一个字：迸一把彩纸和星星（和回顾牌爆字母同一套，片数少一点、飞得近一点，围着这个字）。只在迸的那一下画，平时不挂视图。
struct Burst: View {
    let trigger: Int
    /// 非空时迸这一卷的主题粒子（试看秘籍重数时），否则迸默认彩纸。
    var volume: String? = nil
    var count = 6
    @State private var start: Date?
    private static let themed = 1000

    var body: some View {
        ZStack {
            if let start {
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSince(start)
                    Canvas { ctx, size in
                        let c = CGPoint(x: size.width / 2, y: size.height / 2)
                        if let v = volume {
                            RankFx.draw(ctx, at: c, seed: trigger, t: t, volume: v, rank: 1, base: Self.themed, count: count, speed: 0.55)
                        } else {
                            Confetti.draw(ctx, at: c, seed: trigger, t: t, count: count, speed: 0.55)
                        }
                    } symbols: {
                        if let v = volume {
                            ForEach(RankFx.symbolIDs(volumes: [v], base: Self.themed), id: \.self) { RankFx.symbol($0, base: Self.themed).tag($0) }
                        } else {
                            ForEach(Confetti.symbolIDs(), id: \.self) { Confetti.symbol($0).tag($0) }
                        }
                    }
                }
                .frame(width: 360, height: 360)       // 比字大得多，纸屑飞出去不被裁掉
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            let s = Date()
            start = s
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                if start == s { start = nil }
            }
        }
    }
}

/// 彩纸和星星：Canvas 符号（预先画好一次，之后只盖章）和按时间直接算的运动（不用存状态）。
enum Confetti {
    static let paper: [Color] = [Palette.gold, Palette.red, .white, Palette.navy2, Color(hex: 0x3FBF8F)]

    /// 符号编号：纸片 base + 0…4，星星 base + 100…104。用的 Canvas 里其他符号别和它们撞号。
    static func symbolIDs(base: Int = 0) -> [Int] {
        paper.indices.map { base + $0 } + paper.indices.map { base + 100 + $0 }
    }

    @ViewBuilder static func symbol(_ id: Int, base: Int = 0) -> some View {
        let k = id - base
        if k >= 100 {
            StarShape().fill(k % 2 == 0 ? Palette.gold : .white).overlay(StarShape().stroke(Palette.ink, lineWidth: 1.6))
                .frame(width: 18, height: 18)
        } else {
            Rectangle().fill(paper[k]).overlay(Rectangle().stroke(Palette.ink, lineWidth: 1.4))
                .frame(width: 11, height: 7)
        }
    }

    /// 从 p 迸出 count 片（每 4 片里一颗星）：速度、重力、阻力都按时间直接算位置。
    static func draw(_ g: GraphicsContext, at p: CGPoint, seed: Int, t: Double, count: Int = 9, speed: Double = 1, base: Int = 0) {
        for j in 0..<count {
            guard let q = particle(seed: seed, j: j, t: t, speed: speed) else { continue }
            var c = g
            c.opacity = q.fade
            c.translateBy(x: p.x + q.x, y: p.y + q.y)
            c.rotate(by: .radians(q.rot))
            let star = j % 4 == 0
            if !star { c.scaleBy(x: 1, y: q.flip) }        // 纸片翻转
            let id = base + (star ? 100 : 0) + (seed * 7 + j) % paper.count
            if let sym = c.resolveSymbol(id: id) { c.draw(sym, at: .zero) }
        }
    }

    /// 第 j 片在 t 秒时相对迸出点的位置、旋转、翻转（纵向缩放）、淡出；过了寿命返回 nil。
    static func particle(seed: Int, j: Int, t: Double, speed: Double) -> (x: Double, y: Double, rot: Double, flip: Double, fade: Double, life: Double)? {
        guard t >= 0 else { return nil }
        let grav = 900.0, drag = 2.2
        let e = (1 - exp(-drag * t)) / drag
        let r1 = rand(seed, j, 1), r2 = rand(seed, j, 2), r3 = rand(seed, j, 3)
        let life = 0.55 + 0.35 * r3
        guard t < life else { return nil }
        let a = -Double.pi / 2 + (r1 - 0.5) * 2 * .pi
        let v = 300 * speed * (0.35 + 0.65 * r2)
        let vx = cos(a) * v, vy = sin(a) * v - 140          // 往上挑一点
        let x = vx * e
        let y = (vy - grav / drag) * e + grav * t / drag
        let fade = t / life > 0.7 ? 1 - (t / life - 0.7) / 0.3 : 1
        return (x, y, r1 * 6 + (r2 - 0.5) * 24 * t, max(0.15, abs(cos(r3 * 6 + 12 * t))), fade, life)
    }

    /// 固定的伪随机数（同一片纸每帧算出来一样）。
    static func rand(_ a: Int, _ b: Int, _ c: Int) -> Double {
        var h = UInt64(truncatingIfNeeded: a &* 73856093 ^ b &* 19349663 ^ c &* 83492791)
        h ^= h >> 13; h &*= 0x5bd1e995; h ^= h >> 15
        return Double(h % 10_000) / 10_000
    }
}

struct CardView: View {
    let card: DuelController.CardVM
    var big = false

    var body: some View {
        let glow = min(1, (card.store - 1))
        ZStack(alignment: .topLeading) {
            GeometryReader { g in
                VStack(spacing: 2) {
                    // 四个字以上（长词、五字句）按牌宽算字号，不挤出牌外
                    WordColumns(card: card, scale: big ? 1.4 : 1, fitWidth: card.text.count >= 4 ? g.size.width - 16 : nil)
                    Text(card.volumeLabel).font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.slate2).lineLimit(1)
                }
                .frame(width: g.size.width, height: g.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 4)
            .padding(.top, 8)
            HStack(spacing: 3) {
                Text(card.finisher ? "必杀" : card.weight)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(card.finisher ? Palette.red : Palette.slate2)
                if card.store >= 1.1 && !card.finisher {
                    Text("×\(String(format: "%.1f", card.store))").font(.system(size: 10, weight: .black)).foregroundStyle(Palette.red)
                }
            }
            .padding(.leading, 5).padding(.top, 3)
        }
        .frame(height: big ? 108 : 84)
        .background(background(glow: glow))
        .overlay(alignment: .topTrailing) {
            if card.flaw && !card.finisher {
                Text("破绽").font(.system(size: 10, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 4).padding(.vertical, 1).background(Palette.red)
                    .rotationEffect(.degrees(8)).offset(x: 6, y: -6)
            }
        }
        .overlay(
            Rectangle().strokeBorder(card.flaw && !card.finisher ? Palette.red : Palette.ink,
                                     style: StrokeStyle(lineWidth: 3, dash: card.flaw && !card.finisher ? [6, 4] : []))
        )
        .background(Rectangle().fill(Palette.ink).offset(x: card.locked ? 5 : 3, y: card.locked ? 5 : 3))   // 实心投影：比 shadow 省，动画时不用离屏重画
        .offset(x: card.locked ? -2 : 0, y: card.locked ? -4 : 0)
        .animation(.easeOut(duration: 0.12), value: card.locked)
        .scaleEffect(card.typed.isEmpty ? 1 : 1.04)
        .animation(.spring(duration: 0.12, bounce: 0.7), value: card.typed.count)
        .opacity(card.inactive ? 0.3 : 1)
        .grayscale(card.inactive ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.text)，\(card.weight)招\(card.flaw ? "，破绽" : "")")
    }

    private func background(glow: Double) -> Color {
        if card.finisher { return Palette.gold }
        if card.locked { return Palette.gold }
        return Color(red: 1, green: 1 - 0.08 * glow, blue: 1 - 0.3 * glow)
    }
}

/// 回顾：就在词牌的位置原地进行（打字时视线在这里）。先定格一下原样的词牌（最后一个字变红弹一下），
/// 再往下翻成回顾牌：拼音放大、字小字写在上面；主角每斩一刀，一个字母放大爆开、牌轻轻一震；
/// 最后一刀后金色冲击波外扩，完美的一招盖「完美」印，然后牌放大散去。期间一按下一个词的字母，回顾立刻收掉。
struct ReviewLayer: View {
    let reviews: [DuelController.Review]
    let cardFrames: [Int: CGRect]
    var big = true
    var rank = -1
    var theme = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(reviews) { r in
                if let f = cardFrames[r.slot] {
                    ZStack {
                        // 回顾牌一开始就放着（翻到背面看不见）：它的字母图在定格这 0.35 秒里先画好，翻牌那一帧就不会顿
                        ReviewCard(review: r, card: f.size, rank: rank, theme: theme)
                            .modifier(FlipX(angle: r.phase == 0 ? -90 : 0))
                        if r.phase == 0 {
                            // 定格：原样的词牌，最后一个字变红弹一下、整张放大；必杀时还要蓄力（发抖、聚气、高光扫过）
                            CardView(card: r.intro, big: big)
                                .frame(width: f.width, height: f.height)
                                .scaleEffect(r.intro.typed.count == r.card.typed.count ? 1.06 : 1)
                                .animation(.spring(duration: 0.16, bounce: 0.6), value: r.intro.typed.count)
                                .overlay { if r.card.finisher { FinisherCharge(born: r.born, size: f.size) } }
                                .modifier(Tremble(on: r.card.finisher))
                                .transition(.modifier(active: FlipX(angle: 90), identity: FlipX(angle: 0)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.18), value: r.phase)
                    .scaleEffect(r.leaving ? 1.3 : 1)
                    .opacity(r.leaving ? 0 : 1)
                    .animation(.easeOut(duration: 0.18), value: r.leaving)
                    .position(x: f.midX, y: f.midY)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// 必杀蓄力时词牌发抖：越抖越厉害（用重复动画，不每帧重建词牌）。
struct Tremble: ViewModifier {
    let on: Bool
    @State private var k: CGFloat = 0
    @State private var amp: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: on ? (k - 0.5) * amp : 0, y: on ? (0.5 - k) * amp * 0.5 : 0)
            .onAppear {
                guard on else { return }
                withAnimation(.linear(duration: 0.035).repeatForever(autoreverses: true)) { k = 1 }
                withAnimation(.easeIn(duration: 0.8)) { amp = 5 }
            }
    }
}

/// 必杀蓄力时词牌上的聚气：一圈圈红光从外往里收，一道白色高光从左往右扫过。画在一块画布上，按出现的时刻算。
struct FinisherCharge: View {
    let born: Double
    let size: CGSize

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate - born
            Canvas { ctx, sz in
                let card = CGRect(x: (sz.width - size.width) / 2, y: (sz.height - size.height) / 2, width: size.width, height: size.height)
                // 往里收的光圈：每 0.22 秒一圈，从 1.5 倍收到牌边
                for i in 0..<3 {
                    let k = (t / 0.22 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                    let grow = 0.5 * (1 - k)
                    let r = card.insetBy(dx: -card.width * grow * 0.3, dy: -card.height * grow)
                    ctx.stroke(Path(roundedRect: r, cornerRadius: 6), with: .color(Palette.red.opacity(0.75 * k)), lineWidth: 2 + 4 * k)
                }
                // 高光：一条斜的白带，0.45 秒扫过一次
                var clip = ctx
                clip.clip(to: Path(card))
                let k = (t / 0.45).truncatingRemainder(dividingBy: 1)
                let x = card.minX - 60 + (card.width + 120) * k
                var band = Path()
                band.move(to: CGPoint(x: x, y: card.minY)); band.addLine(to: CGPoint(x: x + 36, y: card.minY))
                band.addLine(to: CGPoint(x: x + 6, y: card.maxY)); band.addLine(to: CGPoint(x: x - 30, y: card.maxY))
                band.closeSubpath()
                clip.fill(band, with: .color(.white.opacity(0.55)))
            }
            .frame(width: size.width + 200, height: size.height + 120)
        }
        .allowsHitTesting(false)
    }
}

/// 绕水平轴翻：定格的词牌往下翻走，回顾牌从上面翻出来。
struct FlipX: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View {
        content.rotation3DEffect(.degrees(angle), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .opacity(abs(angle) >= 89 ? 0.001 : 1)     // 不用 0：完全透明 SwiftUI 可能不画，回顾牌就没法提前把字母图画好
    }
}

/// 回顾牌：整张牌在一块画布上按时间画出来（牌底、字、拼音、每个字母的放大、迸散的纸屑和星星、震动、冲击波、金字印）。
/// 做法：字母、字、纸屑、星星都先画成「符号」（只画一次，缓存成图），每帧只按位置、缩放、旋转把它们盖上去；
/// 不在每帧重新排字、画形状，字母再多也不卡。纸屑按速度、重力、阻力飞，位置由时间直接算出来。
struct ReviewCard: View {
    let review: DuelController.Review
    let card: CGSize
    /// 试看秘籍重数的爆字母效果：-1 = 关（默认彩纸），0–5 = 所有字母按这一重来爆；theme 非空时所有字母都用这一卷的主题。
    var rank = -1
    var theme = ""
    /// 画布比牌大一圈，冲击波、纸屑、金字印能画到牌外面；四重起粒子往上冲得远，画布再放大。
    private var pad: CGFloat { rank >= 4 ? 360 : 90 }

    private struct Layout {
        var size: CGFloat = 30
        var letters: [(ch: Character, p: CGPoint)] = []
        var volumes: [String] = []          // 每个字母所在音节属于哪一卷
        var chars: [(ch: Character, p: CGPoint)] = []
        var charSize: CGFloat = 16
    }

    private enum Tag { static let letterInk = 0, letterRed = 1000, char = 2000, confetti = 3000, seal = 4000,
                       themed = 5000 }   // 彩纸占 3000…3104，主题粒子占 5000…5099

    var body: some View {
        let L = layout()
        TimelineView(.animation) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, _ in draw(ctx, L, now: now) } symbols: {
                // 所有符号放在同一个 ForEach 里，id 用各自的编号：几个 ForEach 并列时 id 会重复，Canvas 会直接崩
                ForEach(symbolIDs(L), id: \.self) { id in symbol(id, L).tag(id) }
            }
        }
        .frame(width: card.width + pad * 2, height: card.height + pad * 2)
    }

    private func symbolIDs(_ L: Layout) -> [Int] {
        L.letters.indices.map { Tag.letterInk + $0 } + L.letters.indices.map { Tag.letterRed + $0 }
            + L.chars.indices.map { Tag.char + $0 }
            + Confetti.symbolIDs(base: Tag.confetti) + [Tag.seal]
            + (rank >= 1 ? RankFx.symbolIDs(volumes: Set(L.volumes), base: Tag.themed) : [])

    }

    @ViewBuilder private func symbol(_ id: Int, _ L: Layout) -> some View {
        switch id {
        case Tag.themed...:
            RankFx.symbol(id, base: Tag.themed)
        case Tag.seal:
            Text("完美").font(Fonts.display(20)).foregroundStyle(.white)
                .frame(width: 58, height: 34)
                .background(RoundedRectangle(cornerRadius: 6).fill(Palette.red))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.ink, lineWidth: 2.5))
        case Tag.confetti...:
            Confetti.symbol(id, base: Tag.confetti)
        case Tag.char...:
            Text(String(L.chars[id - Tag.char].ch)).font(Fonts.hanzi(L.charSize)).foregroundStyle(Palette.slate)
        case Tag.letterRed...:
            Text(String(L.letters[id - Tag.letterRed].ch)).font(Fonts.mono(L.size, weight: .black)).foregroundStyle(Palette.red)
        default:
            Text(String(L.letters[id - Tag.letterInk].ch)).font(Fonts.mono(L.size, weight: .black)).foregroundStyle(Palette.ink)
        }
    }

    /// 排版只算一次：每个字一列，字小在上，拼音大在下；字号按牌宽缩，长成语也放得下。坐标以牌左上角为原点。
    private func layout() -> Layout {
        let c = review.card
        let chars = Array(c.text)
        let n = chars.count
        let total = c.syllables.joined().count
        let gap: CGFloat = n >= 4 ? 6 : 10
        let fit = (card.width - 24 - gap * CGFloat(max(0, n - 1))) / (CGFloat(max(1, total)) * 0.62)
        var L = Layout()
        L.size = min(n >= 4 ? 30 : 42, fit)
        L.charSize = max(14, L.size * 0.55)
        let letterW = L.size * 0.6
        let cols: [CGFloat] = (0..<n).map { k in max(L.charSize, CGFloat(k < c.syllables.count ? c.syllables[k].count : 0) * letterW) }
        let totalW = cols.reduce(0, +) + gap * CGFloat(max(0, n - 1))
        let charH = L.charSize * 1.15, letterH = L.size * 1.1
        let top = card.height / 2 - (charH + letterH) / 2
        var x = card.width / 2 - totalW / 2
        for k in 0..<n {
            let w = cols[k]
            L.chars.append((chars[k], CGPoint(x: x + w / 2, y: top + charH / 2)))
            let syl = k < c.syllables.count ? Array(c.syllables[k]) : []
            var lx = x + (w - CGFloat(syl.count) * letterW) / 2
            let vol = theme.isEmpty ? (k < c.syllables.count ? RankFx.volume(of: c.syllables[k]) : "base") : theme
            for ch in syl {
                L.letters.append((ch, CGPoint(x: lx + letterW / 2, y: top + charH + letterH / 2)))
                L.volumes.append(vol)
                lx += letterW
            }
            x += w + gap
        }
        return L
    }

    private func draw(_ ctx: GraphicsContext, _ L: Layout, now: Double) {
        let r = review
        let popAt = r.popAt
        let popped = popAt.filter { $0 <= now }
        let doneAt: Double? = !L.letters.isEmpty && popped.count >= L.letters.count ? popped.last : nil
        let lastPop = popped.last ?? -10

        // 整张牌：轻微放大；最后一刀后再大一点；每一刀往下顿一下
        let grow = doneAt.map { Self.easeOut(min(1, (now - $0) / 0.15)) } ?? 0
        let scale = 1.04 + 0.04 * grow
        let dn = now - lastPop
        let nudge: CGFloat = dn < 0.03 ? 5 * dn / 0.03 : dn < 0.15 ? 5 * (1 - (dn - 0.03) / 0.12) : 0
        var g = ctx
        g.translateBy(x: pad + card.width / 2, y: pad + card.height / 2 + nudge)
        g.scaleBy(x: scale, y: scale)
        g.translateBy(x: -card.width / 2, y: -card.height / 2)
        let rect = CGRect(origin: .zero, size: card)

        if let d = doneAt, now - d < 0.4 {               // 冲击波（画在牌后面）
            let k = (now - d) / 0.4
            let ring = rect.insetBy(dx: -rect.width * 0.22 * k, dy: -rect.height * 0.22 * k)
            g.stroke(Path(ring), with: .color(Palette.gold.opacity(1 - k)), lineWidth: 6 * (1 - k) + 1)
        }
        g.fill(Path(rect.offsetBy(dx: 5, dy: 5)), with: .color(Palette.ink))
        g.fill(Path(rect), with: .color(r.card.finisher ? Palette.gold : Color(hex: 0xFFF6D6)))
        g.stroke(Path(rect), with: .color(Palette.ink), lineWidth: 3)

        for (k, c) in L.chars.enumerated() {
            if let s = g.resolveSymbol(id: Tag.char + k) { g.draw(s, at: c.p) }
        }
        // 先画没在放大的字母，再画正在放大的（压在上面），最后画纸屑
        var active: [(Int, Double)] = []
        for i in L.letters.indices {
            let dt = i < popAt.count ? now - popAt[i] : -1
            if dt >= 0 && dt < 0.32 { active.append((i, dt)); continue }
            if let s = g.resolveSymbol(id: (dt >= 0 ? Tag.letterRed : Tag.letterInk) + i) { g.draw(s, at: L.letters[i].p) }
        }
        for (i, dt) in active {
            let p = L.letters[i].p
            if dt < 0.2 {                                  // 一圈白光
                let k = Self.easeOut(dt / 0.2)
                let rr = L.size * (0.3 + 0.9 * k)
                g.stroke(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)),
                         with: .color(.white.opacity(1 - dt / 0.2)), lineWidth: 5 * (1 - dt / 0.2) + 1)
            }

            // 放大：一下子到 1.75 倍，再在 0.32 秒里平滑落回
            let k = Self.easeOut(dt / 0.32)
            let s = 1 + 0.75 * (1 - k) * (1 - k)
            var l = g
            l.translateBy(x: p.x, y: p.y)
            l.scaleBy(x: s, y: s)
            if let sym = l.resolveSymbol(id: Tag.letterRed + i) { l.draw(sym, at: .zero) }
        }
        for i in L.letters.indices where i < popAt.count {
            let dt = now - popAt[i]
            guard dt >= 0 && dt < 1.5 else { continue }        // 花瓣、柳叶飘得久，留够时间
            if rank >= 1 {
                RankFx.draw(g, at: L.letters[i].p, seed: i, t: dt, volume: L.volumes[i], rank: rank, base: Tag.themed)
            } else {
                Confetti.draw(g, at: L.letters[i].p, seed: i, t: dt, base: Tag.confetti)
            }
        }

        if r.gold, let d = doneAt, now >= d {            // 金字印：从大到小盖下来
            let k = Self.easeOut(min(1, (now - d) / 0.15))
            var s = g
            s.translateBy(x: rect.maxX - 7, y: rect.minY + 5)
            s.rotate(by: .degrees(-12))
            let sc = 2.4 - 1.4 * k
            s.scaleBy(x: sc, y: sc)
            s.opacity = k
            if let sym = s.resolveSymbol(id: Tag.seal) { s.draw(sym, at: .zero) }
        }
    }

    private static func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
}

/// 五角星（纸屑里的小星星）。
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY), R = min(rect.width, rect.height) / 2
        for i in 0..<10 {
            let r = i % 2 == 0 ? R : R * 0.45
            let a = Double(i) / 10 * 2 * .pi - .pi / 2
            let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
