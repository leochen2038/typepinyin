import LearningCore
import SwiftUI

/// 秘籍页：顶上一排选项卡，一本秘籍一个（上下卷在同一页里上下排），每卷一张「声母 × 韵母」的音节表，
/// 颜色表示熟练度；没学会的显示成「未解锁的招式」。总进度在选项卡上面（只有这一页出现分母）。
/// 点开一格看这个音节对应的常用字和下一步。
struct CodexView: View {
    @State var j: JourneyController
    @State private var picked: String?
    @State private var book: String?

    /// 七本秘籍，按卷的顺序。
    static let books: [String] = Volumes.all.map(Volumes.book).reduce(into: []) { if !$0.contains($1) { $0.append($1) } }

    func volumes(of b: String) -> [String] { Volumes.all.filter { Volumes.book($0) == b } }

    /// 默认打开：正在挑战的地区那本，否则最近拿到的那本，否则基本功。
    var defaultBook: String {
        if let r = j.content.regions.first(where: { j.progress.regions[$0.id]?.phase == .inProgress }) { return Volumes.book(r.volume) }
        if let v = Volumes.all.last(where: { j.progress.volumes[$0]?.obtained == true }) { return Volumes.book(v) }
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
                Text("已学会 \(j.learner.learnedCount) / \(j.content.syllables.count) 个音节，能打出 \(j.typedCommonChars.formatted()) 个常用字")
                    .font(.system(size: 15, weight: .black))
                tabs
            }
            .padding(.horizontal, 16).padding(.top, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    legend
                    ForEach(volumes(of: book ?? defaultBook), id: \.self) { v in volumeBlock(v) }
                }
                .padding(16)
            }
            .id(book ?? defaultBook)
        }
        .background(Palette.mist)
        .sheet(item: Binding(get: { picked.map(Picked.init) }, set: { picked = $0?.id })) { p in
            SyllableDetailSheet(j: j, spelling: p.id).presentationDetents([.medium])
        }
    }

    struct Picked: Identifiable { let id: String }

    /// 选项卡：书名，下面一行是重数（有上下卷的取高的那卷）或「还没拿到」。
    var tabs: some View {
        let current = book ?? defaultBook
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Self.books, id: \.self) { b in
                        let rank = volumes(of: b).map { j.rank(of: $0) }.max() ?? 0
                        let on = b == current
                        Button { book = b } label: {
                            VStack(spacing: 1) {
                                Text(b).font(.system(size: 15, weight: .black))
                                Text(rank == 0 ? "还没拿到" : "第\(["", "一", "二", "三", "四", "五"][rank])重")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(on ? Palette.ink : (rank == 0 ? Palette.slate2 : Palette.red))
                            }
                            .foregroundStyle(rank == 0 && !on ? Palette.slate : Palette.ink)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(on ? Palette.gold : Color.white)
                            .overlay(Rectangle().stroke(Palette.ink, lineWidth: on ? 3 : 1.5))
                        }
                        .buttonStyle(.plain)
                        .id(b)
                        .accessibilityIdentifier("book-\(b)")
                    }
                }
                .padding(.vertical, 3).padding(.horizontal, 2)
            }
            .onAppear { proxy.scrollTo(current, anchor: .center) }
        }
    }

    var legend: some View {
        HStack(spacing: 12) {
            ForEach(Proficiency.allCases, id: \.self) { p in
                HStack(spacing: 4) {
                    Rectangle().fill(Self.fill(p)).frame(width: 14, height: 14).overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
                    Text(Self.name(p)).font(.system(size: 13, weight: .bold))
                }
            }
        }
    }

    static func name(_ p: Proficiency) -> String {
        switch p { case .locked: "未解锁"; case .met: "拆过"; case .fluent: "熟练"; case .master: "精通" }
    }

    static func fill(_ p: Proficiency) -> Color {
        switch p {
        case .locked: Color.white
        case .met: Color(hex: 0xFFE9A8)
        case .fluent: Palette.gold
        case .master: Palette.red
        }
    }

    func volumeBlock(_ v: String) -> some View {
        let syl = j.content.syllables(in: v)
        let rank = j.rank(of: v)
        let inits = Array(Set(syl.map { $0.parts.initial })).sorted { order($0) < order($1) }
        let finals = Array(Set(syl.map { $0.parts.medial + $0.parts.final })).sorted()
        let table = Dictionary(syl.map { ($0.parts.initial + "|" + $0.parts.medial + $0.parts.final, $0.spelling) }, uniquingKeysWith: { a, _ in a })
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Volumes.name(v)).font(Fonts.display(22))
                Text(rank == 0 ? "还没拿到" : "第\(["", "一", "二", "三", "四", "五"][rank])重")
                    .font(.system(size: 12, weight: .black)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(rank == 0 ? Palette.slate2 : Palette.red)
                Spacer()
            }
            Text(rankLine(v, rank: rank)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.slate)
            ScrollView(.horizontal, showsIndicators: false) {
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    GridRow {
                        Color.clear.frame(width: 26, height: 18)
                        ForEach(finals, id: \.self) { fin in
                            Text(fin).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate2).frame(width: 50)
                        }
                    }
                    ForEach(inits, id: \.self) { ini in
                        GridRow {
                            Text(ini.isEmpty ? "–" : ini).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate2).frame(width: 26)
                            ForEach(finals, id: \.self) { fin in
                                if let s = table[ini + "|" + fin] { cell(s) } else { Color.clear.frame(width: 50, height: 30) }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
    }

    func order(_ ini: String) -> Int { (["", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "zh", "ch", "sh", "r", "z", "c", "s", "y", "w"].firstIndex(of: ini) ?? 99) }

    /// 这一重和下一重爆字母的样子（主题粒子、几片、往上冲）。
    func rankLine(_ v: String, rank: Int) -> String {
        let theme = RankFx.theme(v).name
        let pieces = [9, 6, 12, 20, 20, 28]
        let now = rank == 0 ? "现在：默认彩纸" : "现在：\(theme) \(pieces[rank]) 片\(rank >= 4 ? "，往上冲" : "")"
        guard rank < 5 else { return now }
        let next = rank + 1
        return now + "　下一重：\(theme) \(pieces[next]) 片\(next >= 4 ? "，往上冲" : "")"
    }

    func cell(_ s: String) -> some View {
        let p = j.learner.proficiency(s)
        return Button { picked = s } label: {
            Text(p == .locked ? "?" : s)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(p == .master ? .white : Palette.ink.opacity(p == .locked ? 0.35 : 1))
                .frame(width: 50, height: 30)
                .background(Self.fill(p))
                .overlay(Rectangle().stroke(Palette.ink.opacity(0.6), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(p == .locked ? "未解锁的招式" : "\(s)，\(Self.name(p))")
    }
}
