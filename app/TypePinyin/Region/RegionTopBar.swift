import LearningCore
import SwiftUI

/// 地区顶栏：回江湖、地名、秘籍卷、第几站和还剩几站、这一卷的重数（进度环，不写「还差几个」）。
struct RegionTopBar: View {
    @State var j: JourneyController
    let region: Region
    let route: Route

    var body: some View {
        let rank = j.rank(of: region.volume)
        let progress = j.learner.rankProgress(of: region.volume, rank: rank, content: j.content)
        HStack(spacing: 10) {
            Button { j.screen = .map } label: {
                Text("回江湖").font(.system(size: 15, weight: .black)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("backToMap")
            VStack(alignment: .leading, spacing: 1) {
                Text(region.name).font(Fonts.display(22))
                Text(Volumes.name(region.volume)).font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.slate)
            }
            Spacer()
            let n = route.stations.count
            Text("第 \(min(j.stationIndex + 1, n)) 站 · 还剩 \(max(0, n - j.stationIndex - 1)) 站")
                .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.ink)
            ZStack {
                Circle().stroke(Palette.mist2, lineWidth: 5)
                Circle().trim(from: 0, to: rank == 0 ? 0 : progress).stroke(Palette.red, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(rank == 0 ? "零" : ["", "一", "二", "三", "四", "五"][rank]).font(Fonts.display(15))
            }
            .frame(width: 36, height: 36)
            .accessibilityLabel(rank == 0 ? "还没拿到这一卷" : "第\(rank)重")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Palette.mist.opacity(0.96))
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }
    }
}
