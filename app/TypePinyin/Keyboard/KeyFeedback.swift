import UIKit

/// 按键声和按键震动。按键声用系统提供的键盘音（跟随用户在设置里的「键盘按键声」开关），
/// 只有在自定义键盘作为输入视图显示时才会响，所以键盘挂在隐藏焦点视图的 inputView 上（research R3）。
@MainActor
final class KeyFeedback {
    private let tap = UIImpactFeedbackGenerator(style: .light)
    var hapticsOn = true

    init() { tap.prepare() }

    func keyDown() {
        // 键盘放在 App 自己的界面里（不再是输入视图），系统按键声用不了；每个字母已有一声拨弦
        if hapticsOn {
            tap.impactOccurred(intensity: 0.55)
            tap.prepare()
        }
    }
}
