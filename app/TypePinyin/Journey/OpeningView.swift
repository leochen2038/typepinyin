import SwiftUI

/// 开场白：一句话淡入，停一会儿自动开打，没有按钮。
struct OpeningView: View {
    let line: String
    let onDone: () -> Void
    @State private var shown = false

    var body: some View {
        Text(line)
            .font(Fonts.display(34))
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .opacity(shown ? 1 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.mist)
            .task {
                withAnimation(.easeIn(duration: JourneyFlags.fast ? 0.05 : 0.8)) { shown = true }
                try? await Task.sleep(for: .seconds(JourneyFlags.fast ? 0.2 : 2.2))
                onDone()
            }
            .accessibilityIdentifier("openingLine")
    }
}
