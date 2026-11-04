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
                    // 定格：镜头往对手慢慢推近 8%，结束时弹回
                    .scaleEffect(c.freezeCaption == nil ? 1 : 1.08, anchor: UnitPoint(x: c.freezeAnchor.x, y: c.freezeAnchor.y))
                    .animation(c.freezeCaption == nil ? .spring(duration: 0.25, bounce: 0.3) : .easeOut(duration: c.freezeSeconds),
                               value: c.freezeCaption == nil)
                    .clipped()
                    .overlay { FreezeFrameMark(caption: c.freezeCaption) }
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
                    SummaryCardView(s: s, foe: c.foeName, extraGains: c.summaryGains, actions: c.summaryActions) { c.restart() }
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
            if let sent = c.qiSentAt, Date().timeIntervalSince(sent) < DuelController.qiArrive + QiSparks.landing,
               qiFrame != .zero, let card = cardFrames[0] {
                QiSparks(from: CGPoint(x: qiFrame.maxX - 6, y: qiFrame.midY), to: CGPoint(x: card.midX, y: card.midY), start: sent)
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
        ReviewLayer(reviews: c.reviews, cardFrames: cardFrames, big: c.cards.count == 1, rank: c.tuning.rankFx, theme: c.tuning.rankFxTheme,
                    volumeRanks: c.volumeRanks)
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

// Motion Prompt #014 #003 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#014
/// 送气，三段：
/// 1. 聚气：0.14 秒里一圈光点从四周旋进气条末端，聚成一团朱红气团；
/// 2. 飞（拖尾参考 Motion Prompt #014 モーショントレイル）：气团沿弧线飞到必杀牌上，身后 15 个残影按固定时间差排开，
///    越旧越小越淡（半径按气团大小从原版 22→6 换算，透明度 0.9·(1 − i/15) + 0.05），颜色由新到旧朱红 → 米白 → 墨（原版珊瑚 → 黄 → 蓝）；
/// 3. 落（参考 Motion Prompt #003 バースト）：朱红圈半径 44→90、线宽 16→0 用 0.6 秒外扩（easeOut 5 次），
///    10 道放射线（墨、朱红相间，线宽 9）尖端从 64 冲到 130（纵向 0.82 倍）、长度 36→0，10 个粒子（朱红、墨相间，半径 8→4.8）
///    沿横 1.45、纵 0.78 的椭圆从 58 飞到 150 后淡掉。牌那边同时缩一下再弹回（见 FinisherCardFX）。
/// 原版的数值按牌的大小放大 1.3 倍。（原来是九颗小光点一路飞过去，太简陋。）
struct QiSparks: View {
    let from: CGPoint
    let to: CGPoint
    /// 送气开始的时刻（控制器记的），不用视图出现的时刻。
    let start: Date
    @State private var done = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    static let landing = 0.72
    static let paper = Color(red: 0.965, green: 0.945, blue: 0.902)

    var body: some View {
        if reduceMotion || done {
            EmptyView()
        } else {
            TimelineView(.animation) { tl in
                let el = tl.date.timeIntervalSince(start)
                let g = DuelController.qiGather, f = DuelController.qiFlight
                ZStack {
                    if el < g { gather(el / g) }
                    if el >= g && el < g + f + 0.05 { comet(min(1, (el - g) / f)) }
                    if el > g + f && el < g + f + Self.landing { landing(el - g - f) }
                }
            }
            .allowsHitTesting(false)
            .task {                                                   // 演完就停掉时间线，不再每帧重画
                try? await Task.sleep(for: .seconds(max(0, DuelController.qiArrive + Self.landing + 0.05 - Date().timeIntervalSince(start))))
                done = true
            }
        }
    }

    /// 二次贝塞尔：从气条往右甩出去，再落到牌中间。
    func point(_ p: Double) -> CGPoint {
        let ctrl = CGPoint(x: max(from.x, to.x) + 70, y: from.y + (to.y - from.y) * 0.25)
        let u = 1 - p
        return CGPoint(x: u * u * from.x + 2 * u * p * ctrl.x + p * p * to.x,
                       y: u * u * from.y + 2 * u * p * ctrl.y + p * p * to.y)
    }

    func orb(_ scale: Double) -> some View {
        Circle().fill(Palette.red)
            .overlay(Circle().fill(Color.white).padding(6))
            .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
            .frame(width: 24, height: 24)
            .scaleEffect(scale)
    }

    @ViewBuilder func gather(_ t: Double) -> some View {
        ZStack {
            ForEach(0..<10, id: \.self) { k in                       // 光点一边转一边往里收（旋进去）
                let a0 = Double(k) / 10 * 2 * .pi
                let a = a0 + t * 2.2
                let d = (1 - t) * (24 + Double(k % 3) * 8)
                Circle().fill(k % 2 == 0 ? Palette.red : Self.paper)
                    .overlay(Circle().stroke(Palette.ink, lineWidth: 1))
                    .frame(width: 6, height: 6)
                    .position(x: from.x + cos(a) * d, y: from.y + sin(a) * d)
                    .opacity(t < 0.95 ? 1 : 0)
            }
            orb(t).position(from)
        }
    }

    @ViewBuilder func comet(_ t: Double) -> some View {
        let p = pow(t, 1.4)                                       // 稍微越飞越快，像被牌吸过去
        ZStack {
            ForEach((1...15).reversed(), id: \.self) { i in           // 旧的先画，气团最后盖上
                let q = max(0, p - Double(i) * 0.018)
                let r = 10.5 - 7.5 * Double(i - 1) / 14                // 原版残影半径 22→6，按气团（半径 12）换算
                let c: Color = i <= 5 ? Palette.red : (i <= 10 ? Self.paper : Palette.ink)
                Circle().fill(c)
                    .frame(width: r * 2, height: r * 2)
                    .opacity(0.9 * (1 - Double(i) / 15) + 0.05)
                    .position(point(q))
            }
            orb(1).position(point(p))
        }
    }

    @ViewBuilder func landing(_ el: Double) -> some View {
        let k = 1.3
        let ringT = min(1, el / 0.6), ringE = 1 - pow(1 - ringT, 5)
        ZStack {
            Circle().stroke(Palette.red, lineWidth: 16 * (1 - ringE))
                .frame(width: 2 * k * (44 + 46 * ringE), height: 2 * k * (44 + 46 * ringE))
                .opacity(ringT < 1 ? 1 : 0)
            ForEach(0..<10, id: \.self) { i in                       // 放射线
                let a = Double(i) / 10 * 2 * .pi
                let lt = min(1, max(0, (el - 0.0) / 0.7)), le = 1 - pow(1 - lt, 3)
                let tip = k * (64 + 66 * le)
                let len = k * 36 * (1 - min(1, max(0, (el - 0.22) / 0.48)))
                Path { path in
                    path.move(to: CGPoint(x: cos(a) * tip, y: sin(a) * tip * 0.82))
                    path.addLine(to: CGPoint(x: cos(a) * (tip - len), y: sin(a) * (tip - len) * 0.82))
                }
                .stroke(i % 2 == 0 ? Palette.ink : Palette.red, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .frame(width: 0, height: 0)
                .opacity(len > 0.5 ? 1 : 0)
            }
            ForEach(0..<10, id: \.self) { i in                       // 粒子
                let a = Double(i) / 10 * 2 * .pi + 0.31
                let pt = min(1, el / 0.72), pe = 1 - pow(1 - pt, 3)
                let d = k * (58 + 92 * pe)
                let r = 8 - 3.2 * pt
                Circle().fill(i % 2 == 0 ? Palette.red : Palette.ink)
                    .frame(width: r * 2, height: r * 2)
                    .offset(x: cos(a) * d * 1.45, y: sin(a) * d * 0.78)
                    .opacity(1 - min(1, max(0, (el - 0.3) / 0.42)))
            }
        }
        .position(to)
    }
}

// Motion Prompt #040 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#040
/// 定格的标记（Motion Prompt #040）：原版是蓝边框、暂停符号和「FREEZE」，0.12 秒淡入淡出。
/// 这里换成电影式的上下墨色黑边（0.12 秒滑进来），成语像盖章一样砸在下面的黑边上。
struct FreezeFrameMark: View {
    let caption: String?
    @State private var shown: String?
    @State private var stamp = false

    var body: some View {
        GeometryReader { g in
            let bar = g.size.height * 0.13
            ZStack {
                VStack(spacing: 0) {
                    Palette.ink.frame(height: bar).offset(y: shown == nil ? -bar : 0)
                    Spacer()
                    Palette.ink.frame(height: bar).offset(y: shown == nil ? bar : 0)
                }
                if let shown {
                    Text(shown)
                        .font(Fonts.display(min(34, bar * 0.62))).foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .overlay(alignment: .bottom) { Palette.red.frame(height: 3).offset(y: 2) }
                        .scaleEffect(stamp ? 1 : 1.8)
                        .opacity(stamp ? 1 : 0)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .padding(.bottom, bar * 0.18)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: caption) { _, now in
            if let now {
                withAnimation(.easeOut(duration: 0.12)) { shown = now }
                stamp = false
                withAnimation(.spring(duration: 0.22, bounce: 0.35).delay(0.06)) { stamp = true }
            } else {
                withAnimation(.easeIn(duration: 0.12)) { shown = nil; stamp = false }
            }
        }
    }
}
