import AVFoundation

/// 用系统中文语音读出整个词，再读这个字；设备没有中文语音时只显示不读。
@MainActor
final class Speaker {
    private let synth = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "zh-CN")

    var available: Bool { voice != nil }

    func say(word: String, character: String) {
        guard let voice else { return }
        synth.stopSpeaking(at: .immediate)
        for text in [word, character] {
            let u = AVSpeechUtterance(string: text)
            u.voice = voice
            u.rate = 0.42
            u.postUtteranceDelay = 0.25
            synth.speak(u)
        }
    }
}
