import DuelCore
import UIKit

/// 自带键盘：照系统键盘实测尺寸画三排字母，左下「读音」、右下退格。
/// 左右手提示：左右手之间一条虚线，沿键缝走（t|y、g|h、v|b），所以是一条有台阶的线；
/// 卡壳提示时，该用的那只手那一侧的字母键整块浅浅亮一下。按键在屏幕上的位置分左右，正好压在中线上的 g、v 归左手。
/// 自己处理触摸：按下就高亮、弹放大字母、响按键声；默认抬起出字（按下后可滑到旁边的键再松手）。
/// 多指按按下先后排队；按到预期字母的相邻键时标记为「按偏了」。
@MainActor
final class KeyboardView: UIView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }

    /// 出字回调（时间都是 UITouch.timestamp 的时钟，和 CACurrentMediaTime 一致）。
    var onKey: ((KeyEvent) -> Void)?
    /// 按下回调，给延迟统计用。
    var onTouchDown: ((TimeInterval) -> Void)?
    var expectedLetters: () -> Set<Character> = { [] }
    var tuning: () -> Tuning = { .standard }
    let feedback = KeyFeedback()

    private var geometry: KeyGeometry?
    private var keyViews: [KeyCap.Kind: KeyCapView] = [:]
    private let popup = KeyPopup()
    private var hinted: KeyCap.Kind?
    private struct Active { var cap: KeyCap; var downAt: TimeInterval; var point: CGPoint }
    private var active: [ObjectIdentifier: Active] = [:]
    private var bottomInset: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Palette.uiMist2
        isMultipleTouchEnabled = true
        clipsToBounds = false
        let border = UIView()
        border.backgroundColor = Palette.uiInk
        border.autoresizingMask = [.flexibleWidth]
        border.frame = CGRect(x: 0, y: 0, width: frame.width, height: 3)
        border.tag = 99
        addSubview(border)
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    required init?(coder: NSCoder) { fatalError() }

    private var metrics: KeyboardMetrics {
        let w = bounds.width > 0 ? bounds.width : (window?.windowScene?.screen.bounds.width ?? 390)
        return AppResources.keyboardMetrics.metrics(forWidth: w)
    }

    override var intrinsicContentSize: CGSize {
        // 只有三排字母（没有系统的空格排和底栏），高度按三排算；下面多留半个键高，整排键往上抬（贴着底边拇指够得别扭）
        let m = metrics
        let rows = m.topInset + 3 * m.keyHeight + 2 * m.gapY + 10 + m.keyHeight * 0.5
        return CGSize(width: UIView.noIntrinsicMetric, height: rows + 3 + bottomInset)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        if safeAreaInsets.bottom != bottomInset {
            bottomInset = safeAreaInsets.bottom
            invalidateIntrinsicContentSize()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let m = metrics
        if geometry?.metrics != m { build(KeyGeometry(metrics: m)) } else { drawDivider(tuning().handZones) }   // 高度变了要重画
    }

    private func build(_ g: KeyGeometry) {
        geometry = g
        keyViews.values.forEach { $0.removeFromSuperview() }
        keyViews = [:]
        for cap in g.keys {
            let v = KeyCapView(kind: cap.kind)
            v.frame = CGRect(x: cap.face.x, y: cap.face.y + 3, width: cap.face.w, height: cap.face.h)
            addSubview(v)
            keyViews[cap.kind] = v
        }
        addSubview(popup)
        bringSubviewToFront(popup)
        applyZones()
    }

    /// 左手打的字母（两拇指打字时以 t/g/b 和 y/h/n 之间为界）。
    private var zoneGlow: Bool?   // nil = 都不亮；true = 左边亮；false = 右边亮
    private let divider = CAShapeLayer()

    /// 这个字母用哪只手：true 左、false 右。压在中线上（离中线不到半个键宽）的 g、v 归左手。
    private func side(_ c: Character) -> Bool? {
        guard let v = keyViews[.letter(c)] else { return nil }
        return v.frame.midX - bounds.midX < v.frame.width / 2
    }

    private func applyZones() {
        let on = tuning().handZones
        for (kind, v) in keyViews {
            guard case .letter(let c) = kind else { continue }
            v.zoneColor = on && zoneGlow != nil && zoneGlow == side(c) ? UIColor(hex: 0xFFF0C8) : .white
        }
        drawDivider(on)
    }

    /// 左右手分界虚线：每一排走在左手最后一个键和右手第一个键的缝中间，排与排之间横着拐一下。
    private func drawDivider(_ on: Bool) {
        let pairs: [(Character, Character)] = [("t", "y"), ("g", "h"), ("v", "b")]
        let rows = pairs.compactMap { l, r -> (x: CGFloat, top: CGFloat, bottom: CGFloat)? in
            guard let a = keyViews[.letter(l)]?.frame, let b = keyViews[.letter(r)]?.frame else { return nil }
            return ((a.maxX + b.minX) / 2, a.minY, a.maxY)
        }
        guard rows.count == 3 else { return }
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rows[0].x, y: rows[0].top))
        for i in 0..<rows.count {
            let bottom = i + 1 < rows.count ? (rows[i].bottom + rows[i + 1].top) / 2 : rows[i].bottom
            path.addLine(to: CGPoint(x: rows[i].x, y: bottom))
            if i + 1 < rows.count { path.addLine(to: CGPoint(x: rows[i + 1].x, y: bottom)) }
        }
        divider.path = path.cgPath
        divider.fillColor = nil
        divider.strokeColor = Palette.uiInk.withAlphaComponent(0.4).cgColor
        divider.lineWidth = 2
        divider.lineDashPattern = [5, 4]
        divider.isHidden = !on
        if divider.superlayer == nil { layer.insertSublayer(divider, at: 0) }
    }

    /// 某个字母键的中心点（键盘自己的坐标）。
    func keyCenter(_ c: Character) -> CGPoint? {
        guard let v = keyViews[.letter(c)] else { return nil }
        return CGPoint(x: v.frame.midX, y: v.frame.midY)
    }

    /// 卡壳提示：让下一个该按的键发金光、一闪一闪；传 nil 熄灭。
    func showHint(_ c: Character?) {
        if let h = hinted { keyViews[h]?.setHint(false) }
        hinted = c.map { .letter($0) }
        if let h = hinted { keyViews[h]?.setHint(true) }
        zoneGlow = c.flatMap { side($0) }
        applyZones()
    }

    // MARK: - 触摸

    private func point(_ t: UITouch) -> KPoint {
        let p = t.location(in: self)
        return KPoint(p.x, p.y - 3)
    }

    private func hit(_ t: UITouch) -> KeyCap? {
        geometry?.key(at: point(t), expected: expectedLetters(), grow: tuning().expectedKeyGrowPt)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard let cap = hit(t) else { continue }
            onTouchDown?(t.timestamp)
            feedback.hapticsOn = tuning().hapticsOnKey
            feedback.keyDown()
            press(cap, true)
            if tuning().commitOnRelease {
                active[ObjectIdentifier(t)] = Active(cap: cap, downAt: t.timestamp, point: t.location(in: self))
            } else {
                commit(cap, down: t.timestamp, up: t.timestamp, at: point(t))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in self?.press(cap, false) }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard tuning().commitOnRelease else { return }
        for t in touches {
            let id = ObjectIdentifier(t)
            guard var a = active[id], let cap = hit(t) else { continue }
            if cap.kind != a.cap.kind {
                press(a.cap, false)
                press(cap, true)
                a.cap = cap
            }
            a.point = t.location(in: self)
            active[id] = a
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
            let id = ObjectIdentifier(t)
            guard let a = active.removeValue(forKey: id) else { continue }
            press(a.cap, false)
            commit(a.cap, down: a.downAt, up: t.timestamp, at: point(t))
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if let a = active.removeValue(forKey: ObjectIdentifier(t)) { press(a.cap, false) }
        }
    }

    private func commit(_ cap: KeyCap, down: TimeInterval, up: TimeInterval, at p: KPoint) {
        let commitAt = tuning().commitOnRelease ? up : down
        switch cap.kind {
        case .letter(let c):
            let miss = geometry?.nearMiss(hit: c, at: p, expected: expectedLetters(), maxDistance: tuning().nearMissMaxPt)
            if let m = miss { keyViews[.letter(m)]?.blink() }
            onKey?(KeyEvent(kind: .letter(c), downAt: down, upAt: up, commitAt: commitAt, nearMissOf: miss))
        case .teach:
            onKey?(KeyEvent(kind: .teach, downAt: down, upAt: up, commitAt: commitAt))
        case .backspace:
            onKey?(KeyEvent(kind: .backspace, downAt: down, upAt: up, commitAt: commitAt))
        }
    }

    private func press(_ cap: KeyCap, _ down: Bool) {
        guard let v = keyViews[cap.kind] else { return }
        v.setPressed(down)
        if down, case .letter(let c) = cap.kind {
            popup.show(String(c), above: v.frame)
            bringSubviewToFront(popup)
        } else if !down, active.isEmpty {
            popup.hide()
        }
    }
}

/// 一个键帽：白底粗描边硬阴影（国潮版画），按下变金色。
final class KeyCapView: UIView {
    private let label = UILabel()
    private let kind: KeyCap.Kind

    init(kind: KeyCap.Kind) {
        self.kind = kind
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        layer.borderColor = Palette.uiInk.cgColor
        layer.borderWidth = 2
        layer.cornerRadius = 4
        layer.shadowColor = Palette.uiInk.cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 2, height: 2)
        label.textAlignment = .center
        label.textColor = Palette.uiInk
        switch kind {
        case .letter(let c):
            label.text = String(c)
            label.font = .monospacedSystemFont(ofSize: 19, weight: .bold)
            backgroundColor = .white
            accessibilityLabel = String(c)
        case .teach:
            label.text = "读音"
            label.font = .systemFont(ofSize: 14, weight: .black)
            backgroundColor = Palette.uiGold
            accessibilityLabel = "读音"
        case .backspace:
            label.text = "⌫"
            label.font = .systemFont(ofSize: 20, weight: .bold)
            backgroundColor = .white
            accessibilityLabel = "退格"
        }
        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 4).cgPath
    }

    /// 字母键的底色（左右手分区）。
    var zoneColor: UIColor = .white {
        didSet { if !pressed { backgroundColor = restColor } }
    }
    private var pressed = false
    private var restColor: UIColor {
        switch kind {
        case .teach: Palette.uiGold
        case .letter: zoneColor
        case .backspace: .white
        }
    }

    func setPressed(_ on: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pressed = on
        backgroundColor = on ? Palette.uiGold : restColor
        transform = on ? CGAffineTransform(translationX: 1, y: 1) : .identity
        layer.shadowOffset = on ? CGSize(width: 1, height: 1) : CGSize(width: 2, height: 2)
        CATransaction.commit()
    }

    /// 卡壳提示：金色描边、一闪一闪。
    func setHint(_ on: Bool) {
        layer.removeAnimation(forKey: "hint")
        if on {
            layer.borderColor = Palette.uiGold.cgColor
            layer.borderWidth = 4
            let pulse = CABasicAnimation(keyPath: "backgroundColor")
            pulse.fromValue = restColor.cgColor
            pulse.toValue = Palette.uiGold.cgColor
            pulse.duration = 0.45
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            layer.add(pulse, forKey: "hint")
        } else {
            layer.borderColor = Palette.uiInk.cgColor
            layer.borderWidth = 2
        }
    }

    /// 「按偏了」时预期键轻闪一下。
    func blink() {
        let old = backgroundColor
        backgroundColor = Palette.uiGold.withAlphaComponent(0.6)
        UIView.animate(withDuration: 0.25, delay: 0.05) { self.backgroundColor = old }
    }
}
