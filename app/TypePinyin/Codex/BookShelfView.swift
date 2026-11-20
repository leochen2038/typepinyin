import LearningCore
import SwiftUI

/// 收获页（按经验升级时用）：顶上四格数字，下面「日历」「勋章」两张卡片，再下面是书架。
/// 书架上十本秘籍按岛的顺序排，一座岛一本；点开一本是第二层（左上角「书架」回来），点日历、勋章卡片也是第二层（左上角「收获」回来）。
/// 书架上每本写：名字（用岛名叫）、练什么、打过几个音节、几张词卡、几级和经验条；打赢过掌门的封面上盖印。
/// 没拿到的缩成一行灰条。只写已有的，不写总数、不写还差多少。
struct BookShelfView: View {
    @State var j: JourneyController
    /// 开发用：-codexBook base 直接打开这一本。
    @State private var open: String? = {
        let a = ProcessInfo.processInfo.arguments
        return a.firstIndex(of: "-codexBook").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
    }()
    /// 日历页、勋章页（从收获页顶上两张卡片进）。开发用：-harvestPage calendar / badges 直接打开。
    enum Sub { case calendar, badges }
    @State private var sub: Sub? = {
        let a = ProcessInfo.processInfo.arguments
        switch a.firstIndex(of: "-harvestPage").flatMap({ $0 + 1 < a.count ? a[$0 + 1] : nil }) {
        case "calendar": return .calendar
        case "badges": return .badges
        default: return nil
        }
    }()
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    if open != nil { open = nil } else if sub != nil { sub = nil } else { j.screen = .map }
                } label: {
                    Text(open != nil ? "书架" : sub != nil ? "收获" : "回江湖").font(.system(size: 15, weight: .black)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                }
                .buttonStyle(.popSmall)
                .accessibilityIdentifier("codexBack")
                Text(open.map(j.bookName) ?? (sub == .calendar ? "日历" : sub == .badges ? "勋章" : "收获")).font(Fonts.display(26))
                    .overlay(PanelGesture { j.showPanel = true })
                Spacer()
            }
            .padding(.horizontal, 16).frame(height: 56)
            .background(Palette.mist)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }
            if let v = open {
                BookDetailView(j: j, volume: v).id(v)
            } else if sub == .calendar {
                CalendarPage(j: j)
            } else if sub == .badges {
                BadgeBookView(j: j)
            } else {
                shelf
            }
        }
        .background(SkyPage())
        .onAppear {
            j.markCodexSeen(books: j.booksToUnveil)
            if let p = j.openHarvestPage {
                sub = p == "badges" ? .badges : .calendar
                j.openHarvestPage = nil
            }
        }
    }

    /// 刚点的那本：轻点太快时系统来不及显示按住，抬手后补一下沉到底（0.06 秒），再弹上来的同时翻开。
    @State private var tapped: String?

    private func release(_ v: String) {
        tapped = v
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.06))
            tapped = nil
            open = v
        }
    }

    private var shelf: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                GainsPanel(j: j).padding(.bottom, 4)
                entryCards.padding(.bottom, 4)
                shelfTitle
                ForEach(j.content.regions.filter(\.playable), id: \.id) { r in
                    if j.progress.volumes[r.volume]?.obtained == true {
                        // 系统按钮（滚动、取消都由系统管，滑动后第一下就能点）+ 自己的按下样式（不变灰）：
                        // 按住时沉下去；轻点太快系统来不及显示按住的，抬手后补一下沉到底再翻开
                        Button { release(r.volume) } label: { row(r) }
                            .buttonStyle(ShelfPress(forced: tapped == r.volume))
                            .padding(.trailing, 4).padding(.bottom, 4)
                            .accessibilityIdentifier("book-\(r.volume)")
                    } else {
                        lockedRow(r)
                    }
                }
            }
            .padding(16)
        }
    }

    /// 收获页顶上两张卡片：左「日历」、右「勋章」（各有开关，关掉的不出）。能点，所以有投影、按下去会沉。
    /// 放大字体时压成一行，不画七格和勋章图。
    @ViewBuilder private var entryCards: some View {
        let compact = typeSize >= .xxLarge
        if j.calendarOn || j.badgesOn {
            HStack(alignment: .top, spacing: 12) {
                if j.calendarOn {
                    Button { sub = .calendar } label: {
                        if compact {
                            let w = j.practicedThisWeek, total = j.practicedDays.count
                            CompactHarvestCard(title: "日历", line: w > 0 ? "本周 \(w) 天" : total > 0 ? "共 \(total) 天" : "打完一场就盖印")
                        } else {
                            CalendarCard(j: j)
                        }
                    }
                    .buttonStyle(ShelfPress())
                    .accessibilityIdentifier("calendarCard")
                }
                if j.badgesOn {
                    Button { sub = .badges } label: {
                        if compact {
                            CompactHarvestCard(title: "勋章", line: "\(j.progress.badges.count) 枚", dot: j.hasNewBadges)
                        } else {
                            BadgeCard(j: j)
                        }
                    }
                    .buttonStyle(ShelfPress())
                    .accessibilityIdentifier("badgeCard")
                }
            }
            .padding(.trailing, 4)
        }
    }

    /// 书架标题：「书架」+ 拿到几本、盖了几个掌门印（只写已有的）。
    private var shelfTitle: some View {
        let regions = j.content.regions.filter(\.playable)
        let got = regions.filter { j.progress.volumes[$0.volume]?.obtained == true }.count
        let sealed = regions.filter { j.cleared($0.id) }.count
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("书架").font(Fonts.display(22))
            Text("\(got) 本秘籍\(sealed > 0 ? " · \(sealed) 个掌门印" : "")").font(.system(size: 12, weight: .black)).foregroundStyle(Palette.slate)
            Spacer()
        }
        .padding(.top, 2)
    }

    /// 书架上的一本（2026-11-18 改版）：白卡片、粗黑边；投影和按下去由按钮样式给（能点的才有投影）；
    /// 左边一条这本书封面的颜色，封面放大、盖着掌门印；名字用标题字，经验条是比武里那种斜条；
    /// 等级是右边一块封面色的方牌（数字大、「级」小）。
    private func row(_ r: Region) -> some View {
        let v = r.volume
        let color = BookCover.colors(v).cover
        let rank = j.rank(of: v)
        return HStack(spacing: 12) {
            BookCover(title: "", seal: j.cleared(r.id) ? String(r.name.prefix(1)) : "", sealColor: Palette.red, dim: false, volume: v)
                .frame(width: 46, height: 63)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(j.bookName(v)).font(Fonts.display(21)).lineLimit(1)
                    Text(r.hint).font(.system(size: 11, weight: .black)).foregroundStyle(Palette.slate)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Text("打过 \(j.typedSyllables(in: v)) 个音节 · \(j.cardCount(in: v)) 张词卡")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.slate).monospacedDigit()
                SkewBar(value: j.bookProgress(v), color: Palette.xp, height: 9, skew: -0.25, border: 2)
                    .padding(.trailing, 4)
            }
            VStack(spacing: -2) {
                Text("\(max(1, rank))").font(Fonts.display(30)).foregroundStyle(.white)
                Text("级").font(.system(size: 11, weight: .black)).foregroundStyle(.white.opacity(0.9))
            }
            .frame(width: 48, height: 56)
            .background(color)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2.5))
            .rotationEffect(.degrees(-3))
        }
        .padding(.leading, 18).padding(.trailing, 12).padding(.vertical, 10)
        .background(alignment: .leading) {
            ZStack(alignment: .leading) {
                Color.white
                Rectangle().fill(color).frame(width: 8)
            }
        }
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(j.bookName(v))，\(j.levelText(j.rank(of: v)))\(j.cleared(r.id) ? "，掌门盖过印" : "")")
    }

    /// 还没拿到的：虚线框、灰色书脊，不占地方。
    private func lockedRow(_ r: Region) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color(hex: 0xD9D9D6)).frame(width: 22, height: 30)
                .overlay(Rectangle().stroke(Palette.slate2, lineWidth: 2)).padding(.horizontal, 12)
            Text(r.name + "秘籍").font(Fonts.display(17)).foregroundStyle(Palette.slate2)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.white.opacity(0.45))
        .overlay(Rectangle().stroke(Palette.slate2.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])))
        .padding(.trailing, 4)
        .accessibilityIdentifier("locked-\(r.volume)")
    }
}

/// 经验条：红色是这一级走了多少。
struct XPBar: View {
    let progress: Double
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(Palette.mist2)
                Rectangle().fill(Palette.xp).frame(width: g.size.width * min(1, max(0, progress)))
            }
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
        }
        .frame(height: height)
    }
}

/// 一本秘籍：封面、等级和经验条；「各级效果」一行（1–5 级都能点着看，2026-11-20 放开等级限制）；下面分「音节」「词卡」两栏，先看音节。
struct BookDetailView: View {
    @State var j: JourneyController
    let volume: String
    @State private var tab = 0
    @State private var shown: Int
    @State private var demo = DemoRun(id: 0, at: Date.distantFuture.timeIntervalSinceReferenceDate)
    @State private var picked: String?
    /// 各级效果的声音（换一级或离开时取消，免得两串声音叠在一起）。
    @State private var soundJob: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct DemoRun: Equatable { var id: Int; var at: Double }
    struct Picked: Identifiable { let id: String }

    init(j: JourneyController, volume: String) {
        _j = State(initialValue: j)
        self.volume = volume
        _shown = State(initialValue: max(1, j.rank(of: volume)))
    }

    var region: Region? { j.region(giving: volume) }
    var rank: Int { max(1, j.rank(of: volume)) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                preview
                HStack(spacing: 6) {
                    tabButton("音节 \(j.typedSyllables(in: volume))", 0)
                    tabButton("词卡 \(j.cardCount(in: volume))", 1)
                    Spacer()
                }
                if tab == 0 { syllables } else { cards }
            }
            .padding(16)
        }
        .sheet(item: Binding(get: { picked.map(Picked.init) }, set: { picked = $0?.id })) { p in
            SyllableDetailSheet(j: j, spelling: p.id).presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            BookCover(title: region?.name ?? "", seal: region.map { j.cleared($0.id) ? String($0.name.prefix(1)) : "" } ?? "",
                      sealColor: Palette.red, dim: false, volume: volume)
                .frame(width: 60, height: 82)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(j.levelText(rank)).font(Fonts.display(30))
                    Text("练 \(j.bookFocus(volume))").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.slate)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                SkewBar(value: j.bookProgress(volume), color: Palette.xp, height: 11, skew: -0.25, border: 2).padding(.trailing, 4)
                Text("打这本秘籍的牌就涨经验，打得干净、打得快涨得多")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12).padding(.top, 6)
        .background(alignment: .top) {
            ZStack(alignment: .top) { Color.white; Rectangle().fill(BookCover.colors(volume).cover).frame(height: 8) }
        }
        .popPanel()
    }

    // MARK: 各级效果

    /// 示范词牌上的词：岛名（拼音在内容里有）。
    private var demoCard: DuelController.CardVM {
        let name = region?.name ?? "江湖"
        let syl = (region?.pinyin ?? "jiang hu").split(separator: " ").map(String.init)
        return DuelController.CardVM(id: 0, text: name, syllables: syl, typed: syl.joined(), weight: "", volumeLabel: "",
                                     store: 1, flaw: false, finisher: false, locked: true, inactive: false)
    }

    private var preview: some View {
        let pieces = [0, 9, 16, 24, 30, 36]
        let theme = RankFx.theme(volume).name
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("各级效果").font(Fonts.display(18))
                Text("\(shown) 级\(shown == rank ? "（当前）" : "")：打中时爆 \(pieces[shown]) 片\(theme)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.slate)
            }
            HStack(spacing: 6) {
                ForEach(1...BookXP.maxLevel, id: \.self) { n in
                    let on = n == shown
                    Button { tapLevel(n) } label: {
                        Text("\(n) 级").font(.system(size: 14, weight: .black))
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .foregroundStyle(on ? Color.white : Palette.ink)
                            .background(on ? Palette.ink : Color.white)
                            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("看 \(n) 级的效果\(n == rank ? "，当前等级" : "")")
                    .accessibilityIdentifier("previewLevel-\(n)")
                }
            }
            GeometryReader { g in
                let card = demoCard
                let n = card.syllables.joined().count
                let at = demo.at
                let review: DuelController.Review = {
                    var r = DuelController.Review(id: demo.id, slot: 0, card: card, intro: card)
                    r.phase = 1
                    r.popAt = (0..<n).map { at + Double($0) * 0.09 }
                    return r
                }()
                ReviewCard(review: review, card: CGSize(width: g.size.width - 20, height: 80), rank: shown, theme: volume, nudges: false)
                    .position(x: g.size.width / 2, y: 44)
                    .id(demo.id)
            }
            .frame(height: 88)
            .allowsHitTesting(false)
        }
        .padding(12)
        .background(Color.white)
        .popPanel()
        .zIndex(1)
        .onAppear { play() }
        .onDisappear { soundJob?.cancel() }
    }

    private func tapLevel(_ n: Int) {
        shown = n
        play()
    }

    /// 播一遍：字母一个个爆开时一个字母一声「嗒」（音调一个比一个高，和结算页经验条同一套），爆完收一声：1–3 级轻击、4–5 级重击。
    private func play() {
        guard !reduceMotion else { return }
        let start = Date().timeIntervalSinceReferenceDate + 0.25
        demo = DemoRun(id: demo.id + 1, at: start)
        j.duel.sounds.hitHaptic(heavy: false)
        soundJob?.cancel()
        let letters = demoCard.syllables.joined().count, level = shown
        soundJob = Task { @MainActor in
            for i in 0..<letters {
                let wait = start + Double(i) * 0.09 - Date().timeIntervalSinceReferenceDate
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                if Task.isCancelled { return }
                j.duel.sounds.tick(min(i, 6))
            }
            try? await Task.sleep(for: .seconds(0.12))
            if Task.isCancelled { return }
            j.duel.sounds.play(level >= 4 ? .hitHeavy : .hitLight)
            j.duel.sounds.hitHaptic(heavy: level >= 4)
        }
    }

    private func tabButton(_ label: String, _ k: Int) -> some View {
        Button { tab = k } label: {
            Text(label).font(.system(size: 15, weight: .black)).monospacedDigit()
                .foregroundStyle(tab == k ? Color.white : Palette.ink)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(tab == k ? Palette.ink : Color.white)
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bookTab-\(k)")
    }

    // MARK: 音节

    private static let initialOrder = ["", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "zh", "ch", "sh", "r", "z", "c", "s", "y", "w"]

    /// 音节表：声母一行、韵母一列。打过的（有词卡含它）是藏青底，写拼法和一张词卡；没打过的留白。
    private var syllables: some View {
        let syl = j.content.syllables(in: volume)
        let inits = Array(Set(syl.map { $0.parts.initial })).sorted { (Self.initialOrder.firstIndex(of: $0) ?? 99) < (Self.initialOrder.firstIndex(of: $1) ?? 99) }
        let finals = Array(Set(syl.map { $0.parts.medial + $0.parts.final })).sorted()
        let table = Dictionary(syl.map { ($0.parts.initial + "|" + $0.parts.medial + $0.parts.final, $0.spelling) }, uniquingKeysWith: { a, _ in a })
        let best = j.cardBest
        let cw = CodexView.cellWidth(columns: finals.count)
        return ScrollView(.horizontal, showsIndicators: false) {
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                GridRow {
                    Color.clear.frame(width: 26, height: 18)
                    ForEach(finals, id: \.self) { fin in
                        Text(fin).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate).frame(width: cw)
                    }
                }
                ForEach(inits, id: \.self) { ini in
                    GridRow {
                        Text(ini.isEmpty ? "–" : ini).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate).frame(width: 26)
                        ForEach(finals, id: \.self) { fin in
                            if let s = table[ini + "|" + fin] {
                                cell(s, typed: best[s] != nil, width: cw)
                            } else {
                                Color.clear.frame(width: cw, height: 44)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white)
        .popPanel()
    }

    private func cell(_ s: String, typed: Bool, width: CGFloat) -> some View {
        Button { if typed { picked = s } } label: {
            VStack(spacing: 1) {
                if typed {
                    Text(s).font(.system(size: 13, weight: .bold, design: .rounded))
                    if let w = j.typedWords(with: s).first {
                        Text(w).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            .foregroundStyle(.white)
            .frame(width: width, height: 44)
            .background(typed ? Palette.navy : Color(hex: 0xF6F3EC))
            .overlay(Rectangle().stroke(Palette.ink.opacity(typed ? 0.6 : 0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(typed ? "\(s)，打过" : "还没打过的音节")
    }

    // MARK: 词卡

    @ViewBuilder private var cards: some View {
        let cs = j.ownedCards(in: volume)
        if cs.isEmpty {
            Text("比武里打完一张牌，就收进词卡。").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.slate)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(cs, id: \.text) { c in
                    Text(c.text).font(Fonts.hanzi(16)).lineLimit(1).minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color(hex: 0xFFFBF1))
                        .overlay(Rectangle().stroke(Palette.ink.opacity(0.7), lineWidth: 1))
                }
            }
        }
    }
}

extension JourneyController {
    /// 这本秘籍里打过的音节有几个（有词卡含它）。
    func typedSyllables(in volume: String) -> Int {
        let best = cardBest
        return content.syllables(in: volume).filter { best[$0.spelling] != nil }.count
    }

    /// 归这本秘籍的词卡（一个词只归一关），最近打过的在前。
    func ownedCards(in volume: String) -> [PracticeWord] {
        cards.filter { content.owner(of: $0.syllables) == volume }.sorted { $0.lastSeen > $1.lastSeen }
    }
}

extension View {
    /// 秘籍页的面板：粗黑边，不加投影（投影只给能点的按钮，2026-11-19）。
    func popPanel() -> some View {
        overlay(Rectangle().stroke(Palette.ink, lineWidth: 2.5))
    }
}


/// 书架上一本秘籍的按下样式：按住（或抬手后补的那一下）往右下沉、盖住投影，松开弹回；按下时轻震。不变灰。
struct ShelfPress: ButtonStyle {
    var forced = false

    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed || forced
        configuration.label
            .offset(x: down ? 4 : 0, y: down ? 4 : 0)
            .background(Rectangle().fill(Palette.ink).offset(x: 4, y: 4))
            .animation(.spring(duration: down ? 0.05 : 0.18, bounce: down ? 0 : 0.5), value: down)
            .sensoryFeedback(.impact(weight: .light), trigger: down) { _, new in new }
    }
}
