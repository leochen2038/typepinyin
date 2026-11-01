import LearningCore
import ProgressStore
import SwiftUI

/// 江湖总地图（云海群岛）：云顶是武林大会和十方印（集齐十卷开放）；中间九座浮岛排成 3×3，一行一本秘籍，
/// 上卷在左、下卷在右、只有一卷的书在中间；最下面是起点葫芦集；右下角的圆印是练功房（固定，不随地图动）。
/// 九座岛一直是彩色的：圆章拿到这卷秘籍画主题粒子，没拿到画灰问号；最后进去过的地区圆章红边、岛有一圈光。
/// 去过的岛右上方漂「N 张」（这一卷收了几张词卡）：还在路上是交叉的剑，拿到秘籍是红色秘籍印。岛下只写地名。
struct WorldMapView: View {
    @State var j: JourneyController
    @State private var selected: String?
    /// 弹窗里放的是哪片地区（关上后也留着，卡片停在屏幕外，下次只是移上来，不用重新插进画面）。
    @State private var sheetId: String?
    @State private var sheetUp = false
    @State private var fogClearing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let canvasHeight: CGFloat = 880   // 不求一屏放下：行距、四周宽松，能上下滚
    /// 练功房（原来的初入江湖那个点）；UI 测试按这个找。
    static let practiceId = "chuRuJiangHu"
    /// 九宫格：一行一本秘籍，上卷左、下卷右、单卷居中。
    static let grid = ["baimeitai", "yueyawan", "chaotoudao", "banshanzhen", "chuiliucun", "changfengcheng",
                       "xiaoqiaoxiang", "lvquanju", "huanghuaguan"]

    var baseObtained: Bool { j.progress.volumes["base"]?.obtained == true }
    var fogGone: Bool { baseObtained && j.progress.journey.fogCleared && !fogClearing }

    func phase(_ id: String) -> RegionPhase { j.progress.regions[id]?.phase ?? .untouched }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = max(Self.canvasHeight, g.size.height - 56)
            VStack(spacing: 0) {
                topBar
                ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .top) {
                        SkyBackground().frame(width: w, height: h)
                        if baseObtained { peak.padding(.top, 8) }
                        islands(width: w, height: h)
                        if !fogGone {
                            FogLayer(clearing: fogClearing || (baseObtained && j.progress.journey.fogCleared))
                                .frame(width: w, height: h * 0.74)
                        }
                    }
                    .frame(width: w, height: h)
                }
                .scrollBounceBehavior(.basedOnSize)
                .onAppear {                                       // 进来先看最后去过的那座岛（新玩家是葫芦集）
                    let target = baseObtained ? (j.progress.journey.lastRegion.isEmpty ? "huluji" : j.progress.journey.lastRegion) : "huluji"
                    proxy.scrollTo("isle-\(target)", anchor: .center)
                }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if j.progress.journey.openingDone {
                    PracticeSeal(count: j.cards.count) { j.enterPractice() }
                        .padding(.trailing, 14).padding(.bottom, 18)
                        .accessibilityIdentifier("place-\(Self.practiceId)")
                }
            }
            .overlay(alignment: .bottom) {
                // 卡片一直在，只上下移：原来每次插进、移走整张卡片，加上整张地图跟着动画，出现和消失都卡
                if let id = sheetId, let r = j.content.region(id) {
                    RegionSheet(region: r, phase: phase(id), stationLine: stationLine(id),
                                cards: j.cardCount(in: r.volume), total: j.cardTotal(in: r.volume),
                                onGo: { closeSheet(); j.inkTransition { j.enterRegion(id) } }, onClose: { closeSheet() })
                        .offset(y: sheetUp ? 0 : g.size.height * 0.7)
                        .allowsHitTesting(sheetUp)
                        .accessibilityHidden(!sheetUp)
                }
            }
        }
        .background(Color(hex: 0xEEF0F0))
        .onAppear {
            clearFogIfNeeded()
            // 演示（-autoplay）：自动进下一片能走、还没拿到的地区
            if let next = j.content.regions.first(where: { $0.playable && j.progress.regions[$0.id]?.phase != .cleared }) {
                j.autoAdvance(after: 3) { jj in jj.inkTransition { jj.enterRegion(next.id) } }
            }
        }
    }

    /// 九座岛 + 起点：每行高度按屏幕分，岛在格子里居中。
    func islands(width w: CGFloat, height h: CGFloat) -> some View {
        let top: CGFloat = baseObtained ? 176 : 40
        let startH: CGFloat = 160
        let rowH = max(160, (h - top - startH - 70) / 3)
        let colW = (w - 32) / 3
        return ZStack(alignment: .topLeading) {
            if baseObtained {
                ForEach(Array(Self.grid.enumerated()), id: \.element) { k, id in
                    if let r = j.content.region(id) {
                        island(r, index: k)
                            .frame(width: colW, height: rowH)
                            .position(x: 16 + colW * (CGFloat(k % 3) + 0.5), y: top + rowH * (CGFloat(k / 3) + 0.5))
                            .id("isle-\(id)")
                    }
                }
            }
            if let r = j.content.region("huluji") {
                island(r, index: 9, start: true)
                    .frame(width: colW, height: startH)
                    .position(x: w / 2, y: h - startH / 2 - 60)
                    .id("isle-huluji")
                if j.needsMapGuide, selected == nil {
                    MapGuide(name: r.name).position(x: w / 2, y: h - startH / 2 - 84).allowsHitTesting(false)
                }
                if fogGone {
                    Text("九处随你挑，点岛就能去").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.slate)
                        .frame(width: w * 0.26, alignment: .leading)
                        .position(x: w * 0.16 + 6, y: h - startH / 2 - 54)
                }
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    func island(_ r: Region, index: Int, start: Bool = false) -> some View {
        let ph = phase(r.id)
        return IslandView(region: r, phase: ph, obtained: j.progress.volumes[r.volume]?.obtained == true,
                          recent: j.progress.journey.lastRegion == r.id, count: j.cardCount(in: r.volume),
                          start: start, picked: selected == r.id, bobDelay: Double(index) * 0.7, reduceMotion: reduceMotion)
            .contentShape(Rectangle())
            .onTapGesture { openSheet(r.id) }
            .accessibilityIdentifier("place-\(r.id)")
    }

    /// 云顶：武林大会，下面十方印（拿到一卷盖一个）。
    var peak: some View {
        let order = ["huluji", "baimeitai", "chaotoudao", "banshanzhen", "changfengcheng", "yueyawan", "chuiliucun", "lvquanju", "xiaoqiaoxiang", "huanghuaguan"]
        let got = order.filter { id in j.content.region(id).map { j.progress.volumes[$0.volume]?.obtained == true } ?? false }
        return VStack(spacing: 3) {
            PeakArt(open: got.count == order.count).frame(width: 170, height: 78)
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
            Text(got.count == order.count ? "十卷集齐 · 武林大会开放" : "已集 \(got.count) 卷 · 集齐十卷开放")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(got.count == order.count ? Palette.red : Palette.slate)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("place-wuLinDaHui")
    }

    var topBar: some View {
        HStack {
            Text("江湖").font(Fonts.display(26))
                .overlay(PanelGesture { j.showPanel = true })
            Spacer()
            Button { j.screen = .codex } label: {
                Text("秘籍").font(.system(size: 16, weight: .black)).foregroundStyle(Palette.ink)
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

    func stationLine(_ id: String) -> String? {
        guard j.progress.regions[id]?.phase == .inProgress, let s = j.progress.regions[id],
              let data = s.route, let r = try? JSONDecoder().decode(Route.self, from: data) else { return nil }
        return "走到第 \(s.stationIndex + 1) 站，再走 \(max(0, r.stations.count - s.stationIndex - 1)) 站到掌门"
    }

    /// 拿到《基本功》后第一次回地图：云雾一起散开（只演一次）。
    func clearFogIfNeeded() {
        guard baseObtained, !j.progress.journey.fogCleared else { return }
        let d = reduceMotion || JourneyFlags.fast ? 0.2 : 1.6
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeInOut(duration: d)) { fogClearing = true }
            try? await Task.sleep(for: .seconds(d))
            var jj = j.progress.journey
            jj.fogCleared = true
            var ch = ProgressChange()
            ch.journey = jj
            j.save(ch)
            fogClearing = false
        }
    }
}

/// 梦醒后第一次到地图：葫芦集外面一圈慢慢扩散的金色光圈，上面一句「点这里」（只出现一次）。
struct MapGuide: View {
    let name: String
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(Palette.gold, lineWidth: 4)
                .frame(width: 96, height: 96)
                .scaleEffect(pulse ? 1.25 : 0.9)
                .opacity(pulse ? 0 : 0.9)
            Circle().stroke(Palette.gold, lineWidth: 3)
                .frame(width: 96, height: 96)
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
            .offset(y: -84)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
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
