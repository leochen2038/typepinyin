import LearningCore
import SwiftUI

/// 「拿到秘籍」演出：掌门被打赢的话（有就显示），书卷展开，卷名，这一卷到了第几重。
struct ObtainVolumeView: View {
    let volume: String
    let rank: Int
    /// 秘籍的名字和等级怎么写（按经验升级时是「白梅台秘籍」「1 级」）；nil = 原来的卷名和重数。
    var name: String? = nil
    var level: String? = nil
    /// 打赢掌门：掌门在秘籍上盖印（秘籍进岛时已经拿到）。
    var seal: String? = nil
    /// 掌门的名字和被打赢的话；没有就不显示。
    var boss: (name: String, line: String)? = nil
    let onDone: () -> Void
    @State private var open = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 14) {
                if let boss {
                    VStack(spacing: 4) {
                        Text(boss.name).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.gold)
                        Text("「\(boss.line)」").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32).padding(.bottom, 8)
                    .accessibilityIdentifier("bossDefeatLine")
                }
                Text(seal == nil ? "拿到秘籍" : "掌门在秘籍上盖了印").font(.system(size: 18, weight: .black)).foregroundStyle(Palette.gold)
                Text(name ?? "《\(Volumes.name(volume))》").font(Fonts.display(name == nil ? 40 : 34)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 26).padding(.vertical, 14)
                    .background(Color(hex: 0xF7EBCF))
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                    .overlay(alignment: .bottomTrailing) {
                        if let seal {                             // 掌门印：岛名第一个字，和山顶十方印是同一批
                            Text(seal).font(.system(size: 22, weight: .black)).foregroundStyle(.white)
                                .frame(width: 36, height: 36).background(Palette.red)
                                .overlay(Rectangle().stroke(Color(hex: 0xFBF7EE), lineWidth: 2.5))
                                .rotationEffect(.degrees(-8)).offset(x: 14, y: 14)
                                .scaleEffect(open ? 1 : 2.4).opacity(open ? 1 : 0)
                        }
                    }
                    .scaleEffect(x: open ? 1 : 0.1, y: 1)
                Text(level ?? "第\(["", "一", "二", "三", "四", "五"][max(1, min(5, rank))])重").font(Fonts.display(26)).foregroundStyle(.white)
                Button(action: onDone) {
                    Text("收下").font(Fonts.display(22)).padding(.horizontal, 36).padding(.vertical, 10)
                        .background(Palette.gold).foregroundStyle(Palette.ink)
                        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("obtainDone")
            }
        }
        .onAppear { withAnimation(.spring(duration: JourneyFlags.fast ? 0.05 : 0.6, bounce: 0.3)) { open = true } }
    }
}
