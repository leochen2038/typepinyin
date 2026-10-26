import SwiftUI

@main
struct TypePinyinApp: App {
    @State private var controller: DuelController
    @State private var journey: JourneyController

    init() {
        AppResources.registerFonts()
        let c = DuelController(tuning: TuningStore.load())
        _controller = State(initialValue: c)
        _journey = State(initialValue: JourneyController(duel: c))
    }

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-keyboardProbe") {
                KeyboardProbeView()
            } else if controller.tuning.textMode == 3 && (!AppResources.isUITest || ProcessInfo.processInfo.arguments.contains("-fastJourney")) {
                JourneyRoot(j: journey)                 // 旅程（默认）：初入江湖、地区、总地图
                    .preferredColorScheme(.light)
            } else if controller.tuning.textMode == 1 || controller.tuning.textMode == 2 {
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
