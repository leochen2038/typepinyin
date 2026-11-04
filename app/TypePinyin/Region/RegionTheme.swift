import SwiftUI
import UIKit

/// 一片地区的配色：长卷和比武背景共用（比武背景就是长卷在这一站的局部）。
struct RegionTheme {
    let sky: UInt32
    let farHill: UInt32
    let nearHill: UInt32
    let road: UInt32
    let accent: UInt32

    /// 先用内容里写的配色（regions.yaml 的 theme），没写再用下面写死的（梦、旧数据）。
    @MainActor static func of(_ regionId: String) -> RegionTheme {
        if let t = AppResources.content.region(regionId)?.theme {
            return RegionTheme(sky: hex(t.sky), farHill: hex(t.farHill), nearHill: hex(t.nearHill), road: hex(t.road), accent: hex(t.accent))
        }
        return switch regionId {
        case "huluji": RegionTheme(sky: 0xF3E9D2, farHill: 0xB9C7A0, nearHill: 0x7E9B5A, road: 0xE6C98F, accent: 0xC8553D)
        case "dream": RegionTheme(sky: 0xE6E0F2, farHill: 0xC9C1E0, nearHill: 0x9C8FC4, road: 0xEDE6F7, accent: 0x7B5FB0)
        case "banshanzhen": RegionTheme(sky: 0xE4EEE6, farHill: 0x9DB8A6, nearHill: 0x4E7D5B, road: 0xD9CFB8, accent: 0x3B6E4A)
        default: RegionTheme(sky: 0xE7EAF1, farHill: 0xB8BFD3, nearHill: 0x6A7390, road: 0xE6D8B8, accent: 0xE2432C)
        }
    }

    static func hex(_ s: String) -> UInt32 { UInt32(s.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x8A8F9E }

    func ui(_ v: UInt32) -> UIColor { UIColor(hex: v) }
    func color(_ v: UInt32) -> Color { Color(hex: v) }
}
