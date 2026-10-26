import SwiftUI
import UIKit

/// 一片地区的配色：长卷和比武背景共用（比武背景就是长卷在这一站的局部）。
struct RegionTheme {
    let sky: UInt32
    let farHill: UInt32
    let nearHill: UInt32
    let road: UInt32
    let accent: UInt32

    static func of(_ regionId: String) -> RegionTheme {
        switch regionId {
        case "shilipo": RegionTheme(sky: 0xF3E9D2, farHill: 0xB9C7A0, nearHill: 0x7E9B5A, road: 0xE6C98F, accent: 0xC8553D)
        case "banshanzhen": RegionTheme(sky: 0xE4EEE6, farHill: 0x9DB8A6, nearHill: 0x4E7D5B, road: 0xD9CFB8, accent: 0x3B6E4A)
        default: RegionTheme(sky: 0xE7EAF1, farHill: 0xB8BFD3, nearHill: 0x6A7390, road: 0xE6D8B8, accent: 0xE2432C)
        }
    }

    func ui(_ v: UInt32) -> UIColor { UIColor(hex: v) }
    func color(_ v: UInt32) -> Color { Color(hex: v) }
}
