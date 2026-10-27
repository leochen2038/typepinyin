import LearningCore
import SwiftUI

/// 秘籍页：按秘籍和上下卷分组，每卷一张「声母 × 韵母」的音节表，颜色表示熟练度；没学会的显示成「未解锁的招式」。
/// 顶部是收集进度（只有这一页出现分母）。点开一格看这个音节对应的常用字和下一步。
struct CodexView: View {
    @State var j: JourneyController
    @State private var picked: String?

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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("已学会 \(j.learner.learnedCount) / \(j.content.syllables.count) 个音节，能打出 \(j.learner.typableCommonChars(j.content).formatted()) 个常用字")
                        .font(.system(size: 16, weight: .black))
                    legend
                    ForEach(Volumes.all, id: \.self) { v in volumeBlock(v) }
                }
                .padding(16)
            }
        }
        .background(Palette.mist)
        .sheet(item: Binding(get: { picked.map(Picked.init) }, set: { picked = $0?.id })) { p in
            SyllableDetailSheet(j: j, spelling: p.id).presentationDetents([.medium])
        }
    }

    struct Picked: Identifiable { let id: String }

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
