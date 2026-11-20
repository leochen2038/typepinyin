import SwiftUI
import UIKit

/// 国潮版画配色。
enum Palette {
    static let navy = Color(hex: 0x1C2A5C)
    static let navy2 = Color(hex: 0x2B3F7E)
    static let gold = Color(hex: 0xF3B52F)
    /// 秘籍经验条：青绿，和血条（主角藏青、对手红）分开；这一场涨的那段是金色。
    static let xp = Color(hex: 0x2E9E7A)
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

/// 统一的按钮手感（2026-11-19）：按钮右下一块黑色硬投影（和卡片同一套样子）；按住时按钮往右下沉、盖住投影，松开弹回，按下时轻震一下。
/// 按钮自己的底色、黑边照旧写在 label 里，这里只管投影和按下去。
/// depth：主按钮、次按钮 4，顶栏小按钮 3。inset：label 外面多出来的透明点按范围（投影要画在看得见的框上，不画在透明边上）。
struct PopButtonStyle: ButtonStyle {
    var depth: CGFloat = 4
    var inset = EdgeInsets()

    func makeBody(configuration: Configuration) -> some View {
        PopBody(configuration: configuration, depth: depth, inset: inset)
    }

    private struct PopBody: View {
        let configuration: Configuration
        let depth: CGFloat
        let inset: EdgeInsets
        @Environment(\.isEnabled) private var enabled

        var body: some View {
            let down = configuration.isPressed && enabled
            configuration.label
                .offset(x: down ? depth : 0, y: down ? depth : 0)
                .background {
                    if enabled { Rectangle().fill(Palette.ink).padding(inset).offset(x: depth, y: depth) }
                }
                .animation(.spring(duration: down ? 0.06 : 0.18, bounce: down ? 0 : 0.5), value: down)
                .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, new in new && enabled }
        }
    }
}

extension ButtonStyle where Self == PopButtonStyle {
    /// 主按钮、次按钮（金底 / 白底，3 粗黑边）。
    static var pop: PopButtonStyle { PopButtonStyle() }
    /// 顶栏的小按钮（回江湖、书架、收获、返回）。
    static var popSmall: PopButtonStyle { PopButtonStyle(depth: 3) }
}
