import CoreGraphics

/// 比武背景的一张图和它管的那一段路：角色站在长卷上 y ≥ minY 的地方时用这张。
struct DuelSegment {
    var asset: String
    var minY: CGFloat
}

/// 一片地区的场景布局。
/// 长卷坐标：x 是长卷宽度的比例（0–1），y 是从顶往下的点数（按 1500 高写，400 以下会拉长到长卷的实际高度）。
struct RegionScene {
    enum RoadStyle { case stone, earth, boardwalk, sand, steppingStones }

    struct Item {
        var kind: Landmarks.Kind
        /// 底边中点（长卷：x 比例、y 设计坐标；比武背景：x、y 都是画布比例）。
        var x: CGFloat
        var y: CGFloat
        /// 宽度（长卷：点；比武背景：画布高度的比例）。
        var size: CGFloat
        /// 高度（茶园、溪、雾这类要高度的景物；长卷：设计坐标的点数，会跟着长卷拉长；比武背景：画布高度的比例）。
        var h: CGFloat = 0
        var flip = false
    }

    /// 路的控制点，从山脚到终点，连成平滑曲线。
    var road: [CGPoint]
    var roadStyle: RoadStyle
    /// 草地的颜色。
    var grass: UInt32 = 0x6E9A5E
    /// 这片地区的光和空气。
    var light = SceneLight()
    /// 整幅长卷的矢量图（Assets.xcassets 里的名字）。有就用它，不再画 items。
    var scrollAsset: String? = nil
    /// 比武背景的矢量图，从山脚往上列，一段路一张（比屏幕宽，同一段里的几站左右换取景）。有就用它，不再画 duel。
    var duelSegments: [DuelSegment] = []
    /// 比武背景里掌门站要居中的位置（最后一张图上的 x）。掌门站固定停在这里，不跟站数走。
    var duelBossX: CGFloat? = nil
    /// 长卷上的景物：背景（天、山、草坡）照原样先画，其余按底边从上到下画（下面的盖住上面的）。
    var items: [Item]
    /// 贴着路、要盖在路上面的景物（台阶）。
    var aboveRoad: [Item] = []
    /// 比武背景的景物（平视），按列出的顺序画（先远后近）。
    var duel: [Item]
}

/// 一片地区的光和空气：光从哪边来（影子往哪边投）、草地的明暗、雾带、阳光。
struct SceneLight {
    /// 影子往哪边投：光从右上来，影子往左、略往下。
    var shadowDir = CGVector(dx: -1, dy: 0.2)
    /// 影子长度：景物高度的几成（最长不超过 shadowMax 点）。
    var shadowLength: CGFloat = 0.36
    var shadowMax: CGFloat = 30
    var shadow: UInt32 = 0x2A4632
    var shadowAlpha: CGFloat = 0.42
    /// 草地上太阳照到的一块块（浅）和背光的一块块（深）。
    var grassLight: UInt32 = 0x86AE62
    var grassShade: UInt32 = 0x60894B
    var mist: UInt32 = 0xF3F6F1
    /// 雾带（长卷：设计坐标；画在单独一层，盖在景物上、站牌和小人之下，慢慢飘）。
    var mistBands: [MistBand] = []
    /// 阳光：从右边缘射进来的几道光带的起点（长卷：设计坐标 y）。
    var rays: [CGFloat] = []
    var rayColor: UInt32 = 0xFFF0CC
    /// 天空右上角的一团暖光（日出那边）。
    var skyGlow: UInt32? = nil
    /// 比武背景的阳光起点（画布高度的比例）。
    var duelRays: [CGFloat] = []
}

/// 一条雾带：y 是雾带底边，h 是厚度（设计坐标）；x0…x1 是左右范围（宽度的比例，可以超出 0–1）。
struct MistBand {
    var y: CGFloat
    var h: CGFloat
    var x0: CGFloat
    var x1: CGFloat
    var alpha: CGFloat
}

enum RegionScenes {
    /// 有正式美术场景的地区：半山镇的声明带旧画法，单独写；其余九片由生成脚本写在 generated 里。
    static func scene(for regionId: String) -> RegionScene? {
        regionId == "banshanzhen" ? banshanzhen : generated[regionId]
    }
}
