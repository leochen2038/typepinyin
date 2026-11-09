import SwiftUI

@main
struct TypePinyinApp: App {
    @State private var controller: DuelController
    @State private var journey: JourneyController

    init() {
        AppResources.registerFonts()
        var tuning = TuningStore.load()
        // 开发用：-demoTextMode 2 直接打文章，-demoTextStyle N 换打文字的动效（只这一次启动，不存）
        if UserDefaults.standard.object(forKey: "demoTextMode") != nil { tuning.textMode = UserDefaults.standard.integer(forKey: "demoTextMode") }
        if UserDefaults.standard.object(forKey: "demoTextStyle") != nil { tuning.textStyle = UserDefaults.standard.integer(forKey: "demoTextStyle") }
        let c = DuelController(tuning: tuning)
        _controller = State(initialValue: c)
        _journey = State(initialValue: JourneyController(duel: c))
    }

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-keyboardProbe") {
                KeyboardProbeView()
            } else if ProcessInfo.processInfo.arguments.contains("-scrollPerf") {
                ScrollPerfView(content: AppResources.content)      // 开发用：真机测长卷
            } else if ProcessInfo.processInfo.arguments.contains("-artGallery") {
                ArtGalleryView(content: AppResources.content)      // 开发用：正式美术画廊页
                    .preferredColorScheme(.light)
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
