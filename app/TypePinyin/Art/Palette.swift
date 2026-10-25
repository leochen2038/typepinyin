import SwiftUI
import UIKit

/// 国潮版画配色。
enum Palette {
    static let navy = Color(hex: 0x1C2A5C)
    static let navy2 = Color(hex: 0x2B3F7E)
    static let gold = Color(hex: 0xF3B52F)
    static let red = Color(hex: 0xE2432C)
    static let paper = Color.white
    static let ink = Color(hex: 0x111111)
    static let mist = Color(hex: 0xE7EAF1)
    static let mist2 = Color(hex: 0xD5DAE6)
    static let slate = Color(hex: 0x3A4260)
    static let slate2 = Color(hex: 0x6A7390)
    static let faint = Color(hex: 0xA3AAC2)
    static let green = Color(hex: 0x2E9A6A)
    /// 命数：每条命的血条颜色，按「还剩几条」取（最后一条是红色）。
    static func life(_ left: Int) -> Color {
        [red, Color(hex: 0xF08A24), Color(hex: 0x8E5BC9), Color(hex: 0x2E9A9A), green][min(4, max(0, left - 1))]
    }

    static let uiNavy = UIColor(hex: 0x1C2A5C)
    static let uiGold = UIColor(hex: 0xF3B52F)
    static let uiRed = UIColor(hex: 0xE2432C)
    static let uiInk = UIColor(hex: 0x111111)
    static let uiMist2 = UIColor(hex: 0xD5DAE6)
    static let uiSkin = UIColor(hex: 0xFFE2C2)
}

/// 标题字体：站酷庆科黄油体（OFL，Resources/ZCOOL-OFL.txt），没装上时退回系统粗体。
enum Fonts {
    static let displayName = "ZCOOLQingKeHuangYou-Regular"

    static func display(_ size: CGFloat) -> Font {
        UIFont(name: displayName, size: size) != nil ? .custom(displayName, size: size) : .system(size: size, weight: .heavy)
    }

    static func uiDisplay(_ size: CGFloat) -> UIFont {
        UIFont(name: displayName, size: size) ?? .systemFont(ofSize: size, weight: .heavy)
    }

    /// 要读的汉字（词牌、回顾牌、来招）：用系统字体（苹方）粗体，笔画规整、好认。
    /// 标题、连招数这些装饰性的字才用上面的艺术字体。
    static func hanzi(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
