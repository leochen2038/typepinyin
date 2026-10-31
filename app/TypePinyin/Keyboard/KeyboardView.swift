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
        if geometry?.metrics != m { build(KeyGeometry(metrics: m)) } else { drawDivider(tuning().handZones || guide) }   // 高度变了要重画
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
        // 键重建以后补上原来的提示（教学引导开打时键盘可能还没排好）
        if let h = hinted {
            keyViews[h]?.setHint(true)
            if case .letter(let c) = h { zoneGlow = side(c) }
        }
        applyZones()
        if let c = thumbFor { thumbFor = nil; showThumb(c) }
    }

    /// 左手打的字母（两拇指打字时以 t/g/b 和 y/h/n 之间为界）。
    private var zoneGlow: Bool?   // nil = 都不亮；true = 左边亮；false = 右边亮
    private let divider = CAShapeLayer()

    /// 这个字母用哪只手：true 左、false 右。压在中线上（离中线不到半个键宽）的 g、v 归左手。
    private func side(_ c: Character) -> Bool? {
        guard let v = keyViews[.letter(c)] else { return nil }
        return v.frame.midX - bounds.midX < v.frame.width / 2
    }

    /// 教学引导：不管调参开没开，都画左右手分界线、亮出该按的那一边。
    var guide = false { didSet { applyZones() } }

    private func applyZones() {
        let on = tuning().handZones || guide
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

    // MARK: 教学：拇指动画

    private let thumb = ThumbView()
    private var thumbFor: Character?
    private var thumbLeft = false

    /// 教学：该按的键上停着一只半透明的白色大拇指，指尖点着这个键，慢慢呼吸（轻按、松开）；
    /// 换键时滑过去，不从屏幕外飞进来。右边的键用右手（指尖朝左上），左边的用左手（镜像）。传 nil 收起。
    func showThumb(_ c: Character?) {
        guard c != thumbFor else { return }
        thumbFor = c
        guard let c, let key = keyViews[.letter(c)], let isLeft = side(c) else {
            thumb.content.removeAllAnimations()
            UIView.animate(withDuration: 0.2) { self.thumb.alpha = 0 }
            return
        }
        let tip = CGPoint(x: key.frame.midX + (isLeft ? -5 : 5), y: key.frame.midY + 7)   // 指尖压在键的右下（左手左下），字母露出来
        let turn = CGAffineTransform(rotationAngle: ThumbView.lean)            // 从右下角斜着伸上来
        let pose = isLeft ? CGAffineTransform(scaleX: -1, y: 1).rotated(by: ThumbView.lean) : turn   // 左手：镜像，从左下角
        let fresh = thumb.superview == nil || thumb.alpha == 0
        let switchHands = !fresh && thumbLeft != isLeft
        thumbLeft = isLeft
        if thumb.superview == nil { addSubview(thumb) }
        bringSubviewToFront(thumb)
        thumb.content.removeAllAnimations()
        if fresh {
            thumb.transform = pose
            thumb.center = tip
            UIView.animate(withDuration: 0.3) { self.thumb.alpha = 1 }
        } else if switchHands {                                 // 换手：这只淡出，那只在新键上淡入（不做镜像翻转的过渡）
            UIView.animate(withDuration: 0.15, delay: 0, options: .beginFromCurrentState, animations: { self.thumb.alpha = 0 }) { _ in
                guard self.thumbLeft == isLeft else { return }
                self.thumb.transform = pose
                self.thumb.center = tip
                UIView.animate(withDuration: 0.25) { self.thumb.alpha = 1 }
            }
        } else {
            UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                self.thumb.transform = pose
                self.thumb.center = tip
                self.thumb.alpha = 1
            }
        }
        // 呼吸：一轮 2.4 秒，轻轻按下去（缩一点、更实）再松开
        let breathe = CABasicAnimation(keyPath: "transform.scale")
        breathe.fromValue = 1.0
        breathe.toValue = 0.9
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.62
        fade.toValue = 0.85
        let group = CAAnimationGroup()
        group.animations = [breathe, fade]
        group.duration = 1.2
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.beginTime = CACurrentMediaTime() + 0.35
        thumb.content.add(group, forKey: "breathe")
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

/// 教学用的大拇指，照双手拇指打字的样子画：先画一只竖着的右手拇指（指尖朝上、锚点在指尖），
/// 摆放时整只转成从右下角斜着伸上来。拇指短而粗（跟一个键差不多宽），指尖上一个宽的椭圆指甲，
/// 关节只有一道褶、轮廓不鼓；下面连着手：上沿往外撑到手背，下沿顺着掌根往下。白色、细描边，整体半透明。
final class ThumbView: UIView {
    /// 呼吸动画加在这一层上（不碰视图本身的旋转、镜像）。
    let content = CALayer()

    static let size = CGSize(width: 170, height: 180)
    static let tip = CGPoint(x: 70, y: 0)
    /// 摆放时转多少（右手；左手镜像）：拇指斜着朝左上。
    static let lean: CGFloat = -0.85

    override init(frame: CGRect) {
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        isUserInteractionEnabled = false
        alpha = 0
        layer.anchorPoint = CGPoint(x: Self.tip.x / Self.size.width, y: 0)
        let o = Self.tip
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x, y: o.y + y) }

        // 轮廓（以指尖为原点）：圆头 → 左边（掌根那侧）往下 → 底边 → 右边（手背那侧）往上回到圆头
        let r: CGFloat = 19
        let shape = UIBezierPath()
        shape.move(to: p(r, r))
        shape.addArc(withCenter: p(0, r), radius: r, startAngle: 0, endAngle: .pi, clockwise: false)
        Self.smooth(shape, through: [p(-19.5, 50), p(-21, 78), p(-26, 108), p(-31, 140), p(-36, 182)])
        shape.addLine(to: p(100, 182))
        Self.smooth(shape, through: [p(92, 118), p(54, 96), p(25, 82), p(20.5, 52), p(r, r)])
        shape.close()

        let finger = CAShapeLayer()
        finger.path = shape.cgPath
        finger.fillColor = UIColor.white.cgColor
        finger.strokeColor = Palette.uiInk.withAlphaComponent(0.6).cgColor
        finger.lineWidth = 1.8
        finger.lineJoin = .round
        finger.shadowColor = UIColor.black.cgColor
        finger.shadowOpacity = 0.2
        finger.shadowRadius = 4
        finger.shadowOffset = CGSize(width: 0, height: 2)

        // 指甲：指尖上一个宽椭圆
        let nail = CAShapeLayer()
        nail.path = UIBezierPath(ovalIn: CGRect(x: o.x - 12.5, y: o.y + 5, width: 25, height: 24)).cgPath
        nail.fillColor = UIColor(white: 0.96, alpha: 1).cgColor
        nail.strokeColor = Palette.uiInk.withAlphaComponent(0.4).cgColor
        nail.lineWidth = 1.3

        // 关节：一道微弯的褶
        let creasePath = UIBezierPath()
        creasePath.move(to: p(-13, 56))
        creasePath.addQuadCurve(to: p(12, 53), controlPoint: p(0, 50))
        let crease = CAShapeLayer()
        crease.path = creasePath.cgPath
        crease.fillColor = nil
        crease.strokeColor = Palette.uiInk.withAlphaComponent(0.45).cgColor
        crease.lineWidth = 1.5
        crease.lineCap = .round

        content.bounds = bounds
        content.anchorPoint = layer.anchorPoint
        content.position = Self.tip
        content.allowsGroupOpacity = true
        content.opacity = 0.75
        for l in [finger, nail, crease] { content.addSublayer(l) }
        layer.addSublayer(content)
    }

    /// 从当前点开始，平滑地穿过这些点（Catmull-Rom 换成贝塞尔）。
    static func smooth(_ path: UIBezierPath, through pts: [CGPoint]) {
        let all = [path.currentPoint] + pts
        for i in 1..<all.count {
            let p0 = all[max(i - 2, 0)], p1 = all[i - 1], p2 = all[i], p3 = all[min(i + 1, all.count - 1)]
            path.addCurve(to: p2,
                          controlPoint1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                          controlPoint2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6))
        }
    }

    required init?(coder: NSCoder) { fatalError() }
}
