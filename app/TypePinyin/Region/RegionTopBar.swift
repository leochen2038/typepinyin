import LearningCore
import SwiftUI

/// 地区顶栏：回江湖、地名、这一关练什么（一行放下）。第几站、还剩几站、秘籍等级环 2026-11-18 去掉（长卷上看得到走到哪）。
struct RegionTopBar: View {
    @State var j: JourneyController
    let region: Region
    let route: Route

    var body: some View {
        HStack(spacing: 10) {
            Button { j.screen = .map } label: {
                Text("回江湖").font(.system(size: 15, weight: .black)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            }
            .buttonStyle(.popSmall)
            .accessibilityIdentifier("backToMap")
            VStack(alignment: .leading, spacing: 1) {
                Text(region.name).font(Fonts.display(22)).lineLimit(1)
                Text(j.xpLevels ? "练 \(region.hint)" : Volumes.name(region.volume)).font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.slate)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .overlay(PanelGesture { j.showPanel = true })
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Palette.mist.opacity(0.96))
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }
    }
}
