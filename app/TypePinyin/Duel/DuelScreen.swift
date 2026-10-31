import SpriteKit
import SwiftUI

/// 比武界面，自上而下：状态栏、战斗区、招式牌、键盘（放在界面里，主角的手才能伸到键上）。
struct DuelScreen: View {
    @State var c: DuelController
    /// 旅程：开打前先排好这一场（设好 c.plan）。
    var prepare: (() -> Void)? = nil
    @State private var showPanel = false
    @State private var cardFrames: [Int: CGRect] = [:]
    @State private var battleFrame: CGRect = .zero
    @State private var keyboardFrame: CGRect = .zero
    @State private var qiFrame: CGRect = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            StatusBarView(c: c)
                .overlay(PanelGesture { showPanel = true })
            Rectangle().fill(Palette.ink).frame(height: 3)
            ZStack(alignment: .topLeading) {
                SpriteView(scene: c.scene, preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
                    .accessibilityHidden(true)
                ComboView(combo: c.combo, goldAt: c.tuning.comboGoldAt, redAt: c.tuning.comboRedAt, heat: c.heat)
                    .padding(.leading, 20).padding(.top, 14)
                    .animation(.spring(duration: 0.2), value: c.combo)
                PressureBarHost(c: c)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 14).padding(.top, 12)
                if let inc = c.incoming {
                    IncomingBox(incoming: inc, progress: c.incomingProgress)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 14).padding(.top, 10)
                }
                if let s = c.newMoveToast {
                    NewMoveToast(syllable: s).frame(maxWidth: .infinity).padding(.top, 24)
                }
                if c.killBanner {
                    KillBanner().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if c.finaleBanner {
                    FinaleBanner().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                NearMissLayer(trigger: c.nearMissToast)
                if let g = c.guide {
                    GuideBanner(title: g.title, line: g.line)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 12)
                        .transition(.opacity)
                } else if let t = c.tip {
                    TipBanner(text: t).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom).padding(.bottom, 14)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxHeight: .infinity)
            .clipped()
            .background(GeometryReader { g in Color.clear.preference(key: BattleFrameKey.self, value: g.frame(in: .named("duel"))) })
            .modifier(Shake(trigger: c.mistakeFlash, enabled: !reduceMotion))
            Rectangle().fill(Palette.ink).frame(height: 3)
            CardsView(c: c)
                .padding(.bottom, 8)
                .zIndex(1)      // 打完一个字迸的纸屑要盖在键盘上面，不然往下落就被键盘挡掉
            KeyboardHost(controller: c)
                .background(GeometryReader { g in Color.clear.preference(key: KeyboardFrameKey.self, value: g.frame(in: .named("duel"))) })
                .background(Palette.mist2.ignoresSafeArea(edges: .bottom))
                .background(KeyInputHost(controller: c).frame(width: 1, height: 1).opacity(0.01))
        }
        .background(Palette.mist)
        .coordinateSpace(.named("duel"))
        .onPreferenceChange(CardFrameKey.self) { cardFrames = $0 }
        .onPreferenceChange(BattleFrameKey.self) { battleFrame = $0 }
        .onPreferenceChange(KeyboardFrameKey.self) { keyboardFrame = $0 }
        .onPreferenceChange(QiBarFrameKey.self) { qiFrame = $0 }
        .overlay {
            FXOverlay(c: c, cardFrames: cardFrames, battleFrame: battleFrame, keyboardFrame: keyboardFrame, qiFrame: qiFrame)
        }

        .overlay {
            if let s = c.summary {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea(edges: .top)
                    SummaryCardView(s: s, foe: c.foeName, fasterBy: c.fasterBy, extraGains: c.summaryGains, actions: c.summaryActions) { c.restart() }
                }
                .transition(.opacity)
            }
        }
        .overlay {
            if c.pausedForBackground {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea(edges: .top)
                    Button { c.resumeFromBackground() } label: {
                        Text("继续").font(Fonts.display(30)).padding(.horizontal, 40).padding(.vertical, 12)
                            .background(Palette.gold).foregroundStyle(Palette.ink)
                            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("continue")
                }
            }
        }
        .animation(.spring(duration: 0.3), value: c.finaleBanner)
        .animation(.easeOut(duration: 0.25), value: c.tip)
        .animation(.easeOut(duration: 0.2), value: c.guide?.title)
        .animation(.spring(duration: 0.18, bounce: 0.4), value: c.killBanner)
        .animation(.easeOut(duration: 0.25), value: c.summary != nil)
        .sheet(isPresented: $showPanel) { TuningPanelView(c: c) }
        .onAppear {
            c.scene.reducedMotion = reduceMotion
            if let prepare { prepare() } else { c.plan = nil }
            c.start()
        }
        .modifier(Lifecycle(c: c))
    }

}

/// 最上层的演出：回顾牌、取字（剑气 / 绳镖）。各层各自读自己的状态：
/// 打字时取字每个键都在变，要是放在一起，回顾牌也会跟着整张重建（连缓存的字母图都要重画）。
struct FXOverlay: View {
    let c: DuelController
    let cardFrames: [Int: CGRect]
    let battleFrame: CGRect
    let keyboardFrame: CGRect
    var qiFrame: CGRect = .zero

    var body: some View {
        ZStack {
            ReviewHost(c: c, cardFrames: cardFrames)
            if c.finisherArrival > 0, qiFrame != .zero, let card = cardFrames[0] {
                QiSparks(from: CGPoint(x: qiFrame.maxX - 6, y: qiFrame.midY), to: CGPoint(x: card.midX, y: card.midY))
                    .id(c.finisherArrival)                         // 每张必杀牌飞一次
            }
            if battleFrame != .zero && keyboardFrame != .zero {
                GrabHost(c: c, hand: { toScreen(c.scene.playerHand) }, chest: { toScreen(c.scene.playerChest) }, key: { ch in
                    c.keyCenter(ch).map { CGPoint(x: keyboardFrame.minX + $0.x, y: keyboardFrame.minY + $0.y) }
                })
            }
        }
    }

    /// 战斗区（SpriteKit，y 向上）里的点 → 界面坐标（y 向下）。
    private func toScreen(_ p: CGPoint?) -> CGPoint {
        guard let p else { return CGPoint(x: battleFrame.midX, y: battleFrame.midY) }
        return CGPoint(x: battleFrame.minX + p.x, y: battleFrame.minY + battleFrame.height - p.y)
    }
}

struct ReviewHost: View {
    let c: DuelController
    let cardFrames: [Int: CGRect]
    var body: some View {
        ReviewLayer(reviews: c.reviews, cardFrames: cardFrames, big: c.cards.count == 1, rank: c.tuning.rankFx, theme: c.tuning.rankFxTheme)
    }
}

struct GrabHost: View {
    let c: DuelController
    let hand: () -> CGPoint
    let chest: () -> CGPoint
    let key: (Character) -> CGPoint?
    var body: some View { GrabLayer(grabs: c.grabs, chains: c.chains, hand: hand, chest: chest, key: key, style: c.tuning.grabStyle, hot: c.heat >= 3) }
}

/// 已学会的音节打错时，战斗区红色抖动。
struct Shake: GeometryEffect {
    var trigger: Int
    var enabled: Bool
    var animatableData: CGFloat

    init(trigger: Int, enabled: Bool) {
        self.trigger = trigger
        self.enabled = enabled
        self.animatableData = CGFloat(trigger)
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard enabled else { return ProjectionTransform(.identity) }
        let x = sin(animatableData * .pi * 6) * 6 * (1 - (animatableData - floor(animatableData)))
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

/// 调参面板的隐藏入口：在状态栏上连点三下。
struct PanelGesture: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let g = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.fire(_:)))
        g.numberOfTapsRequired = 3
        v.addGestureRecognizer(g)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) { context.coordinator.action = action }
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    @MainActor final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func fire(_ g: UITapGestureRecognizer) { if g.state == .ended { action() } }
    }
}

/// 每次按偏冒一下「差一点」，0.8 秒后消失。
struct NearMissLayer: View {
    let trigger: Int
    @State private var visible = false

    var body: some View {
        ZStack {
            if visible { NearMissToast() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 64)
        .animation(.easeOut(duration: 0.15), value: visible)
        .onChange(of: trigger) { _, _ in
            visible = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                visible = false
            }
        }
        .allowsHitTesting(false)
    }
}

/// 必杀牌露出来时：一串朱红和白的光点从气条飞到牌上（弧线、一个跟一个，墨线描边），落下就散。
struct QiSparks: View {
    let from: CGPoint
    let to: CGPoint
    @State private var t: CGFloat = 0
    @State private var gone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SparkField(from: from, to: to, t: t)
            .opacity(gone ? 0 : 1)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { gone = true; return }
                withAnimation(.easeIn(duration: DuelController.qiFlight)) { t = 1 }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(DuelController.qiFlight + 0.05))
                    withAnimation(.easeOut(duration: 0.15)) { gone = true }
                }
            }
    }
}

/// 光点的位置是进度 t 的函数：做成 Animatable，t 动画时每帧按弧线重算。
private struct SparkField: View, @preconcurrency Animatable {
    let from: CGPoint
    let to: CGPoint
    var t: CGFloat
    var animatableData: CGFloat { get { t } set { t = newValue } }
    static let count = 9
    static let lag: CGFloat = 0.06

    var body: some View {
        ZStack {
            ForEach(0..<Self.count, id: \.self) { k in
                let p = max(0, min(1, (t - CGFloat(k) * Self.lag) / (1 - Self.lag * CGFloat(Self.count - 1))))
                let d = 10 - CGFloat(k) * 0.6
                Circle().fill(k % 3 == 0 ? Color.white : Palette.red)
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 1.2))
                    .frame(width: d, height: d)
                    .position(point(p, bend: CGFloat(k % 3 - 1) * 18))
                    .opacity(p <= 0 || p >= 1 ? 0 : 1)
            }
        }
    }

    /// 二次贝塞尔：从气条往右甩出去，再落到牌中间；bend 让几颗光点走的弧线错开。
    func point(_ p: CGFloat, bend: CGFloat) -> CGPoint {
        let ctrl = CGPoint(x: max(from.x, to.x) + 70 + bend, y: from.y + (to.y - from.y) * 0.25 + bend)
        let u = 1 - p
        return CGPoint(x: u * u * from.x + 2 * u * p * ctrl.x + p * p * to.x,
                       y: u * u * from.y + 2 * u * p * ctrl.y + p * p * to.y)
    }
}
