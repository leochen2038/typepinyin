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
                    ForEach(books) { b in BookGainRow(book: b, onLevelUp: onLevelUp) }
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
                .compositingGroup().shadow(color: Palette.ink, radius: 0, x: 3, y: 3)
        }
        .buttonStyle(.plain)
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

/// 结算页的一本秘籍：小封面、名字、等级、「+41」；经验条上红色是原来的、金色是这一场涨的。
/// 收获那几行的数字跑完（约 0.9 秒）再开始涨。正好升级的那本分三步演：
/// ① 条从原来的位置涨满；② 升级：响升级音效、重震，「升到 N 级」盖上去，牌子闪一下，按新等级爆一次主题效果；③ 条清零，长到新的进度。
struct BookGainRow: View {
    let book: DuelController.SummaryBook
    /// 升级那一下（响音效、震动），旅程给。
    var onLevelUp: () -> Void = {}
    /// 条上金色走到哪（0…1）。
    @State private var fill: Double
    /// 红色（原来的）走到哪：升级后清零。
    @State private var base: Double
    @State private var up = false
    @State private var flash = 0.0
    @State private var burstAt = Date.distantFuture.timeIntervalSinceReferenceDate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let start = 0.9

    init(book: DuelController.SummaryBook, onLevelUp: @escaping () -> Void = {}) {
        self.book = book
        self.onLevelUp = onLevelUp
        _fill = State(initialValue: book.from)
        _base = State(initialValue: book.from)
    }

    var body: some View {
        Group { if book.leveledUp { levelUp } else { plain } }
            .onAppear(perform: run)
    }

    private func run() {
        guard !reduceMotion else {
            up = book.leveledUp
            base = book.leveledUp ? 0 : book.from
            fill = book.to
            if book.leveledUp { onLevelUp() }
            return
        }
        guard book.leveledUp else {
            withAnimation(.easeOut(duration: 0.7).delay(Self.start)) { fill = book.to }
            return
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.start))
            withAnimation(.easeIn(duration: 0.55)) { fill = 1 }                 // ① 涨满
            try? await Task.sleep(for: .seconds(0.6))
            onLevelUp()                                                          // ② 升级
            burstAt = Date().timeIntervalSinceReferenceDate
            flash = 0.9
            withAnimation(.easeOut(duration: 0.45)) { flash = 0 }
            withAnimation(.spring(duration: 0.35, bounce: 0.55)) { up = true }
            try? await Task.sleep(for: .seconds(0.35))
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { base = 0; fill = 0 }                           // ③ 清零，长到新进度
            withAnimation(.easeOut(duration: 0.6)) { fill = book.to }
        }
    }

    private var plain: some View {
        HStack(spacing: 10) {
            BookCover(title: "", seal: "", sealColor: .clear, dim: false, volume: book.id).frame(width: 28, height: 38)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(book.name).font(.system(size: 16, weight: .black))
                    badge(book.level)
                    Spacer()
                    Text("+\(book.gain)").font(Fonts.display(24)).foregroundStyle(Palette.red)
                }
                bar
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.name)，\(book.level) 级，经验加 \(book.gain)")
    }

    private func badge(_ level: Int) -> some View {
        Text("\(level) 级").font(.system(size: 12, weight: .black)).foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 1).background(Palette.red)
    }

    private var levelUp: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                BookCover(title: "", seal: "", sealColor: .clear, dim: false, volume: book.id).frame(width: 52, height: 70)
                    .scaleEffect(up ? 1 : 0.92)
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.name).font(.system(size: 15, weight: .black))
                    ZStack(alignment: .leading) {
                        Text("\(book.level - 1) 级").font(Fonts.display(34)).foregroundStyle(Palette.ink)
                            .opacity(up ? 0 : 1)
                        Text("升到 \(book.level) 级").font(Fonts.display(34)).foregroundStyle(Palette.red)
                            .scaleEffect(up ? 1 : 2.2, anchor: .leading)
                            .opacity(up ? 1 : 0)
                    }
                    Text(book.note.isEmpty ? " " : book.note).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.slate)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(up ? 1 : 0)
                }
            }
            HStack(spacing: 8) {
                bar
                Text("+\(book.gain)").font(Fonts.display(24)).foregroundStyle(Palette.red)
            }
        }
        .padding(12)
        .background(Color(hex: up ? 0xFFF6D6 : 0xFFFFFF))
        .overlay(Rectangle().fill(Color.white).opacity(flash).allowsHitTesting(false))
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
        .scaleEffect(up ? 1 : 0.98)
        .overlay { if !reduceMotion { burst } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book.name)升到 \(book.level) 级")
    }

    /// 按新等级爆一次主题效果：从封面和牌子上几处一起爆（和比武里打中时、秘籍页试看是同一个画法）。
    private var burst: some View {
        TimelineView(.animation(paused: Date().timeIntervalSinceReferenceDate - burstAt > 2)) { tl in
            Canvas { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate - burstAt
                guard t >= 0, t < 1.8 else { return }
                let pad = 140.0, w = size.width - pad * 2, h = size.height - pad * 2
                let spots = [CGPoint(x: pad + 38, y: pad + 47), CGPoint(x: pad + w * 0.45, y: pad + h * 0.3),
                             CGPoint(x: pad + w * 0.75, y: pad + h * 0.35), CGPoint(x: pad + w * 0.6, y: pad + h * 0.8)]
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

    private var bar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.mist2)
                Rectangle().fill(Palette.gold).frame(width: g.size.width * fill)
                Rectangle().fill(Palette.red).frame(width: g.size.width * base)
            }
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
        }
        .frame(height: 10)
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
