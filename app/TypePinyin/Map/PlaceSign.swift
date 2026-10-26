import LearningCore
import SwiftUI

/// 总地图上一个地点的状态。
enum PlaceState: Equatable {
    case untouched
    case inProgress
    case cleared(rank: Int)
    case passed          // 初入江湖：已过
    case locked(String)  // 武林大会：集齐十卷开放
}

/// 地点：小图标 + 一块路牌（地名、状态、拼音提示）。地名不小于 15 像素，拼音提示不小于 13 像素。
struct PlaceSign: View {
    let name: String
    let hint: String?
    let icon: String
    let state: PlaceState
    var selected = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 34, height: 34)
                .background(Circle().fill(iconFill))
                .overlay(Circle().stroke(Palette.ink, lineWidth: 2))
            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    Text(name).font(Fonts.hanzi(17)).foregroundStyle(Palette.ink)
                    marker
                }
                if let hint { Text(hint).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.slate) }
            }
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color(hex: 0xF7EBCF))
            .overlay(Rectangle().stroke(borderColor, lineWidth: borderWidth))
        }
        .scaleEffect(selected ? 1.08 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    var iconFill: Color {
        if case .passed = state { return Palette.mist2 }
        return Color(hex: 0xFFF6E0)
    }

    var borderColor: Color {
        if case .inProgress = state { return Palette.green }
        return Palette.ink.opacity(0.7)
    }

    var borderWidth: CGFloat { if case .inProgress = state { return 3 } else { return 1 } }

    @ViewBuilder var marker: some View {
        switch state {
        case .untouched: EmptyView()
        case .inProgress:
            Text("挑战中").font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                .padding(.horizontal, 4).background(Palette.green)
        case .cleared(let r):
            Text(["", "一", "二", "三", "四", "五"][max(1, min(5, r))] + "重").font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                .padding(.horizontal, 4).background(Palette.red)
        case .passed:
            Text("已过").font(.system(size: 11, weight: .black)).foregroundStyle(.white)
                .padding(.horizontal, 4).background(Palette.slate2)
        case .locked(let t):
            Text(t).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate)
        }
    }

    static func symbol(_ icon: String?) -> String {
        switch icon {
        case "slope": "mountain.2"
        case "plum": "camera.macro"
        case "island": "water.waves"
        case "moon": "moon"
        case "willow": "tree"
        case "spring": "drop"
        case "town": "house"
        case "city": "building.columns"
        case "bridge": "point.topleft.down.to.point.bottomright.curvepath"
        case "pass": "flag"
        default: "circle"
        }
    }
}
