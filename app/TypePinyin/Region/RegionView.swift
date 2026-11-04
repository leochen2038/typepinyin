import LearningCore
import SwiftUI

/// 地区画面：长卷 + 顶栏。镜头跟着小人走；每到一站先问「挑战」还是「返回」（卡片上是这一站的对手和过场）。
/// 打赢一站小人自动走到下一站再问，输了留在原地问；走完这片地区才有小结卡片。卡片只盖住画的下半部分。
struct RegionView: View {
    @State var j: JourneyController
    @State private var cameraY: CGFloat = 0
    /// 手指拖长卷时，按下那一刻的镜头位置。
    @State private var dragFrom: CGFloat?
    @State private var hero: Double = 0
    @State private var asking = false
    @State private var banner = false
    @State private var busy = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var fast: Bool { JourneyFlags.fast || reduceMotion }

    var body: some View {
        if let region = j.currentRegion, let route = j.route {
            GeometryReader { g in
                let w = g.size.width
                // 长卷画到屏幕最底下（盖住底部安全区），卡片仍停在安全区以内；镜头按看得见的整段高度算
                let viewH = g.size.height + g.safeAreaInsets.bottom
                ZStack(alignment: .top) {
                    Color.clear
                    if banner {
                        // Motion Prompt #183 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#183
                        // 定场镜头的地名卡：左下角一张白卡，左边一道色条，淡入时往上走 8 点，然后一直留着
                        HStack(spacing: 10) {
                            Rectangle().fill(Palette.red).frame(width: 6)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(region.name).font(Fonts.display(34)).foregroundStyle(Palette.ink)
                                Text(Volumes.name(region.volume)).font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.slate)
                            }
                            .padding(.vertical, 6).padding(.trailing, 16)
                        }
                        .fixedSize()
                        .background(Color.white).overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(.leading, 16).padding(.bottom, 40)
                        .transition(.opacity.combined(with: .offset(y: 8)))
                    }
                    if asking, j.pendingCard == nil, j.obtained == nil, j.rankUp == nil, let st = j.currentStation {
                        VStack {
                            Spacer()
                            StationCard(station: st, index: j.stationIndex, count: route.stations.count, last: j.lastResult,
                                        onGo: { asking = false; j.challenge() }, onBack: { asking = false; j.leaveRegion() })
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if let card = j.pendingCard, j.obtained == nil, j.rankUp == nil {
                        VStack {
                            Spacer()
                            RegionCard(card: card, onGo: { j.continueRoute() }, onRest: { j.harvest() }, onBack: { j.pendingCard = nil; j.screen = .map })
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if let v = j.obtained {
                        ObtainVolumeView(volume: v, rank: j.rank(of: v), boss: region.boss.defeatLine.map { (region.boss.name, $0) }) { j.obtained = nil }
                            .transition(.opacity)
                    }
                    if let up = j.rankUp, j.obtained == nil {
                        RankUpView(volume: up.volume, rank: up.rank) { j.rankUp = nil }
                            .transition(.opacity)
                    }
                    RegionTopBar(j: j, region: region, route: route)
                }
                .background(alignment: .top) {
                    RegionScrollView(region: region, route: route, cleared: j.stationIndex, hero: hero, width: w, scene: scene(region), walking: busy)
                        .modifier(CameraFollow(t: hero, still: cameraY, following: busy,
                                               camera: { cameraFor($0, count: route.stations.count, height: viewH, width: w) }))
                        .frame(width: w, height: viewH, alignment: .top)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { skipWalk() }
                        .gesture(scrollDrag(viewH: viewH))
                }
                .onAppear { arrive(height: viewH, width: w) }
                .onChange(of: j.walkFrom) { _, from in if from != nil { walk(height: viewH, width: w) } }
                .onChange(of: j.debugJumpTick) { _, _ in
                    busy = false
                    banner = false
                    arrive(height: viewH, width: w)
                }
            }
            .background(Palette.mist)
            .animation(.easeOut(duration: 0.3), value: j.pendingCard?.title)
            .animation(.easeOut(duration: 0.3), value: j.obtained)
            .animation(.easeOut(duration: 0.3), value: asking)
        }
    }

    /// 上下拖长卷看前后的站；松手按手速再滑一段。走路、开场摇镜头时不让拖，走到下一站镜头自己跟回小人。
    func scrollDrag(viewH: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard !busy, !banner else { return }
                let from = dragFrom ?? cameraY
                dragFrom = from
                cameraY = min(max(0, from - v.translation.height), RegionScrollView.height - viewH)
            }
            .onEnded { v in
                guard let from = dragFrom else { return }
                dragFrom = nil
                let end = min(max(0, from - v.predictedEndTranslation.height), RegionScrollView.height - viewH)
                withAnimation(.easeOut(duration: 0.45)) { cameraY = end }
            }
    }

    /// 正式美术的场景：新画法打开、这片地区画好了才有。
    func scene(_ region: Region) -> RegionScene? {
        j.duel.tuning.artStyle == 1 ? RegionScenes.scene(for: region.id) : nil
    }

    func cameraFor(_ i: Double, count: Int, height: CGFloat, width: CGFloat) -> CGFloat {
        let p = RegionScrollView.point(i, count: count, width: width, scene: j.currentRegion.flatMap(scene))
        return min(max(0, p.y - height * 0.67), RegionScrollView.height - height)   // 小人站在站前卡片上沿的正上方
    }

    /// 进来时：第一次先从掌门摇到山脚、出地名横幅；然后说过场、开打。
    func arrive(height: CGFloat, width: CGFloat) {
        guard let route = j.route else { return }
        let n = route.stations.count
        hero = Double(j.stationIndex)
        let target = cameraFor(hero, count: n, height: height, width: width)
        if j.introPending && !fast {                            // 第一次来：镜头从掌门落到山脚、地名卡，再看主角从山脚走上来
            j.introPending = false
            let start = Double(j.walkFrom ?? j.stationIndex)
            hero = start
            cameraY = cameraFor(Double(n - 1), count: n, height: height, width: width)
            Task { @MainActor in
                // Motion Prompt #169 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#169
                // 升降（这里往下落）：镜头不转向，垂直平移；先停 0.5 秒，2.9 秒，三次方缓入缓出（cubic-bezier 0.65, 0, 0.35, 1）
                try? await Task.sleep(for: .seconds(0.5))
                withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 2.9)) { cameraY = cameraFor(start, count: n, height: height, width: width) }
                try? await Task.sleep(for: .seconds(0.4))                // #183：0.9 秒时地名卡开始淡入，0.4 秒
                withAnimation(.easeOut(duration: 0.4)) { banner = true }
                try? await Task.sleep(for: .seconds(2.6))                // 镜头落定（3.4 秒）再停一下
                if j.walkFrom != nil { walk(height: height, width: width) } else { hideBanner(); askChallenge() }
            }
            return
        }
        if j.pendingCard != nil || j.walkFrom != nil {
            j.introPending = false
            cameraY = cameraFor(Double(j.walkFrom ?? j.stationIndex), count: n, height: height, width: width)
            if j.walkFrom != nil { hero = Double(j.walkFrom!); walk(height: height, width: width) }
            return
        }
        do {
            j.introPending = false
            cameraY = target
            askChallenge()
        }
    }

    /// 接着走：画面跟着小人走到下一站（两三秒，点一下跳过）。
    func walk(height: CGFloat, width: CGFloat) {
        guard let from = j.walkFrom, let route = j.route else { return }
        let n = route.stations.count
        let to = Double(j.stationIndex)
        hero = Double(from)
        cameraY = cameraFor(Double(from), count: n, height: height, width: width)
        busy = true
        // 走多久按路有多长：慢慢走，看得到主角赶路（约每秒 70 点，2.4–6 秒，点一下可以跳过）
        let a = RegionScrollView.point(Double(from), count: n, width: width, scene: j.currentRegion.flatMap(scene))
        let b = RegionScrollView.point(to, count: n, width: width, scene: j.currentRegion.flatMap(scene))
        let d = fast ? 0.01 : min(6, max(2.4, Double(hypot(b.x - a.x, b.y - a.y)) * 1.15 / 70))
        // Motion Prompt #029 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#029
        // 跟拍：镜头和主角同速、匀速不缓动，主角始终在画面里同一个位置（镜头按主角每一帧的位置算，见 CameraFollow）
        withAnimation(.linear(duration: d)) { hero = to }
        cameraY = cameraFor(to, count: n, height: height, width: width)   // 走完停在这里（走的时候不用它）
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(d + 0.1))
            guard busy else { return }
            busy = false
            j.walkFrom = nil
            hideBanner()
            askChallenge()
        }
    }

    func hideBanner() {
        guard banner else { return }
        withAnimation(.easeOut(duration: 0.3)) { banner = false }
    }

    func skipWalk() {
        guard busy, j.route != nil else { return }
        busy = false
        hideBanner()
        withAnimation(.easeOut(duration: 0.15)) { hero = Double(j.stationIndex) }
        j.walkFrom = nil
        askChallenge()
    }

    /// 到了一站：问挑战还是返回。
    func askChallenge() {
        guard j.pendingCard == nil, j.currentStation != nil else { return }
        asking = true
        j.autoAdvance(after: 2) { jj in
            guard asking else { return }
            asking = false
            jj.challenge()
        }
    }
}

/// 站前的卡片：上一站的结果（有的话）、这一站是谁、过场一句，「挑战」或「返回」。
struct StationCard: View {
    let station: Station
    /// 第几站 / 共几站；练功房没有站数，传 nil。
    let index: Int?
    let count: Int
    let last: JourneyController.PendingCard?
    let onGo: () -> Void
    let onBack: () -> Void

    var heading: String {
        let name = station.foe?.name ?? ""
        switch station.kind {
        case .duel: return name
        case .group: return station.groupSize.map { "\($0) 人群战 · \(name)领头" } ?? "群战 · \(name)一伙"
        case .boss: return "掌门 · \(name)"
        case .encounter: return "奇遇"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let last {
                HStack(spacing: 8) {
                    Text(last.title).font(.system(size: 15, weight: .black))
                    if let g = last.gains.first { Text(g).font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.slate) }
                }
                .lineLimit(1).minimumScaleFactor(0.8)
                Rectangle().fill(Palette.ink.opacity(0.15)).frame(height: 1)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(heading).font(Fonts.display(26))
                Spacer()
                if let index {
                    Text("第 \(index + 1) / \(count) 站").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.slate)
                }
            }
            Text(station.line).font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("stationLine")
            HStack(spacing: 12) {
                RegionCard.button(station.kind == .encounter ? "去看看" : "挑战", primary: true, action: onGo)
                RegionCard.button("返回", primary: false, action: onBack)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        .compositingGroup()
        .shadow(color: Palette.ink, radius: 0, x: 6, y: 6)
        .padding(.horizontal, 16).padding(.bottom, 24)
    }
}

/// 走完一片地区（或通关后随机一场）的小结卡片（只盖住下半部分）。
struct RegionCard: View {
    let card: JourneyController.PendingCard
    let onGo: () -> Void
    let onRest: () -> Void
    var onBack: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(card.title).font(Fonts.display(28))
            if !card.won {
                Text("差一点，换个打法再试试").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.slate)
            }
            ForEach(card.gains + summaryGains, id: \.self) { g in
                HStack(spacing: 8) {
                    Rectangle().fill(Palette.gold).frame(width: 9, height: 9).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                    Text(g).font(.system(size: 16, weight: .bold))
                }
            }
            HStack(spacing: 12) {
                button(card.won ? (card.finished ? "回江湖" : "接着走") : "再来一次", primary: true, action: onGo)
                if !card.finished { button("收功", primary: false, action: onRest) }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        .compositingGroup()
        .shadow(color: Palette.ink, radius: 0, x: 6, y: 6)
        .padding(.horizontal, 16).padding(.bottom, 24)
    }

    var summaryGains: [String] {
        guard let s = card.summary, card.won else { return [] }
        var g: [String] = []
        if s.goldMoves > 0 { g.append("打出 \(s.goldMoves) 招完美") }
        if s.maxCombo > 1 { g.append("最高 \(s.maxCombo) 连") }
        return g
    }

    func button(_ label: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Self.button(label, primary: primary, action: action)
    }

    static func button(_ label: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(Fonts.display(22)).frame(maxWidth: .infinity).frame(height: 50)
                .background(primary ? Palette.gold : Color.white).foregroundStyle(Palette.ink)
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                .compositingGroup().shadow(color: Palette.ink, radius: 0, x: 3, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(label)
    }
}

/// 长卷的镜头：平时停在 still（拖动、进场摇镜头都改它）；主角走路时跟着主角每一帧的位置走（跟拍，见 RegionView.walk）。
struct CameraFollow: ViewModifier, @preconcurrency Animatable {
    var t: Double
    var still: CGFloat
    let following: Bool
    let camera: (Double) -> CGFloat
    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(t, still) }
        set { t = newValue.first; still = newValue.second }
    }

    func body(content: Content) -> some View {
        content.offset(y: -(following ? camera(t) : still))
    }
}
