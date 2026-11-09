import CoreGraphics

/// 九片地区的场景声明：路线、比武背景分段、掌门站取景。由场景导出脚本生成，和图放在一起改，不要手改。
extension RegionScenes {
    static let generated: [String: RegionScene] = [
        "huluji": RegionScene(
            road: [CGPoint(x: 0.46, y: 1520), CGPoint(x: 0.4, y: 1420), CGPoint(x: 0.38, y: 1310), CGPoint(x: 0.47, y: 1210), CGPoint(x: 0.58, y: 1110), CGPoint(x: 0.6, y: 1000), CGPoint(x: 0.5, y: 900), CGPoint(x: 0.42, y: 790), CGPoint(x: 0.44, y: 680), CGPoint(x: 0.54, y: 580), CGPoint(x: 0.56, y: 480), CGPoint(x: 0.5, y: 390), CGPoint(x: 0.5, y: 318)],
            roadStyle: .stone,
            scrollAsset: "scroll-huluji",
            duelSegments: [DuelSegment(asset: "duel-huluji-1", minY: 1870), DuelSegment(asset: "duel-huluji-2", minY: 1160), DuelSegment(asset: "duel-huluji-3", minY: 470), DuelSegment(asset: "duel-huluji-4", minY: 0)],
            duelBossX: 625,
            items: [],
            duel: []),
        "baimeitai": RegionScene(
            road: [CGPoint(x: 0.52, y: 1520), CGPoint(x: 0.66, y: 1410), CGPoint(x: 0.7, y: 1300), CGPoint(x: 0.5, y: 1200), CGPoint(x: 0.3, y: 1110), CGPoint(x: 0.28, y: 1000), CGPoint(x: 0.5, y: 900), CGPoint(x: 0.72, y: 800), CGPoint(x: 0.7, y: 690), CGPoint(x: 0.5, y: 600), CGPoint(x: 0.42, y: 510), CGPoint(x: 0.5, y: 430), CGPoint(x: 0.5, y: 350)],
            roadStyle: .stone,
            scrollAsset: "scroll-baimeitai",
            duelSegments: [DuelSegment(asset: "duel-baimeitai-1", minY: 1240), DuelSegment(asset: "duel-baimeitai-2", minY: 870), DuelSegment(asset: "duel-baimeitai-3", minY: 500), DuelSegment(asset: "duel-baimeitai-4", minY: 0)],
            duelBossX: 625,
            items: [],
            duel: []),
        "chaotoudao": RegionScene(
            road: [CGPoint(x: 0.5, y: 1520), CGPoint(x: 0.5, y: 1420), CGPoint(x: 0.5, y: 1342), CGPoint(x: 0.46, y: 1250), CGPoint(x: 0.54, y: 1150), CGPoint(x: 0.6, y: 1050), CGPoint(x: 0.52, y: 950), CGPoint(x: 0.42, y: 850), CGPoint(x: 0.44, y: 750), CGPoint(x: 0.54, y: 650), CGPoint(x: 0.58, y: 550), CGPoint(x: 0.5, y: 450), CGPoint(x: 0.5, y: 372)],
            roadStyle: .stone,
            scrollAsset: "scroll-chaotoudao",
            duelSegments: [DuelSegment(asset: "duel-chaotoudao-1", minY: 1590), DuelSegment(asset: "duel-chaotoudao-2", minY: 900), DuelSegment(asset: "duel-chaotoudao-3", minY: 0)],
            duelBossX: 625,
            items: [],
            duel: []),
        "yueyawan": RegionScene(
            road: [CGPoint(x: 0.52, y: 1520), CGPoint(x: 0.6, y: 1400), CGPoint(x: 0.7, y: 1300), CGPoint(x: 0.74, y: 1200), CGPoint(x: 0.72, y: 1100), CGPoint(x: 0.66, y: 1000), CGPoint(x: 0.64, y: 900), CGPoint(x: 0.66, y: 800), CGPoint(x: 0.62, y: 700), CGPoint(x: 0.56, y: 600), CGPoint(x: 0.5, y: 520), CGPoint(x: 0.47, y: 470), CGPoint(x: 0.4, y: 420), CGPoint(x: 0.3, y: 385), CGPoint(x: 0.25, y: 374)],
            roadStyle: .stone,
            scrollAsset: "scroll-yueyawan",
            duelSegments: [DuelSegment(asset: "duel-yueyawan-1", minY: 1300), DuelSegment(asset: "duel-yueyawan-2", minY: 600), DuelSegment(asset: "duel-yueyawan-3", minY: 0)],
            duelBossX: 625,
            items: [],
            duel: []),
        "chuiliucun": RegionScene(
            road: [CGPoint(x: 0.66, y: 1520), CGPoint(x: 0.66, y: 1400), CGPoint(x: 0.62, y: 1300), CGPoint(x: 0.56, y: 1215), CGPoint(x: 0.48, y: 1140), CGPoint(x: 0.42, y: 1040), CGPoint(x: 0.46, y: 900), CGPoint(x: 0.56, y: 800), CGPoint(x: 0.6, y: 700), CGPoint(x: 0.52, y: 600), CGPoint(x: 0.44, y: 500), CGPoint(x: 0.48, y: 420), CGPoint(x: 0.5, y: 358)],
            roadStyle: .stone,
            scrollAsset: "scroll-chuiliucun",
            duelSegments: [DuelSegment(asset: "duel-chuiliucun-1", minY: 1500), DuelSegment(asset: "duel-chuiliucun-2", minY: 1180), DuelSegment(asset: "duel-chuiliucun-3", minY: 450), DuelSegment(asset: "duel-chuiliucun-4", minY: 0)],
            duelBossX: 625,
            items: [],
            duel: []),
        "lvquanju": RegionScene(
            road: [CGPoint(x: 0.62, y: 1520), CGPoint(x: 0.6, y: 1400), CGPoint(x: 0.58, y: 1310), CGPoint(x: 0.44, y: 1220), CGPoint(x: 0.36, y: 1120), CGPoint(x: 0.4, y: 1000), CGPoint(x: 0.5, y: 900), CGPoint(x: 0.46, y: 800), CGPoint(x: 0.36, y: 700), CGPoint(x: 0.36, y: 620), CGPoint(x: 0.42, y: 560), CGPoint(x: 0.46, y: 520), CGPoint(x: 0.47, y: 500)],
            roadStyle: .stone,
            scrollAsset: "scroll-lvquanju",
            duelSegments: [DuelSegment(asset: "duel-lvquanju-1", minY: 1800), DuelSegment(asset: "duel-lvquanju-2", minY: 1180), DuelSegment(asset: "duel-lvquanju-3", minY: 640), DuelSegment(asset: "duel-lvquanju-4", minY: 0)],
            duelBossX: 660,
            items: [],
            duel: []),
        "changfengcheng": RegionScene(
            road: [CGPoint(x: 0.5, y: 1520), CGPoint(x: 0.5, y: 1380), CGPoint(x: 0.5, y: 1250), CGPoint(x: 0.5, y: 1143), CGPoint(x: 0.5, y: 1000), CGPoint(x: 0.5, y: 860), CGPoint(x: 0.5, y: 720), CGPoint(x: 0.5, y: 600), CGPoint(x: 0.5, y: 500), CGPoint(x: 0.5, y: 433)],
            roadStyle: .stone,
            scrollAsset: "scroll-changfengcheng",
            duelSegments: [DuelSegment(asset: "duel-changfengcheng-1", minY: 1650), DuelSegment(asset: "duel-changfengcheng-2", minY: 900), DuelSegment(asset: "duel-changfengcheng-3", minY: 500), DuelSegment(asset: "duel-changfengcheng-4", minY: 0)],
            duelBossX: 625,
            items: [],
            duel: []),
        "xiaoqiaoxiang": RegionScene(
            road: [CGPoint(x: 0.26, y: 1520), CGPoint(x: 0.2, y: 1351), CGPoint(x: 0.17, y: 1250), CGPoint(x: 0.18, y: 1165), CGPoint(x: 0.26, y: 1118), CGPoint(x: 0.32, y: 1112), CGPoint(x: 0.42, y: 1112), CGPoint(x: 0.56, y: 1112), CGPoint(x: 0.68, y: 1112), CGPoint(x: 0.74, y: 1108), CGPoint(x: 0.84, y: 1060), CGPoint(x: 0.86, y: 960), CGPoint(x: 0.84, y: 860), CGPoint(x: 0.76, y: 804), CGPoint(x: 0.7, y: 794), CGPoint(x: 0.58, y: 794), CGPoint(x: 0.42, y: 794), CGPoint(x: 0.32, y: 794), CGPoint(x: 0.24, y: 780), CGPoint(x: 0.15, y: 720), CGPoint(x: 0.16, y: 620), CGPoint(x: 0.3, y: 512), CGPoint(x: 0.44, y: 436), CGPoint(x: 0.5, y: 394)],
            roadStyle: .stone,
            scrollAsset: "scroll-xiaoqiaoxiang",
            duelSegments: [DuelSegment(asset: "duel-xiaoqiaoxiang-1", minY: 1640), DuelSegment(asset: "duel-xiaoqiaoxiang-2", minY: 1100), DuelSegment(asset: "duel-xiaoqiaoxiang-3", minY: 490), DuelSegment(asset: "duel-xiaoqiaoxiang-4", minY: 0)],
            duelBossX: 625,
            items: [],
            duel: []),
        "huanghuaguan": RegionScene(
            road: [CGPoint(x: 0.56, y: 1520), CGPoint(x: 0.64, y: 1400), CGPoint(x: 0.6, y: 1280), CGPoint(x: 0.44, y: 1180), CGPoint(x: 0.36, y: 1070), CGPoint(x: 0.46, y: 960), CGPoint(x: 0.6, y: 860), CGPoint(x: 0.58, y: 750), CGPoint(x: 0.46, y: 660), CGPoint(x: 0.48, y: 600), CGPoint(x: 0.47, y: 545)],
            roadStyle: .stone,
            scrollAsset: "scroll-huanghuaguan",
            duelSegments: [DuelSegment(asset: "duel-huanghuaguan-1", minY: 1460), DuelSegment(asset: "duel-huanghuaguan-2", minY: 760), DuelSegment(asset: "duel-huanghuaguan-3", minY: 0)],
            duelBossX: 625,
            items: [],
            duel: []),
    ]
}
