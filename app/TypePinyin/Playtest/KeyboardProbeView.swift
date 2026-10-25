import SwiftUI

/// 只给量键盘尺寸用：以 -keyboardProbe 启动时显示一个获得焦点的英文文本框，
/// 用来截系统键盘、量按键尺寸。
struct KeyboardProbeView: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack {
            TextField("probe", text: $text)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .padding()
            Spacer()
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focused = true } }
    }
}
