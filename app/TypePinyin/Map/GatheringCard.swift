import SwiftUI

/// 点武林大会弹的小卡片：集齐十卷写「还在筹备」，没集齐写集齐就能参加。样式同地区简介卡。
struct GatheringCard: View {
    let all: Bool
    let onClose: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("武林大会").font(Fonts.display(30))
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink) }
                        .buttonStyle(.plain).accessibilityLabel("关上")
                }
                Text(all ? "十卷集齐了。武林大会还在筹备，过些日子开张。" : "集齐十卷就能参加武林大会。")
                    .font(.system(size: 16)).foregroundStyle(Palette.ink)
                    .accessibilityIdentifier("gatheringText")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            .compositingGroup()
            .shadow(color: Palette.ink, radius: 0, x: 5, y: 5)
            .padding(.horizontal, 12).padding(.bottom, 16)
        }
    }
}
