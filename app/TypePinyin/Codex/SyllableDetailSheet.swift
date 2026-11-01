import LearningCore
import SwiftUI

/// 点开一格：会一个音节，就会了一群字。列出含它的词卡（每张四个点）、现在练到哪、下一步、常用字。
struct SyllableDetailSheet: View {
    @State var j: JourneyController
    let spelling: String

    var body: some View {
        let t = j.learner.tuning
        let cs = j.cards(with: spelling)
        let p = cs.map { $0.level(t) }.max()
        let top = cs.first?.cleanDuels ?? 0
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(spelling).font(Fonts.display(34))
                if let p {
                    Text(p.name).font(.system(size: 14, weight: .black)).foregroundStyle(CodexView.text(p))
                        .padding(.horizontal, 6).padding(.vertical, 2).background(CodexView.fill(p))
                        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
                }
                Spacer()
                Text(Volumes.name(j.content.volume(of: spelling))).font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.slate)
            }
            if cs.isEmpty {
                Text("在江湖里打到含它的词，就收进词卡。").font(.system(size: 16, weight: .semibold))
            } else {
                Text("含 \(spelling) 的词卡").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.slate)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(cs.prefix(8), id: \.text) { c in CardChip(card: c, level: c.level(t), dots: t.masterDuels, fluentAt: t.fluentDuels) }
                }
                // 往前一步的说法，不写「还差」
                if top < t.fluentDuels {
                    Text("下一步：再打对 \(t.fluentDuels - top) 场，就有一张熟练的词卡").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.green)
                } else if top < t.masterDuels {
                    Text("下一步：再打对 \(t.masterDuels - top) 场，就有一张精通的词卡").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.green)
                }
            }
            Text("会了 \(spelling)，就能打出这些常用字：").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.slate)
            Text(String(j.content.commonChars(of: spelling).prefix(30)))
                .font(Fonts.hanzi(26)).lineSpacing(4)
            Spacer()
        }
        .padding(20)
    }
}
