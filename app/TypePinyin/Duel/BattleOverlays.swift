import SwiftUI

/// 战斗区左上的连招数：到 8 变金色，到 15 变红色。
struct ComboView: View {
    let combo: Int
    let goldAt: Int
    let redAt: Int
    var heat: Int = 0

    var body: some View {
        if combo >= 2 {
            VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(combo)")
                    .font(Fonts.display(60))
                    .foregroundStyle(combo >= redAt ? Palette.red : combo >= goldAt ? Palette.gold : .white)
                    .shadow(color: Palette.ink, radius: 0, x: 2, y: 2)
                Text("连！").font(Fonts.display(24)).foregroundStyle(.white).shadow(color: Palette.ink, radius: 0, x: 1.5, y: 1.5)
            }
            if heat > 0 {
                Text("气势 " + ["", "一档", "二档", "三档"][heat])
                    .font(.system(size: 12, weight: .black)).foregroundStyle(Palette.ink)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(heat >= 3 ? Palette.red : Palette.gold)
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            }
            }
            .rotationEffect(.degrees(-7))
            .id(combo)
            .transition(.scale(scale: 1.4).combined(with: .opacity))
            .accessibilityLabel("\(combo) 连")
        }
    }
}

/// 对手头上的来招：一个词加一条时间条，不显示秒数。
struct IncomingBox: View {
    let incoming: DuelController.IncomingVM
    let progress: Double
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 30

    var body: some View {
        VStack(spacing: 1) {
            Text("来招！").font(.system(size: 11, weight: .black)).tracking(3).foregroundStyle(Palette.red)
            Text(incoming.text).font(Fonts.hanzi(max(24, size))).lineLimit(1)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Rectangle().fill(.white)
                    Rectangle().fill(Palette.red).frame(width: g.size.width * (1 - progress))
                }
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1.5))
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 8).padding(.top, 4).padding(.bottom, 7)
        .frame(width: 124)
        .background(incoming.locked ? Palette.gold : .white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        .compositingGroup()
        .shadow(color: Palette.ink, radius: 0, x: 4, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("来招 \(incoming.text)")
    }
}

/// 对手蓄力条（一张牌模式）：条满之前没打完这张牌，对手出手。快满时变红、轻轻跳动。
/// 单独成一个视图读 c.pressure：它每帧都在变，放在外面会让整个比武界面每帧重算。
struct PressureBarHost: View {
    let c: DuelController

    var body: some View {
        // 一直挂着：回顾时对手停手、条是空的，新牌露出来再涨（以前条为 0 就藏起来，回顾时会一闪一闪）
        if c.cards.count == 1 && c.summary == nil && !c.tuning.groupFight {      // 群战时每个敌人头上有自己的条
            PressureBar(name: c.foeName, progress: c.pressure)
        }
    }
}

struct PressureBar: View {
    let name: String
    let progress: Double

    var body: some View {
        let danger = progress > 0.75
        HStack(spacing: 6) {
            Text("\(name)蓄力").font(.system(size: 11, weight: .black))
                .foregroundStyle(danger ? Palette.red : Palette.ink)
                .fixedSize()
            ZStack(alignment: .leading) {
                Rectangle().fill(.white)
                Rectangle().fill(danger ? Palette.red : Palette.gold).frame(width: 96 * progress)
            }
            .frame(width: 96, height: 9)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Palette.paper)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
        .scaleEffect(danger ? 1 + 0.05 * sin(progress * 60) : 1, anchor: .trailing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name)蓄力 \(Int(progress * 100))%")
    }
}

/// 金色「新招」：没学过的音节第一次拼错时浮出，不是错误。
struct NewMoveToast: View {
    let syllable: String

    var body: some View {
        HStack(spacing: 8) {
            Text("新招").font(Fonts.display(30)).foregroundStyle(Palette.ink)
            Text(syllable).font(Fonts.mono(22, weight: .heavy)).foregroundStyle(Palette.navy)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(Palette.gold)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        .compositingGroup()
        .shadow(color: Palette.ink, radius: 0, x: 4, y: 4)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }
}

/// 按偏了：轻轻冒一下「差一点」，不罚。
struct NearMissToast: View {
    var body: some View {
        Text("差一点")
            .font(Fonts.display(20)).foregroundStyle(Palette.navy)
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(.white)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

/// 最后一招。
struct FinaleBanner: View {
    var body: some View {
        Text("最后一招！")
            .font(Fonts.display(40)).foregroundStyle(Palette.ink)
            .padding(.horizontal, 22).padding(.vertical, 6)
            .background(Palette.gold)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            .compositingGroup()
            .shadow(color: Palette.ink, radius: 0, x: 5, y: 5)
            .rotationEffect(.degrees(-4))
            .transition(.scale(scale: 1.6).combined(with: .opacity))
    }
}

/// 打空对手血条的那一刀：屏幕中间打出「绝杀！」。
struct KillBanner: View {
    var body: some View {
        Text("绝杀！")
            .font(Fonts.display(64)).foregroundStyle(.white)
            .shadow(color: Palette.ink, radius: 0, x: 4, y: 4)
            .padding(.horizontal, 26).padding(.vertical, 4)
            .background(Palette.red)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 4))
            .rotationEffect(.degrees(-6))
            .transition(.scale(scale: 2.2).combined(with: .opacity))
            .allowsHitTesting(false)
    }
}
