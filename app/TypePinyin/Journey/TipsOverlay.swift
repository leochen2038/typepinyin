import SwiftUI

/// 入门提示：只有三条，各在第一次遇到时出现一次（看过的记进存档）。
enum JourneyTip: String, CaseIterable {
    case firstCard, firstPressure, firstNewMove

    var text: String {
        switch self {
        case .firstCard: "打出牌上字的拼音，就是出招。"
        case .firstPressure: "对手在蓄力，条满前打完这张牌。"
        case .firstNewMove: "没见过的拼法，键盘上会亮出下一个字母。左下角能听读音。"
        }
    }
}

/// 战斗区底部的一条提示，不挡操作。
struct TipBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Palette.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.white)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            .compositingGroup()
            .shadow(color: Palette.ink, radius: 0, x: 3, y: 3)
            .padding(.horizontal, 20)
            .allowsHitTesting(false)
            .accessibilityIdentifier("tip")
    }
}
