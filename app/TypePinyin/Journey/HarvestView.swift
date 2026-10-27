import SwiftUI

/// 「收功」：只说这次的收获，然后回江湖。
struct HarvestView: View {
    @State var j: JourneyController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("收功").font(Fonts.display(40))
                .overlay(PanelGesture { j.showPanel = true })
            ForEach(j.harvestLines, id: \.self) { l in
                HStack(spacing: 8) {
                    Rectangle().fill(Palette.gold).frame(width: 10, height: 10).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                    Text(l).font(.system(size: 18, weight: .bold))
                }
            }
            Text("练打字适合短而多，歇会儿再来记得更牢。").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.slate)
            Button { j.screen = .map } label: {
                Text("回江湖").font(Fonts.display(24)).frame(maxWidth: .infinity).frame(height: 52)
                    .background(Palette.gold).foregroundStyle(Palette.ink)
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.mist)
    }
}
