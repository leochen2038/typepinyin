import DuelCore
import SwiftUI
import UIKit

/// 隐藏的焦点视图：只接收实体键盘（模拟器、蓝牙键盘）的按键，交给引擎。
/// 屏幕键盘放在界面里（KeyboardHost），所以这里的输入视图是一个空视图，不弹出系统键盘。
@MainActor
final class KeyInputHostView: UIView, UIKeyInput {
    let keyboard = KeyboardView(frame: CGRect(x: 0, y: 0, width: 390, height: 240))
    var onHardwareKey: ((KeyKind) -> Void)?
    private let emptyInput = UIView(frame: .zero)

    override var canBecomeFirstResponder: Bool { true }
    override var inputView: UIView? { emptyInput }
    var hasText: Bool { false }

    func insertText(_ text: String) {
        for ch in text.lowercased() {
            if ch >= "a" && ch <= "z" { onHardwareKey?(.letter(ch)) }
            else if ch == "/" || ch == "?" || ch == "\t" { onHardwareKey?(.teach) }
        }
    }

    func deleteBackward() { onHardwareKey?(.backspace) }

    var keyboardType: UIKeyboardType { get { .asciiCapable } set {} }
    var autocorrectionType: UITextAutocorrectionType { get { .no } set {} }
    var autocapitalizationType: UITextAutocapitalizationType { get { .none } set {} }
    var spellCheckingType: UITextSpellCheckingType { get { .no } set {} }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { DispatchQueue.main.async { self.becomeFirstResponder() } }
    }
}

/// 接键盘的一方：比武（DuelController）和打文字（TextController）都用同一个键盘。
@MainActor
protocol KeyTarget: AnyObject {
    func attach(keyboard: KeyboardView)
    func key(_ ev: KeyEvent)
}

extension DuelController: KeyTarget {}

/// 屏幕键盘：照系统键盘的尺寸，放在界面最下面。
struct KeyboardHost: UIViewRepresentable {
    let controller: any KeyTarget

    func makeUIView(context: Context) -> KeyboardView {
        let k = KeyboardView(frame: CGRect(x: 0, y: 0, width: 390, height: 300))
        controller.attach(keyboard: k)
        return k
    }

    func updateUIView(_ uiView: KeyboardView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: KeyboardView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 390, height: uiView.intrinsicContentSize.height)
    }
}

struct KeyInputHost: UIViewRepresentable {
    let controller: any KeyTarget

    func makeUIView(context: Context) -> KeyInputHostView {
        let v = KeyInputHostView()
        v.onHardwareKey = { [weak controller] kind in
            let now = CACurrentMediaTime()
            controller?.key(KeyEvent(kind: kind, downAt: now, upAt: now, commitAt: now))
        }
        return v
    }

    func updateUIView(_ uiView: KeyInputHostView, context: Context) {
        if !uiView.isFirstResponder { uiView.becomeFirstResponder() }
    }
}
