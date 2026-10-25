import AVFoundation
import UIKit

/// 音效与震动。音效文件见 Resources/CREDITS.md。
@MainActor
final class SoundFX {
    enum Sound: String, CaseIterable {
        case hitLight = "hit_light", hitHeavy = "hit_heavy", parry, block, hurt, newmove, mistake, finisher, win, retry
        case levelup, nearmiss, record
        case tick0 = "tick_0", tick1 = "tick_1", tick2 = "tick_2", tick3 = "tick_3"
        case tick4 = "tick_4", tick5 = "tick_5", tick6 = "tick_6", tick7 = "tick_7"
    }

    /// 音效用 AVAudioEngine 播：开场把所有音效读进内存，备 16 个声部轮流用，播放时只是把声音交给一个声部，
    /// 而且放到后台队列做。原来用 AVAudioPlayer，真机上每次 play() 要在主线程卡 20–60 毫秒，一刀两个声音就掉好几帧。
    private let engine = AVAudioEngine()
    private var voices: [AVAudioPlayerNode] = []
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var nextVoice = 0
    private let queue = DispatchQueue(label: "sfx", qos: .userInteractive)
    var soundOn = true
    var hapticsOn = true
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notice = UINotificationFeedbackGenerator()

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        var format: AVAudioFormat?
        for s in Sound.allCases {
            guard let url = Bundle.main.url(forResource: s.rawValue, withExtension: "wav"),
                  let file = try? AVAudioFile(forReading: url),
                  let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buf)) != nil else { continue }
            buffers[s] = buf
            format = format ?? file.processingFormat
        }
        for _ in 0..<16 {
            let v = AVAudioPlayerNode()
            engine.attach(v)
            engine.connect(v, to: engine.mainMixerNode, format: format)
            voices.append(v)
        }
        try? engine.start()
        voices.forEach { $0.play() }
        [light, heavy, rigid].forEach { $0.prepare() }
        notice.prepare()
    }

    /// 同一个词里第 i 个字母：音调一个比一个高。
    func tick(_ i: Int) {
        let ticks: [Sound] = [.tick0, .tick1, .tick2, .tick3, .tick4, .tick5, .tick6, .tick7]
        play(ticks[min(max(0, i), ticks.count - 1)])
    }

    func play(_ s: Sound) {
        guard soundOn, let buf = buffers[s], !voices.isEmpty else { return }
        let v = voices[nextVoice % voices.count]
        nextVoice += 1
        let engine = engine
        PerfLog.measure("播放音效") {
            queue.async {
                if !engine.isRunning { try? engine.start() }       // 来电、切后台之后引擎可能停了
                v.scheduleBuffer(buf, at: nil, options: .interrupts)
                if !v.isPlaying { v.play() }
            }
        }
    }

    func hitHaptic(heavy isHeavy: Bool) {
        guard hapticsOn else { return }
        PerfLog.measure("震动") {
            (isHeavy ? heavy : light).impactOccurred()
            (isHeavy ? heavy : light).prepare()
        }
    }

    func finisherHaptic() {
        guard hapticsOn else { return }
        rigid.impactOccurred(intensity: 1)
        notice.notificationOccurred(.success)
    }
}
