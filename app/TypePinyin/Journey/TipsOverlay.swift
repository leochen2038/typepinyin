import SwiftUI

/// 入门提示：只有三条，各在第一次遇到时出现一次（看过的记进存档）。
enum JourneyTip: String, CaseIterable {
    case firstCard, firstPressure, firstNewMove
    /// 梦里第一张牌的教学（打完这张牌才算学过；和旧版的提示记录分开）。
    case guide

    var text: String {
        switch self {
        case .firstCard: "打出牌上字的拼音，就是出招。"
        case .firstPressure: "对手在蓄力，条满前打完这张牌。"
        case .guide: ""
        case .firstNewMove: "没见过的拼法，键盘上会亮出下一个字母，它在哪一边，那一边就微微发黄。左下角能听读音。"
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

/// 第一张牌的教学说明：一句眼前这一步，必要时再加一句（左右手、发黄）。
struct GuideBanner: View {
    let title: String
    let line: String?

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 18, weight: .black))
            if let line {
                Text(line).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.slate)
            }
        }
        .foregroundStyle(Palette.ink)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        .compositingGroup()
        .shadow(color: Palette.ink, radius: 0, x: 3, y: 3)
        .padding(.horizontal, 16)
        .allowsHitTesting(false)
        .accessibilityIdentifier("guide")
    }
}
