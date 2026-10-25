import DuelCore
import SwiftUI

/// 小结卡片：只写收获；某一项为 0 或为空就不显示。输了标题是「再来一次」。
struct SummaryCardView: View {
    let s: DuelSummary
    let foe: String
    var fasterBy: Double? = nil
    let onAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(s.won ? "打赢了\(foe)" : "再来一次")
                .font(Fonts.display(32))
            if !s.won {
                Text("差一点，换个打法再试试").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.slate)
            }
            if let f = fasterBy {
                Text(String(format: "比上一场快了 %.0f 秒！", f))
                    .font(Fonts.display(22)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10).padding(.vertical, 4).background(Palette.gold)
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            }
            VStack(alignment: .leading, spacing: 8) {
                if s.goldMoves > 0 { gain("打出 \(s.goldMoves) 招完美") }
                if s.won { gain(String(format: "用时 %d:%02d", Int(s.durationSeconds) / 60, Int(s.durationSeconds) % 60)) }
                if s.charactersTyped > 0 { gain("打出了 \(s.charactersTyped) 个字") }
                if s.maxCombo > 1 { gain("最高 \(s.maxCombo) 连") }
                if s.parries > 0 { gain("弹反 \(s.parries) 次") }
                if !s.newMoves.isEmpty { gain("学会新招：\(s.newMoves.joined(separator: "、"))") }
            }
            Button(action: onAgain) {
                Text("再来一场").font(Fonts.display(24)).frame(maxWidth: .infinity).frame(height: 52)
                    .background(Palette.gold).foregroundStyle(Palette.ink)
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                    .compositingGroup().shadow(color: Palette.ink, radius: 0, x: 3, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("again")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        .compositingGroup()
        .shadow(color: Palette.ink, radius: 0, x: 6, y: 6)
        .padding(.horizontal, 16)
    }

    private func gain(_ text: String) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(Palette.gold).frame(width: 9, height: 9).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            Text(text).font(.system(size: 16, weight: .bold))
        }
    }
}
