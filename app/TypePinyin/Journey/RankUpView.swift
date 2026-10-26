import LearningCore
import SwiftUI

/// 升重演出：「《基本功》练到第二重」，五个重数格子亮到这一重，告诉玩家回顾时爆开的字母更华丽了。
struct RankUpView: View {
    let volume: String
    let rank: Int
    let onDone: () -> Void
    @State private var lit = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("《\(Volumes.name(volume))》练到第\(["", "一", "二", "三", "四", "五"][max(1, min(5, rank))])重")
                    .font(Fonts.display(32)).foregroundStyle(.white).multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { k in
                        Rectangle().fill(k <= lit ? Palette.red : Color.white.opacity(0.25))
                            .frame(width: 34, height: 12)
                            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                    }
                }
                Text("回顾时爆开的字母更多了").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.gold)
                Button(action: onDone) {
                    Text("好").font(Fonts.display(22)).padding(.horizontal, 40).padding(.vertical, 10)
                        .background(Palette.gold).foregroundStyle(Palette.ink)
                        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
        .task {
            for k in 1...max(1, rank) {
                try? await Task.sleep(for: .seconds(JourneyFlags.fast ? 0.02 : 0.25))
                withAnimation(.spring(duration: 0.25)) { lit = k }
            }
        }
    }
}
