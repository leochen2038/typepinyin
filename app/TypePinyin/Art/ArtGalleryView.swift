import LearningCore
import SwiftUI

/// 画廊页（开发用，启动参数 -artGallery）：每片地区的长卷和比武背景缩略图，下面是所有人物（原来的画法，可切剪影）。
struct ArtGalleryView: View {
    let content: LearningContent
    @State private var silhouette = false

    struct Entry: Identifiable { let id: String; let name: String; let look: Look }

    /// 启动参数 -artGallery 后面可以跟地区 id，只看这一片（模拟器里不好滚动时用）。
    var only: String? {
        let a = ProcessInfo.processInfo.arguments
        guard let k = a.firstIndex(of: "-artGallery"), k + 1 < a.count, !a[k + 1].hasPrefix("-") else { return nil }
        return a[k + 1]
    }

    var regions: [Region] { content.regions.filter { only == nil || $0.id == only } }

    var groups: [(String, [Entry])] {
        var out: [(String, [Entry])] = []
        for r in regions {
            let cast = [r.boss] + r.foes
            out.append((r.name, cast.map { Entry(id: "\(r.id)-\($0.name)", name: $0.name, look: $0.look) }))
        }
        var dream: [Entry] = []
        if let b = content.dream?.boss { dream.append(Entry(id: "dream-\(b.name)", name: b.name, look: b.look)) }
        for p in content.places { for f in p.foes ?? [] { dream.append(Entry(id: "open-\(f.name)", name: f.name, look: f.look)) } }
        if only == nil || only == "dream" { out.append(("梦里和初入江湖", dream)) }
        return out
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Toggle("剪影", isOn: $silhouette).padding(.horizontal)
                ForEach(regions.filter { RegionScenes.scene(for: $0.id) != nil }, id: \.id) { r in
                    let scene = RegionScenes.scene(for: r.id)!
                    let theme = RegionTheme.of(r.id)
                    Text("\(r.name) · 长卷和比武背景").font(Fonts.display(20)).padding(.horizontal)
                    HStack(alignment: .top, spacing: 10) {
                        Image(uiImage: SceneRenderer.scroll(regionId: r.id, scene: scene, theme: theme, width: 393))
                            .resizable().scaledToFit().frame(width: 150)
                        Image(uiImage: SceneRenderer.duel(regionId: r.id, scene: scene, theme: theme))
                            .resizable().scaledToFit()
                    }
                    .padding(.horizontal)
                }
                Text("主角").font(Fonts.display(20)).padding(.horizontal)
                HStack(alignment: .bottom, spacing: 12) {                // 战斗姿势（比武）、赶路的三帧（长卷：站、迈步、迈另一只脚）
                    Image(uiImage: FigureArt.image(FigureArt.player(), height: 170, silhouette: silhouette))
                    ForEach(0..<3) { k in Image(uiImage: FigureArt.image(FigureArt.playerTravel(step: k), height: 170, silhouette: silhouette)) }
                }
                .padding(.horizontal)
                HStack(alignment: .bottom, spacing: 40) {                // 长卷上走路的小人放大：站着、两腿摆到最开的两帧
                    ForEach([0, Double.pi / 16, 3 * Double.pi / 16], id: \.self) { t in
                        WalkingHero(t: t).scaleEffect(3, anchor: .bottom).frame(height: 160, alignment: .bottom)
                    }
                    Image(uiImage: FigureArt.image(FigureArt.guardsman(robe: UIColor(hex: 0xE2432C)), height: 170, silhouette: silhouette))
                }
                .padding(.horizontal, 60)
                ForEach(groups, id: \.0) { name, entries in
                    Text(name).font(Fonts.display(20)).padding(.horizontal)
                    ScrollView(.horizontal) {
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(entries) { e in
                                VStack(spacing: 2) {
                                    Image(uiImage: FigureArt.image(FigureArt.guardsman(robe: UIColor(hexString: e.look.robe)), height: 170, silhouette: silhouette))
                                    Text(e.name).font(.system(size: 12, weight: .bold))
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color.white)
        .onAppear { exportScrolls() }
    }

    /// 开发用：启动参数 -exportScrolls 把有新场景的地区长卷（连雾那一层）和比武背景存成 PNG（App 的 Documents 里），对照效果图用。
    func exportScrolls() {
        guard ProcessInfo.processInfo.arguments.contains("-exportScrolls"),
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        for r in regions {
            guard let scene = RegionScenes.scene(for: r.id) else { continue }
            let img = SceneRenderer.scroll(regionId: r.id, scene: scene, theme: RegionTheme.of(r.id), width: 393)
            let mist = SceneRenderer.mist(regionId: r.id, scene: scene, width: 393)
            let format = UIGraphicsImageRendererFormat()
            format.scale = img.scale
            format.opaque = true
            let out = UIGraphicsImageRenderer(size: img.size, format: format).image { _ in      // 长卷和雾那一层合成一张（和 App 里看到的一样）
                img.draw(at: .zero)
                mist?.draw(at: CGPoint(x: -SceneRenderer.mistPad, y: 0))
            }
            try? out.pngData()?.write(to: dir.appendingPathComponent("scroll-\(r.id).png"))
            try? SceneRenderer.duel(regionId: r.id, scene: scene, theme: RegionTheme.of(r.id)).pngData()?.write(to: dir.appendingPathComponent("duel-\(r.id).png"))
        }
        // 人物的画法参考（给 AI 出场景图时对照）：主角战斗、赶路，两个对手，白底排一排
        let figures = [FigureArt.player(), FigureArt.playerTravel(step: 0), FigureArt.guardsman(robe: UIColor(hex: 0xE2432C)), FigureArt.guardsman(robe: UIColor(hex: 0x3B6EA8))]
            .map { FigureArt.image($0, height: 300) }
        let size = CGSize(width: figures.reduce(40) { $0 + $1.size.width + 40 }, height: 380)
        let sheet = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            var x: CGFloat = 40
            for f in figures { f.draw(at: CGPoint(x: x, y: 40)); x += f.size.width + 40 }
        }
        try? sheet.pngData()?.write(to: dir.appendingPathComponent("characters.png"))
    }
}
