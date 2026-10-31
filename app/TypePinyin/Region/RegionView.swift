import LearningCore
import SwiftUI

/// 地区画面：长卷 + 顶栏。镜头跟着小人走；每到一站先问「挑战」还是「返回」（卡片上是这一站的对手和过场）。
/// 打赢一站小人自动走到下一站再问，输了留在原地问；走完这片地区才有小结卡片。卡片只盖住画的下半部分。
struct RegionView: View {
    @State var j: JourneyController
    @State private var cameraY: CGFloat = 0
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
                ZStack(alignment: .top) {
                    RegionScrollView(region: region, route: route, cleared: j.stationIndex, hero: hero, width: w)
                        .offset(y: -cameraY)
                        .frame(width: w, height: g.size.height, alignment: .top)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture { skipWalk() }
                    if banner {
                        Text(region.name).font(Fonts.display(44)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 28).padding(.vertical, 8)
                            .background(Color.white).overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                            .padding(.top, g.size.height * 0.32)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
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
                        ObtainVolumeView(volume: v, rank: j.rank(of: v)) { j.obtained = nil }
                            .transition(.opacity)
                    }
                    if let up = j.rankUp, j.obtained == nil {
                        RankUpView(volume: up.volume, rank: up.rank) { j.rankUp = nil }
                            .transition(.opacity)
                    }
                    RegionTopBar(j: j, region: region, route: route)
                }
                .onAppear { arrive(height: g.size.height, width: w) }
                .onChange(of: j.walkFrom) { _, from in if from != nil { walk(height: g.size.height, width: w) } }
            }
            .background(Palette.mist)
            .animation(.easeOut(duration: 0.3), value: j.pendingCard?.title)
            .animation(.easeOut(duration: 0.3), value: j.obtained)
            .animation(.easeOut(duration: 0.3), value: asking)
        }
    }

    func cameraFor(_ i: Double, count: Int, height: CGFloat, width: CGFloat) -> CGFloat {
        let p = RegionScrollView.point(i, count: count, width: width)
        return min(max(0, p.y - height * 0.62), RegionScrollView.height - height)
    }

    /// 进来时：第一次先从掌门摇到山脚、出地名横幅；然后说过场、开打。
    func arrive(height: CGFloat, width: CGFloat) {
        guard let route = j.route else { return }
        let n = route.stations.count
        hero = Double(j.stationIndex)
        let target = cameraFor(hero, count: n, height: height, width: width)
        if j.pendingCard != nil || j.walkFrom != nil {
            cameraY = cameraFor(Double(j.walkFrom ?? j.stationIndex), count: n, height: height, width: width)
            if j.walkFrom != nil { hero = Double(j.walkFrom!); walk(height: height, width: width) }
            return
        }
        if j.introPending && !fast {
            j.introPending = false
            cameraY = cameraFor(Double(n - 1), count: n, height: height, width: width)
            withAnimation(.easeOut(duration: 0.3)) { banner = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                withAnimation(.easeInOut(duration: 2.2)) { cameraY = target }
                try? await Task.sleep(for: .seconds(2.3))
                withAnimation(.easeOut(duration: 0.3)) { banner = false }
                askChallenge()
            }
        } else {
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
        busy = true
        let d = fast ? 0.01 : 2.4
        withAnimation(.easeInOut(duration: d)) {
            hero = to
            cameraY = cameraFor(to, count: n, height: height, width: width)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(d + 0.1))
            guard busy else { return }
            busy = false
            j.walkFrom = nil
            askChallenge()
        }
    }

    func skipWalk() {
        guard busy, j.route != nil else { return }
        busy = false
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
                if card.replay && card.won {
                    button("再来一场", primary: true, action: onGo)
                    button("回江湖", primary: false, action: onBack)
                } else {
                    button(card.won ? (card.finished ? "回江湖" : "接着走") : "再来一次", primary: true, action: onGo)
                    if !card.finished { button("收功", primary: false, action: onRest) }
                }
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
