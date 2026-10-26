import SwiftUI

/// 云雾：拿到《基本功》之前盖住十里坡往上的整张网；拿到后第一次回地图时一起散开。
struct FogLayer: View {
    let clearing: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(Color.white.opacity(0.93))
            ForEach(0..<9, id: \.self) { k in
                Ellipse().fill(Color.white)
                    .frame(width: 220, height: 90)
                    .offset(x: CGFloat((k % 3) - 1) * 130 + (clearing ? CGFloat((k % 3) - 1) * 260 : 0),
                            y: CGFloat(k / 3 - 1) * 150)
            }
            Text("云雾里还看不清").font(Fonts.hanzi(18)).foregroundStyle(Palette.slate2)
        }
        .opacity(clearing ? 0 : 1)
        .allowsHitTesting(!clearing)
        .accessibilityLabel("云雾，还看不清")
    }
}
