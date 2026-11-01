import LearningCore
import SwiftUI

/// 秘籍页：顶上一排选项卡，一本秘籍一个（上下卷在同一页里上下排）。
/// 拿到的卷是一张「声母 × 韵母」的音节表，有词卡含它的格子写拼法和一张词卡，颜色是含它的最好那张词卡的等级（见过 / 熟练 / 精通）；
/// 没有词卡的格子留白。表下面是这一卷的词卡（含这一卷音节的都算），每张下面四个点，打对一场亮一个。
/// 没拿到的卷只有封面和去哪拿，不给看里面。刚拿到的卷第一次打开有揭开演出；上次来过以后新学会的音节带「新」字。
struct CodexView: View {
    @State var j: JourneyController
    @State private var picked: String?
    @State private var book: String?
    /// 正在演揭开的卷；演完以前这卷的格子先不露。
    @State private var unveiling: String?
    @State private var waved: Set<String> = []
    /// 这次进来时算出的新音节（离开时才记成看过，这次一直亮着）。
    @State private var fresh: Set<String> = []
    /// 词卡全部展开的卷。
    @State private var expanded: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 七本秘籍，按卷的顺序。
    static let books: [String] = Volumes.all.map(Volumes.book).reduce(into: []) { if !$0.contains($1) { $0.append($1) } }

    func volumes(of b: String) -> [String] { Volumes.all.filter { Volumes.book($0) == b } }

    func obtained(_ v: String) -> Bool { j.progress.volumes[v]?.obtained == true }

    /// 默认打开：刚拿到的那本，否则正在挑战的地区那本，否则最近拿到的那本，否则基本功。
    var defaultBook: String {
        if let v = j.booksToUnveil.first { return Volumes.book(v) }
        if let r = j.content.regions.first(where: { j.progress.regions[$0.id]?.phase == .inProgress }) { return Volumes.book(r.volume) }
        if let v = Volumes.all.last(where: obtained) { return Volumes.book(v) }
        return Self.books[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { j.screen = .map } label: {
                    Text("回江湖").font(.system(size: 15, weight: .black)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
                Text("秘籍").font(Fonts.display(26))
                    .overlay(PanelGesture { j.showPanel = true })
                Spacer()
            }
            .padding(.horizontal, 16).frame(height: 56)
            .background(Palette.mist)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }
            VStack(alignment: .leading, spacing: 10) {
                Text("收了 \(j.cards.count) 张词卡，打出过 \(j.typedCommonChars.formatted()) 个常用字")
                    .font(.system(size: 15, weight: .black))
                tabs
            }
            .padding(.horizontal, 16).padding(.top, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    let vs = volumes(of: book ?? defaultBook)
                    if vs.contains(where: obtained) { legend }
                    ForEach(vs, id: \.self) { v in
                        if obtained(v) { volumeBlock(v) } else { lockedBlock(v) }
                    }
                }
                .padding(16)
            }
            .id(book ?? defaultBook)
        }
        .background(Palette.mist)
        .overlay {
            if let v = unveiling {
                BookUnveil(title: Volumes.name(v), rank: "第\(Self.rankName(max(1, j.rank(of: v))))重", place: placeLine(v),
                           reduceMotion: reduceMotion || JourneyFlags.fast) {
                    j.duel.sounds.play(.levelup)
                    j.duel.sounds.hitHaptic(heavy: true)
                } done: { finishUnveil(v) }
                .id(v)
                .transition(.opacity)
            }
        }
        .sheet(item: Binding(get: { picked.map(Picked.init) }, set: { picked = $0?.id })) { p in
            SyllableDetailSheet(j: j, spelling: p.id).presentationDetents([.medium])
        }
        .onAppear {
            fresh = Set(j.newlyLearned)
            startNextUnveil()
        }
        .onDisappear {
            j.markCodexSeen(books: j.booksToUnveil.filter { waved.contains($0) }, syllables: Array(fresh))
        }
    }

    struct Picked: Identifiable { let id: String }

    // MARK: 揭开

    func startNextUnveil() {
        guard let v = j.booksToUnveil.first(where: { !waved.contains($0) }) else { return }
        book = Volumes.book(v)
        unveiling = v
    }

    /// 封面翻开以后：这一卷的格子一波波亮出来，记成揭开过，再接着演下一本（一次拿到好几本时）。
    func finishUnveil(_ v: String) {
        withAnimation(.easeOut(duration: 0.25)) { unveiling = nil }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : nil) { _ = waved.insert(v) }
        j.markCodexSeen(books: [v])
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.3 : 1.2))
            startNextUnveil()
        }
    }

    /// 格子露不露：正在揭开的卷要等封面翻完。
    func shown(_ v: String) -> Bool { unveiling != v && (waved.contains(v) || !j.booksToUnveil.contains(v)) }

    // MARK: 顶部

    /// 选项卡：书名，下面一行是重数（有上下卷的取高的那卷）或「还没拿到」。
    var tabs: some View {
        let current = book ?? defaultBook
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.books, id: \.self) { b in
                        let rank = volumes(of: b).map { j.rank(of: $0) }.max() ?? 0
                        let on = b == current
                        let isNew = volumes(of: b).contains { j.booksToUnveil.contains($0) && !waved.contains($0) }
                        Button { book = b } label: {
                            VStack(spacing: 1) {
                                Text(b).font(.system(size: 15, weight: .black))
                                Text(rank == 0 ? "还没拿到" : "第\(Self.rankName(rank))重")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(on ? Color.white.opacity(0.85) : (rank == 0 ? Palette.faint : Palette.red))
                            }
                            .foregroundStyle(on ? Color.white : (rank == 0 ? Palette.faint : Palette.ink))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(on ? Palette.ink : (rank == 0 ? Palette.mist : Color.white))
                            .overlay(Rectangle().stroke(rank == 0 && !on ? Palette.faint : Palette.ink, lineWidth: 1.5))
                            .overlay(alignment: .topTrailing) { if isNew { NewDot().offset(x: 5, y: -5) } }
                        }
                        .buttonStyle(.plain)
                        .id(b)
                        .accessibilityIdentifier("book-\(b)")
                    }
                }
                .padding(.vertical, 6).padding(.horizontal, 6)
            }
            .onAppear { proxy.scrollTo(current, anchor: .center) }
            .onChange(of: book) { _, b in withAnimation { proxy.scrollTo(b ?? defaultBook, anchor: .center) } }
        }
    }

    var legend: some View {
        HStack(spacing: 12) {
            ForEach(CardLevel.allCases, id: \.self) { p in
                HStack(spacing: 4) {
                    Rectangle().fill(Self.fill(p)).frame(width: 14, height: 14).overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
                    Text(p.name).font(.system(size: 13, weight: .bold))
                }
            }
        }
    }

    static func rankName(_ r: Int) -> String { ["", "一", "二", "三", "四", "五"][min(5, max(0, r))] }

    /// 词卡等级用墨色深浅：见过淡墨、熟练浓墨、精通朱红；没有词卡的留白。
    static func fill(_ p: CardLevel?) -> Color {
        switch p {
        case nil: Color(hex: 0xF6F3EC)
        case .met: Color(hex: 0xDCDCDA)
        case .fluent: Color(hex: 0x3B3B3B)
        case .master: Palette.red
        }
    }

    static func text(_ p: CardLevel?) -> Color { (p ?? .met) >= .fluent ? .white : Palette.ink }

    /// 「在葫芦集，从胡大叔手里拿到」/「在白梅台，梅娘手里（还在修路）」。
    func placeLine(_ v: String) -> String {
        guard let r = j.region(giving: v) else { return "" }
        return obtained(v) ? "在\(r.name)，从\(r.boss.name)手里拿到" : "在\(r.name)，\(r.boss.name)手里\(r.playable ? "" : "（还在修路）")"
    }

    // MARK: 卷

    /// 没拿到的卷：灰封面、「未得」印、去哪拿。
    func lockedBlock(_ v: String) -> some View {
        HStack(spacing: 14) {
            BookCover(title: Volumes.name(v), seal: "未得", sealColor: Palette.slate2, dim: true).frame(width: 66, height: 90)
            VStack(alignment: .leading, spacing: 6) {
                Text(Volumes.name(v)).font(Fonts.display(22)).foregroundStyle(Palette.slate2)
                Text(placeLine(v)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.slate)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.6))
        .overlay(Rectangle().stroke(Palette.faint, lineWidth: 1.5))
        .accessibilityIdentifier("locked-\(v)")
    }

    func volumeBlock(_ v: String) -> some View {
        let syl = j.content.syllables(in: v)
        let rank = j.rank(of: v)
        let inits = Array(Set(syl.map { $0.parts.initial })).sorted { order($0) < order($1) }
        let finals = Array(Set(syl.map { $0.parts.medial + $0.parts.final })).sorted()
        let table = Dictionary(syl.map { ($0.parts.initial + "|" + $0.parts.medial + $0.parts.final, $0.spelling) }, uniquingKeysWith: { a, _ in a })
        let show = shown(v)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                BookCover(title: Volumes.name(v), seal: Self.rankName(max(1, rank)), sealColor: Palette.red, dim: false)
                    .frame(width: 44, height: 60)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(Volumes.name(v)).font(Fonts.display(22))
                        Text("第\(Self.rankName(max(1, rank)))重")
                            .font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(Palette.red)
                    }
                    Text(placeLine(v)).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.slate2)
                }
                Spacer()
            }
            rankBar(v, rank: max(1, rank))
            Text(rankLine(v, rank: max(1, rank))).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.slate)
            let best = j.cardBest
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    GridRow {
                        Color.clear.frame(width: 26, height: 18)
                        ForEach(finals, id: \.self) { fin in
                            Text(fin).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate2).frame(width: 54)
                        }
                    }
                    ForEach(Array(inits.enumerated()), id: \.element) { row, ini in
                        GridRow {
                            Text(ini.isEmpty ? "–" : ini).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate2).frame(width: 26)
                            ForEach(Array(finals.enumerated()), id: \.element) { col, fin in
                                if let s = table[ini + "|" + fin] {
                                    cell(s, level: best[s], shown: show, delay: Double(row + col) * 0.035)
                                } else {
                                    Color.clear.frame(width: 54, height: 44)
                                }
                            }
                        }
                    }
                }
            }
            cardList(v)
        }
        .padding(12)
        .background(Color.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
    }

    /// 这一卷的词卡：先列最近、练得好的，太多时先露 24 张，点「全部」再展开。
    @ViewBuilder func cardList(_ v: String) -> some View {
        let cs = j.cards(in: v)
        let t = j.learner.tuning
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("词卡").font(Fonts.display(18))
                Text("收了 \(cs.count) 张").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.slate)
                Spacer()
                if cs.count > 24 {
                    Button(expanded.contains(v) ? "收起" : "全部") {
                        if expanded.contains(v) { expanded.remove(v) } else { expanded.insert(v) }
                    }
                    .font(.system(size: 12, weight: .black)).foregroundStyle(Palette.ink)
                }
            }
            if cs.isEmpty {
                Text("比武里打完一张牌，就收进词卡。").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.slate2)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(expanded.contains(v) ? cs : Array(cs.prefix(24)), id: \.text) { c in
                        CardChip(card: c, level: c.level(t), dots: t.masterDuels, fluentAt: t.fluentDuels)
                    }
                }
            }
        }
        .padding(.top, 6)
    }

    func order(_ ini: String) -> Int { (["", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "zh", "ch", "sh", "r", "z", "c", "s", "y", "w"].firstIndex(of: ini) ?? 99) }

    /// 往下一重的进度条：重数按词卡算（每个音节看含它的最好那张词卡，不是打得多就涨），条下写怎样升，不写「还差几个」。
    func rankBar(_ v: String, rank: Int) -> some View {
        let p = j.cardProgress(of: v)
        let how = ["", "这一卷一半的音节，各有一张熟练的词卡", "这一卷每个音节，都有一张熟练的词卡",
                   "这一卷一半的音节，各有一张精通的词卡", "这一卷每个音节，都有一张精通的词卡"]
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(rank >= 5 ? "第五重" : "往第\(Self.rankName(rank + 1))重")
                    .font(.system(size: 12, weight: .black)).foregroundStyle(Palette.ink)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Palette.mist2)
                        Rectangle().fill(Palette.red).frame(width: g.size.width * p)
                    }
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                }
                .frame(height: 10)
            }
            if rank < 5 {
                Text("\(how[rank])，升第\(Self.rankName(rank + 1))重").font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.slate2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// 这一重和下一重爆字母的样子。
    func rankLine(_ v: String, rank: Int) -> String {
        let theme = RankFx.theme(v).name
        let pieces = [9, 9, 16, 24, 30, 36]
        let now = "打中时爆 \(pieces[rank]) 片\(theme)\(rank >= 4 ? "，往上冲" : "")"
        guard rank < 5 else { return now + "，已经练到顶" }
        return now + "；练到第\(Self.rankName(rank + 1))重爆 \(pieces[rank + 1]) 片"
    }

    /// 有词卡的格子：拼法 + 含它的最好那张词卡；没有的留白。揭开时从左上往右下一波波亮出来。
    func cell(_ s: String, level p: CardLevel?, shown: Bool, delay: Double) -> some View {
        let word = p == nil ? nil : j.typedWords(with: s).first
        return Button { picked = s } label: {
            VStack(spacing: 1) {
                if p != nil {
                    Text(s).font(.system(size: 13, weight: .bold, design: .rounded))
                    if let word { Text(word).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7).opacity(0.75) }
                }
            }
            .foregroundStyle(Self.text(p))
            .frame(width: 54, height: 44)
            .background(Self.fill(p))
            .overlay(Rectangle().stroke(Palette.ink.opacity(p == nil ? 0.15 : 0.6), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if fresh.contains(s) {
                    Text("新").font(.system(size: 9, weight: .black)).foregroundStyle(.white)
                        .padding(.horizontal, 2).background(Palette.red)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(shown || p == nil ? 1 : 0.4)
        .opacity(shown || p == nil ? 1 : 0)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.35, dampingFraction: 0.6).delay(delay), value: shown)
        .accessibilityLabel(p == nil ? "还没有词卡的音节" : "\(s)，\(p!.name)")
    }
}

/// 线装书封面：米白书皮、左边订线、竖排书名签条、右下一方印。
struct BookCover: View {
    let title: String
    let seal: String
    let sealColor: Color
    let dim: Bool

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .topLeading) {
                Rectangle().fill(dim ? Color(hex: 0xD9D9D6) : Color(hex: 0xF4EFE3))
                // 订线
                ForEach(0..<4) { i in
                    Rectangle().fill(Palette.ink.opacity(dim ? 0.25 : 0.55))
                        .frame(width: w * 0.08, height: 1.2)
                        .offset(x: w * 0.04, y: h * (0.15 + 0.23 * Double(i)))
                }
                // 签条
                Text(title.replacingOccurrences(of: "·", with: "\n"))
                    .font(.system(size: max(7, w * 0.15), weight: .black))
                    .foregroundStyle(Palette.ink.opacity(dim ? 0.35 : 0.9))
                    .multilineTextAlignment(.center)
                    .frame(width: w * 0.3, height: h * 0.62)
                    .minimumScaleFactor(0.5)
                    .background(Color.white.opacity(dim ? 0.4 : 1))
                    .overlay(Rectangle().stroke(Palette.ink.opacity(dim ? 0.3 : 0.7), lineWidth: 0.8))
                    .offset(x: w * 0.55, y: h * 0.08)
                // 印
                Text(seal)
                    .font(.system(size: w * 0.17, weight: .black))
                    .foregroundStyle(sealColor)
                    .padding(w * 0.03)
                    .overlay(Rectangle().stroke(sealColor, lineWidth: max(1, w * 0.025)))
                    .rotationEffect(.degrees(-8))
                    .opacity(dim ? 0.6 : 1)
                    .offset(x: w * 0.2, y: h * 0.72)
            }
            .overlay(Rectangle().stroke(Palette.ink.opacity(dim ? 0.4 : 1), lineWidth: max(1.5, w * 0.03)))
        }
    }
}

/// 揭开演出：书从上面落下来，盖印（咚一声），书名和出处浮出，封面向左翻开淡出。点一下跳过。
struct BookUnveil: View {
    let title: String
    let rank: String
    let place: String
    let reduceMotion: Bool
    let stamp: () -> Void
    let done: () -> Void
    @State private var step = 0

    var body: some View {
        ZStack {
            Color.black.opacity(step >= 4 ? 0 : 0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    BookCover(title: title, seal: "", sealColor: .clear, dim: false)
                    Text(rank)
                        .font(.system(size: 22, weight: .black)).foregroundStyle(Palette.red)
                        .padding(4).overlay(Rectangle().stroke(Palette.red, lineWidth: 3))
                        .rotationEffect(.degrees(-8))
                        .scaleEffect(step >= 2 ? 1 : 2.6)
                        .opacity(step >= 2 ? 1 : 0)
                        .offset(x: -16, y: 66)
                }
                .frame(width: 150, height: 204)
                .rotation3DEffect(.degrees(step >= 3 && !reduceMotion ? -88 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.6)
                .offset(y: step >= 1 || reduceMotion ? 0 : -500)
                VStack(spacing: 6) {
                    Text("拿到《\(title)》").font(Fonts.display(28)).foregroundStyle(.white)
                    Text(place).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.8))
                }
                .opacity(step >= 2 && step < 3 ? 1 : 0)
            }
            .opacity(step >= 4 ? 0 : 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .task { await run() }
        .accessibilityIdentifier("bookUnveil")
    }

    func run() async {
        let s = reduceMotion ? 0.35 : 1.0
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { step = 1 }
        try? await Task.sleep(for: .seconds(0.55 * s))
        guard step < 4, !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) { step = 2 }
        stamp()
        try? await Task.sleep(for: .seconds(1.5 * s))
        guard step < 4, !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: 0.45)) { step = 3 }
        try? await Task.sleep(for: .seconds(0.4))
        guard !Task.isCancelled else { return }
        finish()
    }

    func finish() {
        guard step < 4 else { return }
        withAnimation(.easeOut(duration: 0.25)) { step = 4 }
        done()
    }
}

/// 红点「新」。
struct NewDot: View {
    var body: some View {
        Text("新").font(.system(size: 10, weight: .black)).foregroundStyle(.white)
            .frame(width: 18, height: 18).background(Circle().fill(Palette.red))
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
    }
}

/// 一张词卡：词，下面四个点（打对一场亮一个；亮满 fluentAt 个是熟练，全亮是精通）。精通的整张朱红边。
struct CardChip: View {
    let card: PracticeWord
    let level: CardLevel
    let dots: Int
    let fluentAt: Int

    var body: some View {
        VStack(spacing: 3) {
            Text(card.text).font(Fonts.hanzi(16)).lineLimit(1).minimumScaleFactor(0.6)
            HStack(spacing: 3) {
                ForEach(0..<dots, id: \.self) { i in
                    Circle().fill(i < card.cleanDuels ? (i < fluentAt ? Palette.ink : Palette.red) : Color.clear)
                        .overlay(Circle().stroke(Palette.ink.opacity(0.6), lineWidth: 1))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 5)
        .background(Color(hex: 0xFFFBF1))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(level == .master ? Palette.red : Palette.ink.opacity(0.7), lineWidth: level == .master ? 2 : 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(card.text)，\(level.name)")
    }
}
