import AVFoundation

/// 比武配乐：四层同时循环（Resources/Music/battle_*.caf），
/// 气势每升一档就把下一层音量推上去，断连就降回去。
@MainActor
final class MusicLayers {
    private var players: [AVAudioPlayer] = []
    private(set) var level = -1
    var on = true {
        didSet { on ? start() : players.forEach { $0.pause() } }
    }
    /// 总音量，默认低，不盖过打字和打击声。
    var master: Float = 0.55

    init() {
        for name in ["battle_base", "battle_l1", "battle_l2", "battle_l3"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "caf"),
                  let p = try? AVAudioPlayer(contentsOf: url) else { continue }
            p.numberOfLoops = -1
            p.volume = 0
            p.prepareToPlay()
            players.append(p)
        }
    }

    func start() {
        guard on, !players.isEmpty, !(players.first?.isPlaying ?? false) else { return }
        let t = (players.first?.deviceCurrentTime ?? 0) + 0.15      // 同一时刻开始，四层对齐
        for p in players { p.currentTime = 0; p.play(atTime: t) }
        let l = max(0, level)
        level = -1
        setLevel(l)
    }

    /// 0 = 只有底层，1–3 = 再叠上古筝、笛子、太鼓。
    func setLevel(_ l: Int) {
        guard l != level else { return }
        level = l
        for (i, p) in players.enumerated() {
            p.setVolume(i <= l ? master : 0, fadeDuration: i <= l ? 0.6 : 1.2)
        }
    }

    func stop() { players.forEach { $0.setVolume(0, fadeDuration: 1.0) } }
}
