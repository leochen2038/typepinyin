import LearningCore
import SwiftUI

/// 武林大会的几块画面：碑、擂台、比武、当选盟主、收尾。
struct GatheringRoot: View {
    @State var j: JourneyController

    var body: some View {
        switch j.gatheringStage {
        case .stele:
            if let st = j.content.gathering?.stele {
                TextScreen(c: j.duel,
                           encounter: .init(id: "stele-gathering", kind: "encounter", title: "武林大会碑", intro: st.intro, source: nil,
                                            reply: "碑上的字记下了。", text: st.text, syllables: st.syllables),
                           onFinish: { t in j.gatheringSteleDone(t) },
                           onEncounterDone: { j.leaveGatheringStele() },
                           onLeave: { j.screen = .map },
                           doneLabel: "上擂台",
                           guideSyllables: Set(st.syllables.filter { (j.learner.records[$0]?.proficiency ?? .locked) < .met }),
                           resultNote: { "你已经能打出 \(j.typedCommonChars) 个常用字" },
                           brief: j.gatheringBrief)
                    .id("stele-gathering-\(j.duelToken)")
                    .accessibilityIdentifier("stele")
            }
        case .hall:
            GatheringHallView(j: j)
        case .duel(let k):
            DuelScreen(c: j.duel, prepare: { j.startGatheringDuel(k) })
                .id("gathering-\(k)-\(j.duelToken)")
        case .crowned:
            CrownedView(j: j)
        case .finale:
            FinaleView(j: j)
        }
    }
}

/// 「武林盟主」红印。
struct LeaderSeal: View {
    var size: CGFloat = 92

    var body: some View {
        VStack(spacing: 0) {
            Text("武林").font(Fonts.display(size * 0.32))
            Text("盟主").font(Fonts.display(size * 0.32))
        }
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(Palette.red)
        .overlay(Rectangle().stroke(Color(hex: 0x8F1F12), lineWidth: max(2, size * 0.04)).padding(size * 0.06))
        .compositingGroup().shadow(color: Palette.navy, radius: 0, x: 4, y: 4)
        .rotationEffect(.degrees(-5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("武林盟主")
    }
}

/// 擂台：两场，打到哪一场、下一场打谁；打通以后「再来一次」。
struct GatheringHallView: View {
    @State var j: JourneyController

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { j.screen = .map } label: {
                    Text("回江湖").font(.system(size: 15, weight: .black)).foregroundStyle(Palette.ink)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("backToMap")
                Text("武林大会").font(Fonts.display(26))
                    .overlay(PanelGesture { j.showPanel = true })
                Spacer()
            }
            .padding(.horizontal, 16).frame(height: 56)
            .background(Palette.mist)
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.ink).frame(height: 3) }
            ScrollView {
                VStack(spacing: 16) {
                    ZStack(alignment: .bottomTrailing) {
                        Image("peak-open").resizable().scaledToFit().frame(maxWidth: 300)
                        if j.crowned { LeaderSeal(size: 70).offset(x: 6, y: 10) }
                    }
                    .padding(.top, 12)
                    fight(0, title: "十位掌门", note: "一次上三位，轮番上台")
                    fight(1, title: "妙笔书生", note: "写字最快的人，五条命")
                    if j.gatheringWon {
                        Text("打通了。再来一次，看看又快了多少。").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.slate)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
            }
            VStack(spacing: 10) {
                if j.gatheringWon {
                    RegionCard.button("再来一次", primary: true) { j.replayGathering() }
                } else {
                    RegionCard.button("挑战", primary: true) { j.startGatheringFight() }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(Palette.mist)
        .accessibilityIdentifier("gatheringHall")
        .onAppear {
            guard !j.gatheringWon else { return }
            j.autoAdvance(after: 2) { jj in jj.startGatheringFight() }
        }
    }

    /// 一场的牌子：第几场、打谁、一句说明，右边写打赢了还是轮到这一场。
    private func fight(_ k: Int, title: String, note: String) -> some View {
        let done = j.gatheringWon || j.gatheringStep > k
        let now = !j.gatheringWon && j.gatheringStep == k
        return HStack(alignment: .center, spacing: 12) {
            Text(k == 0 ? "第一场" : "第二场").font(.system(size: 13, weight: .black))
                .foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 3)
                .background(now ? Palette.red : Palette.navy)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Fonts.display(22)).foregroundStyle(Palette.ink)
                Text(note).font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.slate)
            }
            Spacer()
            Text(done ? "打赢了" : now ? "该你上台" : "打赢第一场再来")
                .font(.system(size: 13, weight: .black)).foregroundStyle(done ? Palette.green : now ? Palette.red : Palette.faint)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(Color.white)
        .overlay(Rectangle().stroke(now ? Palette.red : Palette.ink, lineWidth: now ? 3 : 2))
        .accessibilityElement(children: .combine)
    }
}

/// 第一场打赢：当选武林盟主。红印落下，十位掌门的名字排两行。
struct CrownedView: View {
    @State var j: JourneyController
    @State private var stamped = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            LeaderSeal(size: 132)
                .scaleEffect(stamped ? 1 : 2.2).opacity(stamped ? 1 : 0)
            Text(j.content.gathering?.crowned ?? "").font(Fonts.hanzi(22)).foregroundStyle(.white)
                .multilineTextAlignment(.center)
            let names = j.content.regions.filter(\.playable).map(\.boss.name)
            VStack(spacing: 6) {
                ForEach([Array(names.prefix(5)), Array(names.dropFirst(5))], id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(row, id: \.self) { n in
                            Text(n).font(.system(size: 12, weight: .black)).foregroundStyle(Palette.gold)
                                .lineLimit(1).minimumScaleFactor(0.7)
                                .padding(.horizontal, 6).padding(.vertical, 4)
                                .overlay(Rectangle().stroke(Palette.gold.opacity(0.6), lineWidth: 1.5))
                        }
                    }
                }
            }
            Text(j.content.gathering?.crownedNote ?? "").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            Spacer()
            RegionCard.button("继续", primary: true) { j.gatheringStage = .hall }
                .padding(.horizontal, 16).padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .background(Palette.navy.ignoresSafeArea())
        .accessibilityIdentifier("crowned")
        .onAppear {
            withAnimation(.spring(duration: 0.35, bounce: 0.4).delay(0.2)) { stamped = true }
            j.autoAdvance(after: 3) { jj in jj.gatheringStage = .hall }
        }
    }
}

/// 打赢妙笔书生：他最后一句，下面只报收获，附一张可以发给家人的卡片。
struct FinaleView: View {
    @State var j: JourneyController
    @State private var shareImage: Image?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    LeaderSeal(size: 96).padding(.top, 28)
                    Text("打赢了妙笔书生").font(Fonts.display(30))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("「\(j.content.gathering?.farewell ?? "")」").font(Fonts.hanzi(18)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("—— 妙笔书生").font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.slate)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(16)
                    .background(Color(hex: 0xFFF6D6))
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("从葫芦集走到山顶").font(.system(size: 14, weight: .black)).foregroundStyle(Palette.slate)
                        ForEach(j.finaleLines, id: \.self) { line in
                            HStack(spacing: 8) {
                                Rectangle().fill(Palette.gold).frame(width: 8, height: 8).overlay(Rectangle().stroke(Palette.ink, lineWidth: 1.5))
                                Text(line).font(.system(size: 17, weight: .bold)).foregroundStyle(Palette.ink)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20).padding(.bottom, 16)
            }
            VStack(spacing: 10) {
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview("武林盟主", image: shareImage)) {
                        Text("发给家人看看").font(Fonts.display(22)).frame(maxWidth: .infinity).frame(height: 50)
                            .background(Palette.gold).foregroundStyle(Palette.ink)
                            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                            .compositingGroup().shadow(color: Palette.ink, radius: 0, x: 3, y: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("shareCard")
                }
                RegionCard.button("回江湖", primary: false) { j.screen = .map }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(Palette.mist)
        .accessibilityIdentifier("finale")
        .task {
            let r = ImageRenderer(content: ShareCardView(lines: j.finaleLines))
            r.scale = 3
            if let ui = r.uiImage { shareImage = Image(uiImage: ui) }
        }
    }
}

/// 发给家人的卡片：红印、一句话、几个数。
struct ShareCardView: View {
    let lines: [String]

    var body: some View {
        VStack(spacing: 14) {
            LeaderSeal(size: 84)
            Text("我当上了武林盟主").font(Fonts.display(26)).foregroundStyle(Palette.ink)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines, id: \.self) { Text($0).font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink) }
            }
            Text("Type Pinyin · 拼音打字").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.slate)
        }
        .padding(24)
        .frame(width: 320)
        .background(Color(hex: 0xFFF6D6))
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
    }
}

/// 走完最后一座岛：妙笔书生的请帖（只弹一次）。
struct InvitationView: View {
    let text: String
    let signature: String
    let onGo: () -> Void
    let onLater: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture(perform: onLater)
            VStack(alignment: .leading, spacing: 14) {
                Text("请帖").font(Fonts.display(30)).foregroundStyle(Palette.red)
                Text(text).font(Fonts.hanzi(18)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                Text("—— \(signature)").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.slate)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                HStack(spacing: 10) {
                    RegionCard.button("先等等", primary: false, action: onLater)
                    RegionCard.button("上山", primary: true, action: onGo)
                }
            }
            .padding(20)
            .background(Color(hex: 0xFFF6D6))
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            .compositingGroup().shadow(color: Palette.ink, radius: 0, x: 5, y: 5)
            .padding(.horizontal, 24)
        }
        .accessibilityIdentifier("invitation")
    }
}
