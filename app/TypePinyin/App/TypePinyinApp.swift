import SwiftUI

@main
struct TypePinyinApp: App {
    @State private var controller: DuelController

    init() {
        AppResources.registerFonts()
        _controller = State(initialValue: DuelController(tuning: TuningStore.load()))
    }

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-keyboardProbe") {
                KeyboardProbeView()
            } else if controller.tuning.textMode != 0 {
                TextScreen(c: controller)               // 试玩：打短句或文章（调参面板「模式」）
                    .preferredColorScheme(.light)
            } else {
                DuelScreen(c: controller)
                    .preferredColorScheme(.light)
                    .statusBarHidden(false)
            }
        }
    }
}
