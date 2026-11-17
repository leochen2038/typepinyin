import LearningCore
import SwiftUI

/// 秘籍页（按经验升级时用）：第一层是书架，十本秘籍按岛的顺序排，一座岛一本；点开一本是第二层。
/// 书架上每本写：名字（用岛名叫）、练什么、打过几个音节、几张词卡、几级和经验条；打赢过掌门的封面上盖印。
/// 没拿到的缩成一行灰条。只写已有的，不写总数、不写还差多少。
struct BookShelfView: View {
    @State var j: JourneyController
    /// 开发用：-codexBook base 直接打开这一本。
    @State private var open: String? = {
        let a = ProcessInfo.processInfo.arguments
        return a.firstIndex(of: "-codexBook").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button { if open != nil { open = nil } else { j.screen = .map } } label: {
                    Text(open == nil ? "回江湖" : "书架").font(.system(size: 15, weight: .black)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("codexBack")
                Text(open.map(j.bookName) ?? "秘籍").font(Fonts.display(26))
                    .overlay(PanelGesture { j.showPanel = true })
                Spacer()
            }
            .padding(.horizontal, 16).frame(height: 56)
            .background(Palette.mist)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }
            if let v = open {
                BookDetailView(j: j, volume: v).id(v)
            } else {
                shelf
            }
        }
        .background(Palette.mist)
        .onAppear { j.markCodexSeen(books: j.booksToUnveil) }
    }

    private var shelf: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                GainsPanel(j: j).padding(.bottom, 6)
                ForEach(j.content.regions.filter(\.playable), id: \.id) { r in
                    if j.progress.volumes[r.volume]?.obtained == true {
                        Button { open = r.volume } label: { row(r) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("book-\(r.volume)")
                    } else {
                        lockedRow(r)
                    }
                }
            }
            .padding(16)
        }
    }

    private func row(_ r: Region) -> some View {
        let v = r.volume
        let recent = j.progress.journey.lastRegion == r.id && !j.cleared(r.id)
        return HStack(spacing: 12) {
            BookCover(title: "", seal: j.cleared(r.id) ? String(r.name.prefix(1)) : "", sealColor: Palette.red, dim: false, volume: v)
                .frame(width: 38, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(j.bookName(v)).font(.system(size: 16, weight: .black))
                    Text("练 \(r.hint)").font(.system(size: 11, weight: .bold)).foregroundStyle(recent ? Palette.red : Palette.slate)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Text("打过 \(j.typedSyllables(in: v)) 个音节 · \(j.cardCount(in: v)) 张词卡")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.slate).monospacedDigit()
                XPBar(progress: j.bookProgress(v), height: 8)
            }
            Text(j.levelText(j.rank(of: v))).font(Fonts.display(22))
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color.white)
        .overlay(Rectangle().stroke(recent ? Palette.red : Palette.ink, lineWidth: recent ? 2.5 : 2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(j.bookName(v))，\(j.levelText(j.rank(of: v)))\(j.cleared(r.id) ? "，掌门盖过印" : "")")
    }

    private func lockedRow(_ r: Region) -> some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color(hex: 0xD9D9D6)).frame(width: 22, height: 30)
                .overlay(Rectangle().stroke(Palette.slate2, lineWidth: 2)).padding(.horizontal, 8)
            Text(r.name + "秘籍").font(.system(size: 15, weight: .black)).foregroundStyle(Palette.slate2)
            Spacer()
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.white.opacity(0.6))
        .overlay(Rectangle().stroke(Palette.faint, lineWidth: 1.5))
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
                Rectangle().fill(Palette.red).frame(width: g.size.width * min(1, max(0, progress)))
            }
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
        }
        .frame(height: height)
    }
}

/// 一本秘籍：封面、等级和经验条；「试看」一行（练到的等级能点，没练到的是灰的，点了只提示）；下面分「音节」「词卡」两栏，先看音节。
struct BookDetailView: View {
    @State var j: JourneyController
    let volume: String
    @State private var tab = 0
    @State private var shown: Int
    @State private var note: String?
    @State private var demo = DemoRun(id: 0, at: Date.distantFuture.timeIntervalSinceReferenceDate)
    @State private var picked: String?
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
            VStack(alignment: .leading, spacing: 10) {
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
                XPBar(progress: j.bookProgress(volume))
                Text("打这本秘籍的牌就涨经验，打得干净、打得快涨得多")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
    }

    // MARK: 试看

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
                Text("试看").font(Fonts.display(18))
                Text(note ?? "\(shown) 级\(shown == rank ? "，现在用的" : "")：打中时爆 \(pieces[shown]) 片\(theme)")
                    .font(.system(size: 12, weight: note == nil ? .semibold : .black))
                    .foregroundStyle(note == nil ? Palette.slate : Palette.ink)
            }
            HStack(spacing: 6) {
                ForEach(1...BookXP.maxLevel, id: \.self) { n in
                    let owned = n <= rank, on = n == shown
                    Button { tapLevel(n) } label: {
                        Text("\(n) 级").font(.system(size: 14, weight: .black))
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .foregroundStyle(on ? Color.white : owned ? Palette.ink : Palette.slate2)
                            .background(on ? Palette.ink : owned ? Color.white : Palette.mist)
                            .overlay(Rectangle().stroke(owned ? Palette.ink : Palette.faint, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(owned ? "试看 \(n) 级" : "\(n) 级，还没练到")
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
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
        .zIndex(1)
        .onAppear { play() }
    }

    private func tapLevel(_ n: Int) {
        guard n <= rank else {                                // 没练到的：不播放，只说一句
            note = "练到 \(n) 级就能看"
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.8))
                note = nil
            }
            return
        }
        note = nil
        shown = n
        play()
    }

    private func play() {
        guard !reduceMotion else { return }
        demo = DemoRun(id: demo.id + 1, at: Date().timeIntervalSinceReferenceDate + 0.25)
        j.duel.sounds.hitHaptic(heavy: false)
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
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
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
