import SwiftUI

/// 开场白：一句话淡入，玩家点按钮才开始（跳过动画、自动演示时直接往下走）。
struct OpeningView: View {
    let line: String
    var button: String = "开始"
    let onDone: () -> Void
    @State private var shown = false

    var body: some View {
        VStack(spacing: 36) {
            Text(line)
                .font(Fonts.display(34))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .accessibilityIdentifier("openingLine")
            Button(action: onDone) {
                Text(button).font(Fonts.display(26)).padding(.horizontal, 44).padding(.vertical, 12)
                    .background(Palette.gold).foregroundStyle(Palette.ink)
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                    .compositingGroup().shadow(color: Palette.ink, radius: 0, x: 3, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openingStart")
        }
            .opacity(shown ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.mist)
            .task {
                withAnimation(.easeIn(duration: JourneyFlags.fast ? 0.05 : 0.8)) { shown = true }
                // 跳过动画或自动演示：不等按钮
                if JourneyFlags.fast || ProcessInfo.processInfo.arguments.contains("-autoplay") {
                    try? await Task.sleep(for: .seconds(JourneyFlags.fast ? 0.2 : 2.2))
                    onDone()
                }
            }
    }
}
