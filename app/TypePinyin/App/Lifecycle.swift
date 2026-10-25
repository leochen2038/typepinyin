import SwiftUI

/// 切到后台或来电时暂停比武；回到前台显示「继续」，点了才继续，不判任何超时。
struct Lifecycle: ViewModifier {
    let c: DuelController
    @Environment(\.scenePhase) private var phase

    func body(content: Content) -> some View {
        content.onChange(of: phase) { _, new in
            if new != .active { c.pauseForBackground() }
        }
    }
}
