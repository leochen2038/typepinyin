import AVFoundation

/// 比武配乐：四层同时循环（Resources/Music/battle_*.caf），
/// 气势每升一档就把下一层音量推上去，断连就降回去。只在比武进行中放：有人倒地就淡出，结算、长卷、地图都安静。
@MainActor
final class MusicLayers {
    private var players: [AVAudioPlayer] = []
    private(set) var level = -1
    /// 正在比武（开关关着也算，打开后接着放）。
    private var active = false
    /// 淡出结束才真正停下；淡出途中又开打了，就取消这次停止。
    private var fadeToken = 0
    var on = true {
        didSet {
            if !on {
                players.forEach { $0.pause() }
            } else if active {
                play(from: max(0, level))
            }
        }
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

    /// 开打：四层从头放，先只开最底下一层。
    func start() {
        active = true
        play(from: 0)
    }

    private func play(from l: Int) {
        fadeToken += 1
        if on, let first = players.first {
            let t = first.deviceCurrentTime + 0.15                  // 同一时刻开始，四层对齐
            for p in players {
                p.pause()
                p.setVolume(0, fadeDuration: 0)
                p.currentTime = 0
                p.play(atTime: t)
            }
        }
        level = -1
        setLevel(l)
    }

    /// 0 = 只有底层，1–3 = 再叠上古筝、笛子、太鼓。
    func setLevel(_ l: Int) {
        guard active, l != level else { return }
        level = l
        for (i, p) in players.enumerated() {
            p.setVolume(i <= l ? master : 0, fadeDuration: i <= l ? 0.6 : 1.2)
        }
    }

    /// 打完或离开比武：淡出后停下。
    func stop() {
        guard active else { return }
        active = false
        level = -1
        fadeToken += 1
        let token = fadeToken
        let fade = 1.0
        players.forEach { $0.setVolume(0, fadeDuration: fade) }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(fade))
            guard let self, self.fadeToken == token else { return }
            self.players.forEach { $0.pause() }
        }
    }
}
