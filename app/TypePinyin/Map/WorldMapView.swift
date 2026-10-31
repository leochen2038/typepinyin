import LearningCore
import ProgressStore
import SwiftUI

/// 江湖总地图：最下面初入江湖一条直路到葫芦集；往上九片地区排成四层（上卷在左、下卷在右），
/// 层间斜着连路；武林大会单独在山顶。没有推荐标记，不画玩家的小人。
struct WorldMapView: View {
    @State var j: JourneyController
    @State private var selected: String?
    @State private var fogClearing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let canvasHeight: CGFloat = 760
    /// 最下面那个点：原来的初入江湖，梦打完以后是练功房。
    static let practiceId = "chuRuJiangHu"

    var baseObtained: Bool { j.progress.volumes["base"]?.obtained == true }

    func y(_ tier: Int, height: CGFloat) -> CGFloat {
        let top: CGFloat = 70, bottom = height - 50
        return bottom - CGFloat(tier + 1) / 6 * (bottom - top)
    }

    func point(_ spot: MapSpot, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: 40 + CGFloat(spot.side) * (width - 80), y: y(spot.tier, height: height))
    }

    func spot(_ id: String) -> MapSpot? { j.content.region(id)?.map ?? j.content.place(id)?.map }

    func state(_ id: String) -> PlaceState {
        if id == Self.practiceId { return .untouched }
        if id == "wuLinDaHui" { return .locked("集齐十卷开放") }
        switch j.progress.regions[id]?.phase ?? .untouched {
        case .untouched: return .untouched
        case .inProgress: return .inProgress
        case .cleared: return .cleared(rank: j.rank(of: j.content.region(id)?.volume ?? ""))
        }
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = max(Self.canvasHeight, g.size.height - 56)
            VStack(spacing: 0) {
                topBar
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        ZStack(alignment: .topLeading) {
                            Rectangle().fill(Color(hex: 0xEFE6CF)).frame(width: w, height: h)
                            roads(width: w, height: h)
                            if !(baseObtained && j.progress.journey.fogCleared && !fogClearing) || fogClearing {
                                FogLayer(clearing: fogClearing || (baseObtained && j.progress.journey.fogCleared))
                                    .frame(width: w, height: y(0, height: h) - 40)
                            }
                            ForEach(j.content.regions) { r in
                                if r.map.tier == 0 || baseObtained {
                                    sign(id: r.id, name: r.name, hint: r.hint, icon: r.map.icon)
                                        .position(point(r.map, width: w, height: h))
                                        .id(r.id)
                                }
                            }
                            ForEach(j.content.places) { p in
                                if p.id == Self.practiceId || baseObtained {
                                    sign(id: p.id, name: p.name, hint: p.id == Self.practiceId ? "打过的词" : nil,
                                         icon: p.id == "wuLinDaHui" ? "crown" : "figure.martial.arts")
                                        .position(point(p.map, width: w, height: h))
                                }
                            }
                            if j.needsMapGuide, selected == nil, let r = j.content.region("huluji") {
                                MapGuide(name: r.name)
                                    .position(point(r.map, width: w, height: h))
                                    .allowsHitTesting(false)
                            }
                            if baseObtained && j.progress.journey.fogCleared {
                                Text("九处随你挑，点地名就能去").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.slate)
                                    .frame(width: w * 0.3)
                                    .multilineTextAlignment(.leading)
                                    .position(x: w * 0.83, y: y(0, height: h) + 6)
                            }
                        }
                        .frame(width: w, height: h)
                    }
                    .onAppear { proxy.scrollTo("huluji", anchor: .bottom) }
                    .onChange(of: selected) { _, id in
                        guard let id, let s = spot(id), point(s, width: w, height: h).y > h * 0.45 else { return }
                        withAnimation { proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.25)) }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let id = selected, let r = j.content.region(id) {
                    RegionSheet(region: r, state: state(id), stationLine: stationLine(id),
                                onGo: { selected = nil; j.enterRegion(id) }, onClose: { selected = nil })
                        .transition(.move(edge: .bottom))
                }
            }
            .animation(.easeOut(duration: 0.25), value: selected)
        }
        .background(Color(hex: 0xEFE6CF))
        .onAppear {
            clearFogIfNeeded()
            // 演示（-autoplay）：自动进下一片能走、还没拿到的地区
            if let next = j.content.regions.first(where: { $0.playable && j.progress.regions[$0.id]?.phase != .cleared }) {
                j.autoAdvance(after: 3) { jj in jj.enterRegion(next.id) }
            }
        }
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
            .accessibilityIdentifier("codex")
        }
        .padding(.horizontal, 16).frame(height: 56)
        .background(Palette.mist)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }
    }

    func sign(id: String, name: String, hint: String?, icon: String?) -> some View {
        PlaceSign(name: name, hint: hint, icon: icon == "crown" || icon == "figure.martial.arts" ? icon! : PlaceSign.symbol(icon),
                  state: state(id), selected: selected == id)
            .onTapGesture {
                if id == Self.practiceId { j.enterPractice(); return }
                guard j.content.region(id) != nil else { return }
                selected = id
            }
            .accessibilityIdentifier("place-\(id)")
    }

    func stationLine(_ id: String) -> String? {
        guard j.progress.regions[id]?.phase == .inProgress, let s = j.progress.regions[id],
              let data = s.route, let r = try? JSONDecoder().decode(Route.self, from: data) else { return nil }
        return "走到第 \(s.stationIndex + 1) 站，再走 \(max(0, r.stations.count - s.stationIndex - 1)) 站到掌门"
    }

    /// 路：各地点之间的连线；武林大会没开放时是虚线。
    func roads(width: CGFloat, height: CGFloat) -> some View {
        Canvas { ctx, _ in
            var links: [(String, String)] = []
            for r in j.content.regions { for l in r.map.links { links.append((r.id, l)) } }
            for p in j.content.places { for l in p.map.links { links.append((p.id, l)) } }
            for (a, b) in links {
                guard let sa = spot(a), let sb = spot(b) else { continue }
                if !baseObtained && (sa.tier > 0 || sb.tier > 0) { continue }
                var path = Path()
                path.move(to: point(sa, width: width, height: height))
                path.addLine(to: point(sb, width: width, height: height))
                let dashed = a == "wuLinDaHui" || b == "wuLinDaHui"
                ctx.stroke(path, with: .color(Palette.ink.opacity(0.75)),
                           style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: dashed ? [8, 8] : []))
                ctx.stroke(path, with: .color(Color(hex: 0xE6C98F)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: dashed ? [8, 8] : []))
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
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
