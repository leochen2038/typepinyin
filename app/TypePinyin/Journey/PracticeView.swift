import LearningCore
import SwiftUI

/// 练功房：顶栏、一句说明（有几个打过的词），下面是这一场的卡片，「挑战」或「返回」。
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
                Text("练功房").font(Fonts.display(26))
                    .overlay(PanelGesture { j.showPanel = true })
                Spacer()
            }
            .padding(.horizontal, 16).frame(height: 56)
            .background(Palette.mist)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }
            Spacer()
            VStack(spacing: 14) {
                Image(systemName: "figure.martial.arts").font(.system(size: 64, weight: .bold)).foregroundStyle(Palette.ink)
                if j.practiceWords.isEmpty {
                    Text("这里还没有词").font(Fonts.display(24))
                    Text("在梦里、地区里打过的词，\n都会放进练功房。").font(.system(size: 15, weight: .bold))
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
        .background(Palette.mist)
        .onAppear {
            guard !j.practiceWords.isEmpty else { return }
            j.autoAdvance(after: 2) { jj in jj.startPracticeChallenge() }
        }
    }
}
