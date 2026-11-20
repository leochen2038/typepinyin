import DuelCore
import SwiftUI

/// 小结卡片：先写收获，最后一行小字列这一场不熟练的音节；某一项为 0 或为空就不显示。输了标题是「再来一次」。
struct SummaryCardView: View {
    let s: DuelSummary
    let foe: String
    /// 旅程多出来的收获（「你已经能打出 N 个常用字」等），排在前面。
    var extraGains: [String] = []
    /// 秘籍进度（旅程给）：有的话不写「打赢了谁」，先写这一场打得怎样，秘籍进度放在按钮上面。
    var books: [DuelController.SummaryBook] = []
    /// 秘籍升级那一下（响音效、震动）。
    var onLevelUp: () -> Void = {}
    /// 秘籍经验条涨的时候一声一声（第 i 声）。
    var onTick: (Int) -> Void = { _ in }
    /// 旅程的按钮（空 = 「再来一场」）。
    var actions: [DuelController.SummaryAction] = []
    let onAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !s.won || books.isEmpty {
                Text(s.won ? "打赢了\(foe)" : "再来一次")
                    .font(Fonts.display(32))
            }
            if !s.won {
                Text("差一点，换个打法再试试").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.slate)
            }
            if s.charsPerMinute >= 1 {
                // 平均打字速度（原来是「比上一场快了 X 秒」：对手血量按手速换算，一场总在 75 秒上下，比用时没有意义）
                Text(String(format: "打字速度 %.0f 字/分", s.charsPerMinute))
                    .font(Fonts.display(22)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(Palette.gold)
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            }
            VStack(alignment: .leading, spacing: 8) {
                let lines = gainLines
                ForEach(Array(lines.enumerated()), id: \.element) { i, text in gain(text, order: i) }
            }
            if let raw = rawLine {
                // 拼错过、这一场还没打对的：放在收获后面，墨色小一号，只列正确拼法和词
                Text(raw).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !books.isEmpty {
                Rectangle().fill(Palette.mist2).frame(height: 2)
                VStack(alignment: .leading, spacing: 12) {
                    if !s.won { Text("秘籍照样涨了").font(.system(size: 14, weight: .black)).foregroundStyle(Palette.slate) }
                    ForEach(Array(books.enumerated()), id: \.element.id) { i, b in BookGainRow(book: b, order: i, onLevelUp: onLevelUp, onTick: onTick) }
                }
            }
            if actions.isEmpty {
                bigButton("再来一场", primary: true, action: onAgain).accessibilityIdentifier("again")
            } else {
                HStack(spacing: 12) {
                    ForEach(actions) { a in bigButton(a.label, primary: a.primary, action: a.action).accessibilityIdentifier(a.label) }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        .compositingGroup()
        .shadow(color: Palette.ink, radius: 0, x: 6, y: 6)
        .padding(.horizontal, 16)
    }

    private func bigButton(_ label: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(Fonts.display(24)).frame(maxWidth: .infinity).frame(height: 52)
                .background(primary ? Palette.gold : Color.white).foregroundStyle(Palette.ink)
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        }
        .buttonStyle(.pop)
    }

    private var gainLines: [String] {
        var out = extraGains
        if s.goldMoves > 0 { out.append("打出 \(s.goldMoves) 招完美") }
        if books.isEmpty {                                  // 有秘籍进度时这几行不写（用时、字数挪到收获页）
            if s.won { out.append(String(format: "用时 %d:%02d", Int(s.durationSeconds) / 60, Int(s.durationSeconds) % 60)) }
            if s.charactersTyped > 0 { out.append("打出了 \(s.charactersTyped) 个字") }
        }
        if s.maxCombo > 1 { out.append("最高 \(s.maxCombo) 连") }
        if s.parries > 0 { out.append("弹反 \(s.parries) 次") }
        // 「打顺了」改成按词卡说（旅程在 extraGains 里给：几张词卡练到熟练 / 精通）
        return out
    }

    /// 「不熟练：zhi（知道）、qu（去年）」：最多列 3 个，多的写「等 N 个」；没有就不出这一行。
    private var rawLine: String? {
        let raw = s.missed.filter { !$0.smoothed }
        guard !raw.isEmpty else { return nil }
        // 拼法和词之间、词里面不断行（U+2060），免得「ting」和「（挺身而出）」分到两行
        let shown = raw.prefix(3).map { "\($0.spelling)\u{2060}（\($0.word.map(String.init).joined(separator: "\u{2060}"))）" }.joined(separator: "、")
        return "不熟练：" + shown + (raw.count > 3 ? " 等 \(raw.count) 个" : "")
    }

    private func gain(_ text: String, order: Int) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Palette.gold).frame(width: 9, height: 9).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            CountUpText(text: text, delay: 0.15 + Double(order) * 0.12)
        }
    }
}

/// 结算页的一本秘籍：小封面、名字、等级、「+41」；经验条上青绿是原来的、金色是这一场涨的。
/// 收获那几行的数字跑完（约 0.9 秒）再开始涨，几本秘籍错开 0.35 秒。涨的手感：
/// 金色先快后慢冲上去（0.55 秒），条头一个白亮点、甩出金色小方块；一路「嗒嗒嗒」音调一个比一个高、配轻震；
/// 「+41」跟着条一起跑；到位那一下条竖着弹一下、闪白，最高一声。青绿晚 0.18 秒追上去。
/// 正好升级的那本：① 冲满；② 升级：响升级音效、重震，等级牌子换成新等级，按新等级爆一次主题效果（行不放大）；③ 条清零，再冲到新的进度。
struct BookGainRow: View {
    let book: DuelController.SummaryBook
    /// 第几本（错开出场）。
    var order = 0
    /// 升级那一下（响音效、震动），旅程给。
    var onLevelUp: () -> Void = {}
    /// 涨的时候一声一声（第 i 声，音调递增）和轻震，旅程给。
    var onTick: (Int) -> Void = { _ in }
    @State private var t0: Double?
    /// 响声音、升级的那串定时：结算页关掉（进下一场）时取消，不然下一场开头还会听到嗒嗒声。
    @State private var job: Task<Void, Never>?
    @State private var up = false
    @State private var burstAt = Date.distantFuture.timeIntervalSinceReferenceDate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let start = 0.9

    // 时间轴（秒，从这本开始涨算）
    static let rush = 0.55, lag = 0.18, chase = 0.5, pop = 0.28
    /// 升级：冲满之后多久清零再涨。
    static let hold = 0.45
    private var lead: Double { Self.start + Double(order) * 0.35 }
    /// 第二段（升级后）从几时开始。
    private var phase2: Double { Self.rush + Self.hold }
    private var total: Double { (book.leveledUp ? phase2 : 0) + Self.rush + Self.lag + Self.chase + Self.pop + 0.2 }

    /// 睡到某个时刻（timeIntervalSinceReferenceDate）。
    private static func sleep(until at: Double) async {
        let d = at - Date().timeIntervalSinceReferenceDate
        if d > 0 { try? await Task.sleep(for: .seconds(d)) }
    }

    private static func ease(_ x: Double) -> Double { let c = min(1, max(0, x)); return 1 - pow(1 - c, 3) }

    /// t 时刻：金色、青绿、跑过的经验（0…1）、到位弹一下的强度（0…1）、条头位置是否在冲。
    private func state(_ t: Double) -> (gold: Double, xp: Double, done: Double, pop: Double, rushing: Bool) {
        func seg(_ t: Double, from: Double, to: Double) -> (Double, Double, Double, Bool) {
            let g = from + (to - from) * Self.ease(t / Self.rush)
            let x = from + (to - from) * Self.ease((t - Self.lag) / Self.chase)
            let pp = t >= Self.rush ? max(0, 1 - (t - Self.rush) / Self.pop) : 0
            return (g, x, pp, t > 0 && t < Self.rush)
        }
        guard book.leveledUp else {
            let (g, x, pp, r) = seg(t, from: book.from, to: book.to)
            return (g, x, Self.ease(t / Self.rush), pp, r)
        }
        let a = 1 - book.from, sum = max(0.001, a + book.to)
        if t < phase2 {
            let (g, x, pp, r) = seg(t, from: book.from, to: 1)
            return (g, x, Self.ease(t / Self.rush) * a / sum, pp, r)
        }
        let (g, x, pp, r) = seg(t - phase2, from: 0, to: book.to)
        return (g, x, (a + Self.ease((t - phase2) / Self.rush) * book.to) / sum, pp, r)
    }

    var body: some View {
        TimelineView(.animation(paused: t0 == nil || Date().timeIntervalSinceReferenceDate - (t0 ?? 0) > total + 0.1)) { tl in
            let t = reduceMotion ? 99 : t0.map { tl.date.timeIntervalSinceReferenceDate - $0 } ?? -1
            row(state(t), t: t)
        }
        .onAppear(perform: run)
        .onDisappear { job?.cancel(); job = nil }
    }

    private func run() {
        guard !reduceMotion else {
            up = book.leveledUp
            if book.leveledUp { onLevelUp() }
            return
        }
        let begin = Date().timeIntervalSinceReferenceDate + lead
        t0 = begin
        job = Task { @MainActor in
            try? await Task.sleep(for: .seconds(lead))
            await ticks(span: book.leveledUp ? 1 - book.from : book.to - book.from, from: 0)
            guard book.leveledUp else { return }
            await Self.sleep(until: begin + Self.rush)
            guard !Task.isCancelled else { return }
            onLevelUp()                                                          // ② 升级
            burstAt = Date().timeIntervalSinceReferenceDate
            withAnimation(.spring(duration: 0.35, bounce: 0.55)) { up = true }
            await Self.sleep(until: begin + phase2)
            await ticks(span: book.to, from: 0)                                  // ③ 清零再冲
        }
    }

    /// 冲的这段按条走过的格数响几声（3～7 声），声音落在条正好走到那一格的时候；到位再响最高一声。
    private func ticks(span: Double, from: Int) async {
        let n = max(3, min(7, Int((span * 10).rounded())))
        let start = Date().timeIntervalSinceReferenceDate
        for k in 1...n {
            let p = 1 - pow(1 - Double(k) / Double(n + 1), 1.0 / 3)          // 反解先快后慢：走到第 k 格的时刻
            await Self.sleep(until: start + p * Self.rush)
            guard !Task.isCancelled else { return }
            onTick(from + k - 1)
        }
        await Self.sleep(until: start + Self.rush)
        guard !Task.isCancelled else { return }
        onTick(7)
    }

    private func row(_ s: (gold: Double, xp: Double, done: Double, pop: Double, rushing: Bool), t: Double) -> some View {
        HStack(spacing: 10) {
            BookCover(title: "", seal: "", sealColor: .clear, dim: false, volume: book.id).frame(width: 28, height: 38)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(book.name).font(.system(size: 16, weight: .black))
                    badge(book.leveledUp && !up ? book.level - 1 : book.level)
                        .id(up)
                        .transition(.scale(scale: 1.6).combined(with: .opacity))
                    Spacer()
                    // 宽度按最终值留好，右对齐，跑的时候不左右晃；到位跟着条弹一下
                    Text("+\(book.gain)").font(Fonts.display(24)).hidden()
                        .overlay(alignment: .trailing) {
                            Text("+\(Int((Double(book.gain) * s.done).rounded()))").font(Fonts.display(24))
                                .foregroundStyle(Palette.red).fixedSize()
                        }
                        .scaleEffect(1 + 0.25 * s.pop, anchor: .trailing)
                }
                bar(s, t: t)
            }
        }
        .overlay { if book.leveledUp && !reduceMotion { burst } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(book.leveledUp ? "\(book.name)升到 \(book.level) 级，经验加 \(book.gain)"
                                           : "\(book.name)，\(book.level) 级，经验加 \(book.gain)")
    }

    private func badge(_ level: Int) -> some View {
        Text("\(level) 级").font(.system(size: 12, weight: .black)).foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 1).background(Palette.red)
    }

    /// 按新等级爆一次主题效果：从封面、等级牌子和条上几处一起爆（和比武里打中时、秘籍页试看是同一个画法）。
    private var burst: some View {
        TimelineView(.animation(paused: Date().timeIntervalSinceReferenceDate - burstAt > 2)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate - burstAt
                guard t >= 0, t < 1.8 else { return }
                let pad = 140.0, w = size.width - pad * 2, h = size.height - pad * 2
                let spots = [CGPoint(x: pad + 14, y: pad + h * 0.5), CGPoint(x: pad + w * 0.35, y: pad + h * 0.25),
                             CGPoint(x: pad + w * 0.6, y: pad + h * 0.75), CGPoint(x: pad + w * 0.9, y: pad + h * 0.3)]
                for (k, p) in spots.enumerated() {
                    RankFx.draw(ctx, at: p, seed: 7 + k * 13, t: t - Double(k) * 0.06, volume: book.id, rank: book.level, base: 5000)
                }
            } symbols: {
                ForEach(RankFx.symbolIDs(volumes: [book.id], base: 5000), id: \.self) { id in RankFx.symbol(id, base: 5000).tag(id) }
            }
        }
        .padding(-140)
        .allowsHitTesting(false)
    }

    /// 经验条：底、金色、青绿；冲的时候条头一个白亮点、身后甩金色小方块；到位条竖着弹一下、闪白。
    private func bar(_ s: (gold: Double, xp: Double, done: Double, pop: Double, rushing: Bool), t: Double) -> some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.mist2)
                Rectangle().fill(Palette.gold).frame(width: w * s.gold)
                Rectangle().fill(Palette.xp).frame(width: w * min(s.xp, s.gold))
                if s.rushing {
                    Rectangle().fill(Color.white).frame(width: 6).offset(x: max(0, w * s.gold - 6))
                }
                Rectangle().fill(Color.white).opacity(0.85 * s.pop)
            }
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            .scaleEffect(x: 1, y: 1 + 0.6 * s.pop)
            .overlay(alignment: .leading) {
                if !reduceMotion { sparks(width: w, t: t).allowsHitTesting(false) }
            }
        }
        .frame(height: 10)
    }

    /// 条头甩出的金色小方块：每块在条头经过时生出来，往后上方飞、落下、变小消失（0.4 秒）。
    private func sparks(width w: Double, t: Double) -> some View {
        Canvas { ctx, size in
            let midY = size.height / 2
            func one(_ i: Int, born: Double, x: Double) {
                let age = t - born
                guard age >= 0, age < 0.4 else { return }
                var r = UInt64(i &* 2654435761 &+ 97)
                func rnd() -> Double { r = r &* 6364136223846793005 &+ 1442695040888963407; return Double(r >> 33) / Double(1 << 31) }
                let vx = -40 - rnd() * 90, vy = -60 - rnd() * 120
                let px = x + vx * age, py = midY + vy * age + 420 * age * age
                let side = (3 + rnd() * 3) * (1 - age / 0.4)
                let color = rnd() < 0.3 ? Color.white : Palette.gold
                ctx.fill(Path(CGRect(x: px - side / 2, y: py - side / 2, width: side, height: side)), with: .color(color))
                ctx.stroke(Path(CGRect(x: px - side / 2, y: py - side / 2, width: side, height: side)), with: .color(Palette.ink), lineWidth: 1)
            }
            let segs: [(start: Double, from: Double, to: Double)] = book.leveledUp
                ? [(0, book.from, 1), (phase2, 0, book.to)] : [(0, book.from, book.to)]
            for (si, sg) in segs.enumerated() {
                let n = 16
                for k in 0..<n {
                    let born = sg.start + Self.rush * Double(k) / Double(n) * 0.9
                    let x = 20 + (sg.from + (sg.to - sg.from) * Self.ease((born - sg.start) / Self.rush)) * w
                    one(si * 100 + k, born: born, x: x)
                }
                // 到位那一下往四周炸一小圈
                for k in 0..<8 {
                    one(si * 100 + 50 + k, born: sg.start + Self.rush, x: 20 + sg.to * w)
                }
            }
        }
        .frame(width: w + 40, height: 60)
        .offset(x: -20)
    }
}

// Motion Prompt #007 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#007
/// 数字往上跑（Motion Prompt #007 カウントアップ）：一行里的数字从 0 跑到目标，值 = 目标 × (1 − (1 − p)^4)（先快后慢），
/// 原版跑 2.45 秒，定住时变色、弹一下；结算卡片一行一行出，这里跑 0.9 秒、每行错开 0.12 秒，定住时不变色不弹（试玩时觉得多余）。
/// 数字放大成 26 号标题字，旁边的字照旧 16 号（只跑不放大时不够醒目）。
/// 「用时 0:33」这种带冒号的、没有数字的行照原样显示。
struct CountUpText: View {
    let text: String
    var delay = 0.0
    @State private var start: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let run = 0.9

    var body: some View {
        if let (pre, target, post) = Self.split(text), !reduceMotion {
            TimelineView(.animation(paused: start.map { Date().timeIntervalSince($0) > Self.run + 0.1 } ?? false)) { tl in
                let t = start.map { tl.date.timeIntervalSince($0) } ?? 0
                let p = min(1, max(0, t / Self.run))
                let v = Int((Double(target) * (1 - pow(1 - p, 4))).rounded())
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(pre)
                    // 数字放大成标题字（26 号），跑的时候宽度按最终值留好，右对齐，字不跟着左右晃
                    Text("\(target)").font(Fonts.display(26)).hidden()
                        .overlay(alignment: .trailing) { Text("\(v)").font(Fonts.display(26)).fixedSize() }
                        .padding(.horizontal, 3)
                    Text(post)
                }
                .font(.system(size: 16, weight: .bold))
            }
            .onAppear { start = Date().addingTimeInterval(delay) }
        } else {
            Text(text).font(.system(size: 16, weight: .bold))
        }
    }

    /// 「你已经能打出 151 个常用字」→（「你已经能打出 」, 151, 「 个常用字」）；带冒号（时间）或没有数字的返回 nil。
    static func split(_ s: String) -> (String, Int, String)? {
        guard !s.contains(":"), let r = s.range(of: "[0-9]+", options: .regularExpression), let n = Int(s[r]), n > 1 else { return nil }
        return (String(s[..<r.lowerBound]), n, String(s[r.upperBound...]))
    }
}
