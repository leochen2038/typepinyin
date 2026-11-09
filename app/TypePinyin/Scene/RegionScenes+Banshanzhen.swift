import CoreGraphics

/// 半山镇：长卷和比武背景用矢量图（scrollAsset、duelSegments）；路线用于站点和小人。
/// items 和 duel 是旧画法，只在调参面板切回旧画法时用。
extension RegionScenes {
    static let banshanzhen = RegionScene(
        road: [CGPoint(x: 0.46, y: 1520), CGPoint(x: 0.58, y: 1420), CGPoint(x: 0.62, y: 1300), CGPoint(x: 0.57, y: 1190),
               CGPoint(x: 0.45, y: 1090), CGPoint(x: 0.42, y: 980), CGPoint(x: 0.56, y: 880), CGPoint(x: 0.63, y: 780),
               CGPoint(x: 0.55, y: 670), CGPoint(x: 0.38, y: 570), CGPoint(x: 0.42, y: 470), CGPoint(x: 0.5, y: 360),
               CGPoint(x: 0.5, y: 262)],
        roadStyle: .stone,
        grass: 0x729C56,
        light: SceneLight(
            skyGlow: 0xFBEFD2,
            duelRays: [0.02, 0.3]),
        scrollAsset: "scroll-banshanzhen",
        duelSegments: [DuelSegment(asset: "duel-banshanzhen-1", minY: 1870),   // 山脚溪涧
                       DuelSegment(asset: "duel-banshanzhen-2", minY: 1160),   // 竹林石阶
                       DuelSegment(asset: "duel-banshanzhen-3", minY: 436),    // 镇子
                       DuelSegment(asset: "duel-banshanzhen-4", minY: 0)],     // 山门
        duelBossX: 625,
        items: [
            .init(kind: .cloud, x: 0.2, y: 46, size: 80), .init(kind: .cloud, x: 0.82, y: 38, size: 76), .init(kind: .cloud, x: 0.55, y: 84, size: 60),
            .init(kind: .mountains, x: 0.5, y: 228, size: 760),
            .init(kind: .slope, x: 0.5, y: 196, size: 1200),
            // 山门：石灯、松树、大石、花丛
            .init(kind: .bush, x: 0.16, y: 270, size: 46), .init(kind: .bush, x: 0.86, y: 268, size: 46),
            .init(kind: .pine, x: 0.28, y: 256, size: 66), .init(kind: .pine, x: 0.73, y: 254, size: 66),
            .init(kind: .gate, x: 0.5, y: 232, size: 104),
            .init(kind: .lantern, x: 0.38, y: 258, size: 19), .init(kind: .lantern, x: 0.62, y: 258, size: 19),
            .init(kind: .flowerBed, x: 0.42, y: 288, size: 28), .init(kind: .flowerBed, x: 0.59, y: 290, size: 28),
            .init(kind: .rock, x: 0.33, y: 318, size: 50), .init(kind: .rock, x: 0.67, y: 312, size: 40),
            .init(kind: .bush, x: 0.2, y: 350, size: 40), .init(kind: .flowerBed, x: 0.8, y: 345, size: 32),
            .init(kind: .pine, x: 0.07, y: 380, size: 84), .init(kind: .roundTree, x: 0.93, y: 365, size: 70),
            // 山门前路两边一对长幡：快到了
            .init(kind: .flags, x: 0.4, y: 398, size: 24, flip: true), .init(kind: .flags, x: 0.585, y: 402, size: 24),
            // 石阶岩壁：右边摩崖石、松树、一小片茶园；左边松树、大石
            .init(kind: .carvedRock, x: 0.66, y: 470, size: 46), .init(kind: .bush, x: 0.57, y: 490, size: 30),
            .init(kind: .pine, x: 0.8, y: 500, size: 70), .init(kind: .pine, x: 0.97, y: 452, size: 62),
            .init(kind: .terraces, x: 0.86, y: 562, size: 170, h: 50, flip: true),
            .init(kind: .pine, x: 0.08, y: 470, size: 78), .init(kind: .bush, x: 0.27, y: 445, size: 32), .init(kind: .rock, x: 0.2, y: 522, size: 40),
            .init(kind: .roundTree, x: 0.02, y: 575, size: 60), .init(kind: .bush, x: 0.12, y: 590, size: 30),
            // 半山凉亭：右边凉亭、踏脚石通到路上、樱花、花丛；左边一大片茶园
            .init(kind: .pavilion, x: 0.76, y: 640, size: 100),
            .init(kind: .steppingStones, x: 0.62, y: 652, size: 40),
            .init(kind: .blossom, x: 0.97, y: 650, size: 52), .init(kind: .flowerBed, x: 0.88, y: 668, size: 28),
            .init(kind: .terraces, x: 0.9, y: 762, size: 150, h: 70, flip: true),
            .init(kind: .blossom, x: 0.05, y: 640, size: 54), .init(kind: .rock, x: 0.24, y: 612, size: 36), .init(kind: .bush, x: 0.3, y: 652, size: 30),
            .init(kind: .terraces, x: 0.15, y: 772, size: 210, h: 90),
            .init(kind: .pine, x: 0.01, y: 676, size: 72),
            .init(kind: .pine, x: 0.94, y: 820, size: 68), .init(kind: .bush, x: 0.76, y: 806, size: 34),
            // 采茶人家：左边茅屋、竹篓、篱笆、茶园、圆树；右边一片茶园
            .init(kind: .terraces, x: 0.2, y: 852, size: 190, h: 60),
            .init(kind: .roundTree, x: 0.04, y: 880, size: 64),
            .init(kind: .hut, x: 0.2, y: 902, size: 84),
            .init(kind: .basket, x: 0.36, y: 914, size: 22),
            .init(kind: .fence, x: 0.24, y: 940, size: 84),
            .init(kind: .terraces, x: 0.88, y: 930, size: 160, h: 80, flip: true),
            .init(kind: .roundTree, x: 0.98, y: 850, size: 60), .init(kind: .blossom, x: 0.96, y: 962, size: 46),
            // 古樟石碑：右边大樟树（系着红布）、树下长凳、路边石碑、土地庙；左边圆树、大石、花丛
            .init(kind: .bigTree, x: 0.74, y: 1046, size: 112),
            .init(kind: .stele, x: 0.555, y: 1062, size: 26),
            .init(kind: .bench, x: 0.68, y: 1066, size: 34),
            .init(kind: .shrine, x: 0.93, y: 1082, size: 40), .init(kind: .flowerBed, x: 0.84, y: 1096, size: 26),
            .init(kind: .roundTree, x: 0.12, y: 1010, size: 66), .init(kind: .flowerBed, x: 0.3, y: 990, size: 26),
            .init(kind: .rock, x: 0.27, y: 1040, size: 40), .init(kind: .bush, x: 0.06, y: 1062, size: 36),
            // 路口茶摊：右边布篷茶摊、晒茶的竹匾、竹篓；左边茶园
            .init(kind: .terraces, x: 0.12, y: 1135, size: 150, h: 65),
            .init(kind: .teaStall, x: 0.72, y: 1160, size: 76),
            .init(kind: .basket, x: 0.94, y: 1168, size: 22),
            .init(kind: .roundTree, x: 1.0, y: 1200, size: 56),
            .init(kind: .dryingRack, x: 0.88, y: 1212, size: 56),
            // 山脚镇子（左）：几户人家一排排往下叠，路边一间茶馆，晾衣竿、水缸、竹篓，最下面铁匠铺、板车、柴堆、水井
            .init(kind: .roundTree, x: 0.0, y: 1175, size: 60),
            .init(kind: .house, x: 0.14, y: 1205, size: 130),
            .init(kind: .laundry, x: 0.06, y: 1262, size: 50),
            .init(kind: .teaHouse, x: 0.33, y: 1270, size: 136),
            .init(kind: .bush, x: 0.52, y: 1290, size: 28), .init(kind: .basket, x: 0.5, y: 1320, size: 20),
            .init(kind: .house, x: 0.17, y: 1345, size: 150),
            .init(kind: .fence, x: 0.15, y: 1372, size: 64),
            .init(kind: .waterVat, x: 0.47, y: 1352, size: 22),
            .init(kind: .flowerBed, x: 0.06, y: 1395, size: 28), .init(kind: .flowerBed, x: 0.36, y: 1392, size: 26),
            .init(kind: .roundTree, x: 0.47, y: 1395, size: 50),
            .init(kind: .well, x: 0.42, y: 1420, size: 46),
            .init(kind: .smithy, x: 0.2, y: 1470, size: 150),
            .init(kind: .cart, x: 0.38, y: 1490, size: 44),
            .init(kind: .firewood, x: 0.03, y: 1492, size: 34),
            // 山脚镇子（右）：小溪从下面流上来，上游一架水车，中间石拱桥，岸边垂柳、石头、花丛
            .init(kind: .stream, x: 0.88, y: 1540, size: 46, h: 300),
            .init(kind: .waterwheel, x: 0.82, y: 1268, size: 48),
            .init(kind: .flowerBed, x: 0.73, y: 1300, size: 26),
            .init(kind: .bush, x: 0.7, y: 1338, size: 30), .init(kind: .willow, x: 0.95, y: 1360, size: 120),
            .init(kind: .rock, x: 0.77, y: 1385, size: 26),
            .init(kind: .stoneBridge, x: 0.86, y: 1420, size: 90), .init(kind: .steppingStones, x: 0.68, y: 1428, size: 40),
            .init(kind: .rock, x: 0.74, y: 1460, size: 40), .init(kind: .bush, x: 0.68, y: 1494, size: 36), .init(kind: .rock, x: 0.97, y: 1498, size: 44),
        ],
        aboveRoad: [.init(kind: .steps, x: 0.5, y: 312, size: 50)],
        duel: [
            .init(kind: .sun, x: 0.88, y: 0.3, size: 0.15),
            .init(kind: .cloud, x: 0.12, y: 0.18, size: 0.26), .init(kind: .cloud, x: 0.62, y: 0.13, size: 0.22),
            .init(kind: .mountains, x: 0.5, y: 0.68, size: 3.4, h: 0.36),
            .init(kind: .mistBand, x: 0.32, y: 0.665, size: 1.1, h: 0.06), .init(kind: .mistBand, x: 0.86, y: 0.65, size: 0.8, h: 0.05),
            .init(kind: .hillBand, x: 0.5, y: 0.72, size: 3.4),
            .init(kind: .gate, x: 0.22, y: 0.57, size: 0.17),
            .init(kind: .pine, x: 0.15, y: 0.58, size: 0.11), .init(kind: .pine, x: 0.3, y: 0.58, size: 0.1),
            .init(kind: .pavilion, x: 0.7, y: 0.6, size: 0.18),
            .init(kind: .mistBand, x: 0.52, y: 0.62, size: 0.9, h: 0.045),
            .init(kind: .terraces, x: 0.27, y: 0.845, size: 1.75, h: 0.18, flip: true),
            .init(kind: .terraces, x: 0.73, y: 0.85, size: 1.75, h: 0.17),
            .init(kind: .blossom, x: 0.1, y: 0.85, size: 0.28), .init(kind: .fence, x: 0.6, y: 0.85, size: 0.3),
            .init(kind: .lantern, x: 0.42, y: 0.85, size: 0.11), .init(kind: .basket, x: 0.82, y: 0.85, size: 0.1),
            .init(kind: .flowerBed, x: 0.5, y: 0.85, size: 0.12), .init(kind: .bush, x: 0.35, y: 0.855, size: 0.14),
            .init(kind: .pine, x: 0.02, y: 0.86, size: 0.5), .init(kind: .rock, x: 0.93, y: 0.86, size: 0.22),
            .init(kind: .pine, x: 0.99, y: 0.86, size: 0.44),
        ])
}
