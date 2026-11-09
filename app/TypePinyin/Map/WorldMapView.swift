import LearningCore
import ProgressStore
import SwiftUI

/// 江湖总地图：十座岛按闯关的顺序从下往上一座一层、左右交替，按顺序解锁，没解锁的灰；最上面是武林大会和十方印（拿到一卷盖一个），
/// 走完最后一座岛开放；右下角的圆印是练习场（固定，不随地图动）。最后进去过的岛红边、有一圈光；去过的岛右上方漂「N 张」。
/// （2026-11-09 去掉了原来的九宫格加云雾那一版。）
struct WorldMapView: View {
    @State var j: JourneyController
    @State private var selected: String?
    /// 弹窗里放的是哪片地区（关上后也留着，卡片停在屏幕外，下次只是移上来，不用重新插进画面）。
    @State private var sheetId: String?
    @State private var sheetUp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 练习场（原来的初入江湖那个点）；UI 测试按这个找。
    static let practiceId = "chuRuJiangHu"

    /// 调参面板「新画法（场景）」：浮岛、云顶、天空跟长卷一起换。
    var newArt: Bool { j.duel.tuning.artStyle == 1 }

    func phase(_ id: String) -> RegionPhase { j.progress.regions[id]?.phase ?? .untouched }
    @State private var lockedNote: String?

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = pathHeight(pathOrder.count)
            VStack(spacing: 0) {
                topBar
                ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .top) {
                        SkyBackground(flat: newArt).frame(width: w, height: h)
                        pathIslands(width: w)
                    }
                    .frame(width: w, height: h)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onAppear {                                       // 先看现在该去的那座岛（等排好版再滚）
                    let target = frontier
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(60))
                        proxy.scrollTo("isle-\(target)", anchor: .center)
                    }
                }
                }
            }
            .overlay(alignment: .top) {
                if let note = lockedNote {
                    Text(note).font(.system(size: 15, weight: .black)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Palette.gold).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2.5))
                        .padding(.top, 68)
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if j.progress.journey.openingDone {
                    PracticeSeal(count: j.cards.count, useArt: newArt) { j.enterPractice() }
                        .padding(.trailing, 14).padding(.bottom, 18)
                        .accessibilityIdentifier("place-\(Self.practiceId)")
                }
            }
            .overlay(alignment: .bottom) {
                // 卡片一直在，只上下移：原来每次插进、移走整张卡片，加上整张地图跟着动画，出现和消失都卡
                if let id = sheetId, let r = j.content.region(id) {
                    RegionSheet(region: r, phase: phase(id), stationLine: stationLine(id),
                                cards: j.cardCount(in: r.volume), total: j.cardTotal(in: r.volume),
                                onGo: { closeSheet(); j.inkTransition { j.enterRegion(id) } }, onClose: { closeSheet() },
                                onRestart: { closeSheet(); j.inkTransition { j.restartRegion(id) } })
                        .frame(maxHeight: .infinity, alignment: .bottom)   // 和请帖同时在时也贴底，不跑到屏幕中间
                        .offset(y: sheetUp ? 0 : g.size.height)
                        .allowsHitTesting(sheetUp)
                        .accessibilityHidden(!sheetUp)
                }
                if j.showInvitation, let g = j.content.gathering {      // 走完最后一座岛：妙笔书生的请帖
                    InvitationView(text: g.invitation, signature: g.signature,
                                   onGo: { j.inkTransition { j.enterGathering() } },
                                   onLater: { withAnimation(.easeIn(duration: 0.2)) { j.markInvitationSeen() } })
                        .transition(.opacity)
                }
            }
        }
        .background(newArt ? SkyBackground.flatSky : Color(hex: 0xEEF0F0))
        .onAppear {
            if j.invitationPending {
                Task { @MainActor in                               // 地图先露一下，请帖再落下来
                    try? await Task.sleep(for: .seconds(0.5))
                    withAnimation(.easeOut(duration: 0.25)) { j.showInvitation = true }
                }
            }
            // 演示（-autoplay）：自动进下一片能走、还没拿到的地区；都走完了就上山
            if let next = j.content.regions.first(where: { $0.playable && j.progress.regions[$0.id]?.phase != .cleared }) {
                j.autoAdvance(after: 3) { jj in jj.inkTransition { jj.enterRegion(next.id) } }
            } else if j.gatheringOpen && !j.gatheringWon {
                j.autoAdvance(after: 3) { jj in jj.inkTransition { jj.enterGathering() } }
            }
        }
    }

    func island(_ r: Region, index: Int, start: Bool = false, locked: Bool = false, maxScale: CGFloat = 1.3, after: String? = nil) -> some View {
        let ph = phase(r.id)
        return IslandView(region: r, phase: ph, obtained: j.progress.volumes[r.volume]?.obtained == true,
                          recent: j.progress.journey.lastRegion == r.id, count: j.cardCount(in: r.volume),
                          start: start, picked: selected == r.id, bobDelay: Double(index) * 0.7, reduceMotion: reduceMotion, useArt: newArt,
                          locked: locked, maxScale: maxScale)
            .contentShape(Rectangle())
            .onTapGesture {
                if locked { showLockedNote("走完「\(after ?? "")」就能去") } else { openSheet(r.id) }
            }
            .accessibilityIdentifier("place-\(r.id)")
    }

    // MARK: 一座一层

    /// 十座岛按学习顺序（内容里地区的顺序）从下往上，一座一层、左右交替；最上面是武林大会。
    var pathOrder: [Region] { j.content.regions.filter(\.playable) }
    static let levelStep: CGFloat = 176
    static let pathTop: CGFloat = 250                    // 云顶（武林大会和十方印）占的高度
    static let pathBottom: CGFloat = 46                  // 葫芦集下面到云海的空（原来 96，离云太远）
    func pathHeight(_ n: Int) -> CGFloat { Self.pathTop + Self.levelStep * CGFloat(n) + Self.pathBottom }
    func pathPoint(_ i: Int, count n: Int, width w: CGFloat) -> CGPoint {
        let y = pathHeight(n) - Self.pathBottom - Self.levelStep * (CGFloat(i) + 0.5)
        return CGPoint(x: i == 0 ? w / 2 : (i % 2 == 1 ? w * 0.3 : w * 0.7), y: y)
    }

    /// 按顺序解锁：第一座一开始就开；前一座走完（或拿到它的秘籍）开下一座；已经进去过的照样开着。
    func unlocked(_ i: Int, _ order: [Region]) -> Bool {
        if i == 0 { return true }
        let prev = order[i - 1], me = order[i]
        return phase(prev.id) == .cleared || j.progress.volumes[prev.volume]?.obtained == true
            || phase(me.id) != .untouched || j.progress.volumes[me.volume]?.obtained == true
    }

    /// 现在该去的那座：第一座开着、还没走完的；全走完了就是最后一座。
    var frontier: String {
        let order = pathOrder
        return order.indices.first { unlocked($0, order) && phase(order[$0].id) != .cleared && !sealed(order[$0].id) }
            .map { order[$0].id } ?? order.last?.id ?? "huluji"
    }

    func pathIslands(width w: CGFloat) -> some View {
        let order = pathOrder
        let n = order.count
        let peakAt = CGPoint(x: w / 2, y: 112)
        // 每座岛占一整行，按正常排版从上往下排（最上面是武林大会）：行有真实的位置，滚到某座岛才准
        return VStack(spacing: 0) {
            peak.position(peakAt).frame(width: w, height: Self.pathTop)
            ForEach(Array(order.indices.reversed()), id: \.self) { i in
                let r = order[i]
                let p = pathPoint(i, count: n, width: w)
                ZStack {
                    island(r, index: i, start: i == 0, locked: !unlocked(i, order), maxScale: 1.3, after: i > 0 ? order[i - 1].name : nil)
                        .frame(width: 176, height: 164)
                        .position(x: p.x, y: Self.levelStep / 2)
                    if i == 0, j.needsMapGuide, selected == nil {
                        MapGuide(name: r.name).position(x: p.x, y: Self.levelStep / 2 - 18).allowsHitTesting(false)
                    }
                }
                .frame(width: w, height: Self.levelStep)
                .id("isle-\(r.id)")
            }
            Color.clear.frame(width: w, height: Self.pathBottom)
        }
        .frame(width: w, height: pathHeight(n))
        .background {
            Canvas { ctx, _ in                                    // 路：走过的墨色，还没到的淡灰，虚线
                var pts = order.indices.map { pathPoint($0, count: n, width: w) }
                pts.append(CGPoint(x: peakAt.x, y: peakAt.y + 60))
                for k in 0..<(pts.count - 1) {
                    let a = CGPoint(x: pts[k].x, y: pts[k].y + 10), b = CGPoint(x: pts[k + 1].x, y: pts[k + 1].y + 10)
                    var path = Path()
                    path.move(to: a)
                    path.addCurve(to: b, control1: CGPoint(x: a.x, y: (a.y + b.y) / 2), control2: CGPoint(x: b.x, y: (a.y + b.y) / 2))
                    let walked = k + 1 < n ? unlocked(k + 1, order) : j.gatheringOpen
                    ctx.stroke(path, with: .color(walked ? Palette.ink : Palette.faint), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 7]))
                }
            }
            .allowsHitTesting(false)
        }
    }

    func showLockedNote(_ text: String) {
        withAnimation(.easeOut(duration: 0.15)) { lockedNote = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            if lockedNote == text { withAnimation(.easeIn(duration: 0.25)) { lockedNote = nil } }
        }
    }

    func sealed(_ id: String) -> Bool { j.content.region(id).map { j.progress.volumes[$0.volume]?.obtained == true } ?? false }

    /// 云顶：武林大会，下面十方印（按闯关的顺序，拿到一卷盖一个）；开放了点进去上山，没开放提示走完哪座岛。
    var peak: some View {
        let order = pathOrder.map(\.id)
        let got = order.filter(sealed)
        return VStack(spacing: 3) {
            Group {
                if newArt {
                    Image(j.gatheringOpen ? "peak-open" : "peak-closed").resizable().frame(width: 170, height: 89)
                } else {
                    PeakArt(open: j.gatheringOpen).frame(width: 170, height: 78)
                }
            }
            Text("武林大会").font(Fonts.display(22))
            HStack(spacing: 4) {
                ForEach(order, id: \.self) { id in
                    let on = got.contains(id)
                    Text(String(j.content.region(id)?.name.prefix(1) ?? "")).font(Fonts.display(13))
                        .foregroundStyle(on ? .white : Palette.faint)
                        .frame(width: 23, height: 23)
                        .background(on ? Palette.red : Color.white.opacity(0.5))
                        .overlay(Rectangle().stroke(on ? Color(hex: 0x8F1F12) : Palette.faint, style: StrokeStyle(lineWidth: 1.5, dash: on ? [] : [3, 2])))
                        .rotationEffect(.degrees(on ? -4 : 0))
                }
            }
            Text(peakCaption)
                .font(.system(size: 12, weight: .bold)).foregroundStyle(j.gatheringOpen ? Palette.red : Palette.slate)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            closeSheet()
            if j.gatheringOpen { j.enterGathering() }               // 走完最后一座岛：上山
            else { showLockedNote("走完「\(pathOrder.last?.name ?? "")」就能去") }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("place-wuLinDaHui")
    }

    /// 云顶下面的一行字：当选了是「武林盟主」，开放了是「上山去」，没开放写「走完十座岛开放」。
    var peakCaption: String {
        if j.crowned { return "武林盟主" }
        return j.gatheringOpen ? "上山去" : "走完十座岛开放"
    }

    var topBar: some View {
        HStack {
            Text("江湖").font(Fonts.display(26))
                .overlay(PanelGesture { j.showPanel = true })
            Spacer()
            Button { j.screen = .codex } label: {
                Text("收获").font(.system(size: 16, weight: .black)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.white).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .overlay { if !j.booksToUnveil.isEmpty { NewBookPulse() } }
            .overlay(alignment: .topTrailing) { if !j.booksToUnveil.isEmpty { NewDot().offset(x: 7, y: -7) } }
            .accessibilityIdentifier("codex")
        }
        .padding(.horizontal, 16).frame(height: 56)
        .background(Palette.mist)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }
    }

    func openSheet(_ id: String) {
        selected = id
        if sheetId == id || sheetUp {
            sheetId = id
            withAnimation(Self.sheetSpring) { sheetUp = true }
        } else {
            sheetId = id                                      // 先在屏幕外放好，下一帧再移上来
            DispatchQueue.main.async { withAnimation(Self.sheetSpring) { sheetUp = true } }
        }
    }

    func closeSheet() {
        selected = nil
        withAnimation(.easeIn(duration: 0.22)) { sheetUp = false }
    }

    static let sheetSpring = Animation.spring(duration: 0.32, bounce: 0.12)

    /// 这一趟走到哪了：第一次挑战中，或通关后再去一趟走了一半（已经打过至少一站）。
    func stationLine(_ id: String) -> String? {
        guard let s = j.progress.regions[id], s.phase == .inProgress || s.stationIndex > 0,
              let data = s.route, let r = try? JSONDecoder().decode(Route.self, from: data), r.stations.count > 1 else { return nil }
        return "走到第 \(s.stationIndex + 1) 站，再走 \(max(0, r.stations.count - s.stationIndex - 1)) 站到掌门"
    }
}

/// 梦醒后第一次到地图：葫芦集上方一块「点这里」的提示牌，箭头指着岛，轻轻上下浮（只出现一次）。
/// 原来岛外面还有一圈慢慢扩散的金色光圈，看着就是个黄圈、不好看，去掉了；只剩这一座岛是彩色的，指一下就够。
struct MapGuide: View {
    let name: String
    @State private var bob = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Text("点「\(name)」，开始第一关")
                .font(.system(size: 16, weight: .black)).foregroundStyle(Palette.ink)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Palette.gold)
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                .compositingGroup().shadow(color: Palette.ink, radius: 0, x: 3, y: 3)
            Image(systemName: "arrowtriangle.down.fill").font(.system(size: 16)).foregroundStyle(Palette.ink)
                .offset(y: -2)
        }
        .fixedSize()
        .offset(y: -84 + (bob ? -6 : 0))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { bob = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mapGuide")
    }
}

/// 拿到新秘籍、还没去看：「秘籍」按钮外一圈朱红往外扩。
struct NewBookPulse: View {
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Rectangle().stroke(Palette.red, lineWidth: 2)
            .scaleEffect(on ? 1.35 : 1)
            .opacity(on ? 0 : 0.9)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) { on = true }
            }
    }
}
