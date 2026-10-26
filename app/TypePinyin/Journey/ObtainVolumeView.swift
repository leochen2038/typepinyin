import LearningCore
import SwiftUI

/// 「拿到秘籍」演出：书卷展开，卷名，这一卷到了第几重。
struct ObtainVolumeView: View {
    let volume: String
    let rank: Int
    let onDone: () -> Void
    @State private var open = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("拿到秘籍").font(.system(size: 18, weight: .black)).foregroundStyle(Palette.gold)
                Text("《\(Volumes.name(volume))》").font(Fonts.display(40)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 26).padding(.vertical, 14)
                    .background(Color(hex: 0xF7EBCF))
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                    .scaleEffect(x: open ? 1 : 0.1, y: 1)
                Text("第\(["", "一", "二", "三", "四", "五"][max(1, min(5, rank))])重").font(Fonts.display(26)).foregroundStyle(.white)
                Button(action: onDone) {
                    Text("收下").font(Fonts.display(22)).padding(.horizontal, 36).padding(.vertical, 10)
                        .background(Palette.gold).foregroundStyle(Palette.ink)
                        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("obtainDone")
            }
        }
        .onAppear { withAnimation(.spring(duration: JourneyFlags.fast ? 0.05 : 0.6, bounce: 0.3)) { open = true } }
    }
}
