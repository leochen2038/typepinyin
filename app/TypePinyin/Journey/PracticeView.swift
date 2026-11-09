import LearningCore
import SwiftUI

/// 练习场：顶栏，下面两个选项。
/// 「词语」：一句说明（有几个打过的词），下面是这一场的卡片，「挑战」或「返回」，要比武；
/// 「文章」：去过的地区里的诗文，点一篇就一句句打，不比武。
struct PracticeView: View {
    @State var j: JourneyController

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { j.screen = .map } label: {
                    Text("回江湖").font(.system(size: 15, weight: .black)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("backToMap")
                Text("练习场").font(Fonts.display(26))
                    .overlay(PanelGesture { j.showPanel = true })
                Spacer()
            }
            .padding(.horizontal, 16).frame(height: 56)
            .background(Palette.mist)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }
            HStack(spacing: 8) {
                tab(0, "词语", "挑你打过的词，比一场")
                tab(1, "文章", "一句句打诗文，不比武")
            }
            .padding(.horizontal, 16).padding(.top, 12)
            if j.practiceTab == 0 { words } else { passages }
        }
        .background(Palette.mist)
        .onAppear {
            guard j.practiceTab == 0, !j.practiceWords.isEmpty else { return }
            j.autoAdvance(after: 2) { jj in jj.startPracticeChallenge() }
        }
    }

    private func tab(_ k: Int, _ title: String, _ note: String) -> some View {
        let on = j.practiceTab == k
        return Button { j.practiceTab = k } label: {
            VStack(spacing: 2) {
                Text(title).font(Fonts.display(20))
                Text(note).font(.system(size: 11, weight: .bold)).opacity(on ? 0.85 : 1)
                    .foregroundStyle(on ? Color.white : Palette.slate)
            }
            .foregroundStyle(on ? Color.white : Palette.ink)
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(on ? Palette.ink : Color.white)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practiceTab-\(k)")
    }

    @ViewBuilder private var words: some View {
        Spacer()
        VStack(spacing: 14) {
            Image(systemName: "figure.martial.arts").font(.system(size: 64, weight: .bold)).foregroundStyle(Palette.ink)
            if j.practiceWords.isEmpty {
                Text("这里还没有词").font(Fonts.display(24))
                Text("在梦里、地区里打过的词，\n都会放进练习场。").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.slate).multilineTextAlignment(.center)
            } else {
                Text("这里有你打过的 \(j.practiceWords.count) 个词").font(Fonts.display(24))
                Text("打得不顺、常打错的会多出几次，\n练熟的少出一些。").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.slate).multilineTextAlignment(.center)
            }
        }
        Spacer()
        if let st = j.practiceStation, !j.practiceWords.isEmpty {
            StationCard(station: st, index: nil, count: 0, last: nil,
                        onGo: { j.startPracticeChallenge() }, onBack: { j.screen = .map })
        }
    }

    @ViewBuilder private var passages: some View {
        let list = j.practicePassages
        if list.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Text("这里还没有诗文").font(Fonts.display(24))
                Text("去过的地区里的诗文，\n都会放进练习场。").font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.slate).multilineTextAlignment(.center)
            }
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(list, id: \.id) { e in
                        Button { j.startPracticeText(e.id) } label: { row(e) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("passage-\(e.id)")
                    }
                }
                .padding(16)
            }
        }
    }

    private func row(_ e: Encounter) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(e.title).font(Fonts.hanzi(18)).foregroundStyle(Palette.ink)
                Text(e.source).font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.slate)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("\(e.text.filter(\.isLetter).count) 字").font(.system(size: 12, weight: .black)).foregroundStyle(Palette.slate).monospacedDigit()
                if let best = TextController.best(of: e.id) {   // 打完过：写最好的速度
                    Text("最好 \(Int(best.rounded())) 字/分").font(.system(size: 12, weight: .black)).foregroundStyle(Palette.red).monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
    }
}
