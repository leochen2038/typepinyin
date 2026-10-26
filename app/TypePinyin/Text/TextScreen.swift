import DuelCore
import SwiftUI

/// 打文字的界面（试玩）：上面是故事（短句）或和之前的你赛跑（文章），中间是这一句的牌，下面是同一个键盘。
struct TextScreen: View {
    let c: DuelController
    @State private var t: TextController
    @State private var showPanel = false

    /// 旅程的奇遇：篇目和打完后的按钮。
    var encounter: TextController.Passage?
    var onEncounterDone: (() -> Void)?

    init(c: DuelController, encounter: TextController.Passage? = nil, onFinish: ((TextController) -> Void)? = nil,
         onEncounterDone: (() -> Void)? = nil) {
        self.c = c
        self.encounter = encounter
        self.onEncounterDone = onEncounterDone
        let tc = TextController(c: c)
        tc.given = encounter
        tc.onFinish = onFinish
        _t = State(initialValue: tc)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .overlay(PanelGesture { showPanel = true })
            Rectangle().fill(Palette.ink).frame(height: 3)
            top
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.navy)
            Rectangle().fill(Palette.ink).frame(height: 3)
            SentenceArea(t: t)
                .padding(.vertical, 10)
                .zIndex(1)
            KeyboardHost(controller: t)
                .background(Palette.mist2.ignoresSafeArea(edges: .bottom))
                .background(KeyInputHost(controller: t).frame(width: 1, height: 1).opacity(0.01))
        }
        .background(Palette.mist)
        .overlay { if t.finished { result } }
        .sheet(isPresented: $showPanel) { TuningPanelView(c: c) }
        .onAppear { c.suspend(); t.start(mode: encounter != nil ? 1 : c.tuning.textMode) }
        .onDisappear { t.stop() }
        .onChange(of: c.tuning.textMode) { _, m in if m != 0 && encounter == nil { t.start(mode: m) } }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(t.passage?.title ?? "").font(Fonts.display(20))
            Spacer()
            Text(String(format: "%d:%02d", Int(t.elapsed) / 60, Int(t.elapsed) % 60))
                .font(Fonts.display(20)).monospacedDigit()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder private var top: some View {
        if t.isArticle {
            VStack(alignment: .leading, spacing: 18) {
                Text(t.passage?.intro ?? "").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                RaceLane(label: "你", done: Double(t.charsDone), total: Double(t.totalChars), color: Palette.gold)
                RaceLane(label: "之前的你", done: t.ghostChars, total: Double(t.totalChars), color: .white.opacity(0.45))
                Text(String(format: "%.0f 字/分　之前的你 %.0f 字/分", t.cpm, t.ghostCPM))
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white).monospacedDigit()
            }
            .padding(20)
        } else {
            VStack(spacing: 14) {
                Text(t.passage?.intro ?? "")
                    .font(Fonts.hanzi(18)).foregroundStyle(.white).multilineTextAlignment(.center)
                if let src = t.passage?.source {
                    Text(src).font(Fonts.hanzi(14)).foregroundStyle(.white.opacity(0.7))
                }
                Text("第 \(min(t.index + 1, t.sentences.count)) / \(t.sentences.count) 句")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.gold)
            }
            .padding(24)
        }
    }

    private var result: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Text(t.isArticle ? "打完了" : (t.passage?.reply ?? "")).font(Fonts.display(26))
                if t.isArticle {
                    let diff = t.cpm - t.ghostCPM
                    if diff > 0.5 { Text(String(format: "比之前的你快了 %.0f 字/分！", diff)).font(.system(size: 16, weight: .black)).foregroundStyle(Palette.red) }
                    else { Text("和之前的你差不多").font(.system(size: 16, weight: .bold)) }
                    Text(String(format: "速度 %.0f 字/分", t.cpm)).font(.system(size: 15, weight: .bold))
                } else if t.perfects > 0 {
                    Text("打出 \(t.perfects) 句完美").font(.system(size: 15, weight: .bold))
                }
                Text(String(format: "用时 %d:%02d　打了 %d 个字", Int(t.elapsed) / 60, Int(t.elapsed) % 60, t.totalChars))
                    .font(.system(size: 15, weight: .bold))
                Button {
                    if let done = onEncounterDone { done() } else { t.start(mode: c.tuning.textMode) }
                } label: {
                    Text(onEncounterDone != nil ? "接着走" : "再来一次").font(Fonts.display(20)).frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(Palette.gold).overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .background(Color.white)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            .padding(28)
        }
    }
}

/// 和之前的你赛跑的一条道：一条进度条，头上一个小人。
struct RaceLane: View {
    let label: String
    let done: Double
    let total: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.85))
            GeometryReader { g in
                let k = total > 0 ? min(1, done / total) : 0
                ZStack(alignment: .leading) {
                    Rectangle().fill(.white.opacity(0.15))
                    Rectangle().fill(color).frame(width: g.size.width * k)
                }
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
            }
            .frame(height: 12)
        }
    }
}

/// 中间：这一句放在牌上（字和拼音逐字对齐），下方露出下一句（上面不显示打过的句子）。
struct SentenceArea: View {
    let t: TextController
    @State private var cardFrames: [Int: CGRect] = [:]

    var body: some View {
        content
            .overlay(alignment: .topTrailing) { PerfectStamp(at: t.perfectAt) }
            .coordinateSpace(.named("duel"))             // 牌的位置按这一块量，回顾牌画在同一块里，位置不会量偏
            .onPreferenceChange(CardFrameKey.self) { cardFrames = $0 }
            .overlay {                                   // 战斗动效：回顾牌就在这句牌原位（和比武同一个回顾层）
                ReviewLayer(reviews: t.reviews, cardFrames: cardFrames, big: true,
                            rank: t.c.tuning.rankFx, theme: t.c.tuning.rankFxTheme)
            }
    }

    private var content: some View {
        VStack(spacing: 8) {
            if t.current != nil {
                // 换句子像翻页钟，从下往上翻：旧的下半截往上翻起，新的上半截再翻上来
                SplitFlap(back: t.flipFrom.map { AnyView(card(at: $0, typed: nil).allowsHitTesting(false)) },
                          front: AnyView(card(at: t.index, typed: t.typed).id(t.index)),
                          start: t.flipAt)
                    .opacity(t.covered ? 0 : 1)
            }
            Text(t.sentences.indices.contains(t.index + 1) ? t.sentences[t.index + 1].text : " ")
                .font(Fonts.hanzi(15)).foregroundStyle(Palette.slate.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .frame(height: 150)                              // 固定高度：句子长短不同，上面的故事区不跟着跳
    }

    /// 第 k 句的牌；typed 为 nil 时是打完的样子（翻页时翻下去的那张）。
    @ViewBuilder private func card(at k: Int, typed: Int?) -> some View {
        let s = t.sentences[k]
        let n = typed ?? s.letters.count
        if t.battleStyle {
            BattleSentenceCard(card: DuelController.CardVM(id: k, text: String(s.chars), syllables: s.syllables,
                                                           typed: String(s.letters.prefix(n)), weight: "", volumeLabel: "",
                                                           store: 1, flaw: false, finisher: false, locked: true, inactive: false),
                               shake: typed == nil ? 0 : t.shake, reportsFrame: typed != nil)
                .environment(\.rankFxOn, t.c.tuning.rankFx >= 1)
                .environment(\.rankFxTheme, t.c.tuning.rankFxTheme)
        } else {
            SentenceCard(sentence: s, typed: n, flash: typed == nil ? 0 : t.flash, perfect: t.flashPerfect,
                         shake: typed == nil ? 0 : t.shake, themed: t.c.tuning.rankFx >= 1, quick: true)
        }
    }
}

/// 一句的牌：每个字一列，拼音打到哪写到哪，打完一个字变红、迸粒子；打完一句牌一跳、金光一闪，完美的盖印。
struct SentenceCard: View {
    let sentence: TextController.Sentence
    let typed: Int
    let flash: Int
    let perfect: Bool
    let shake: Int
    let themed: Bool
    /// 短句：打完一句时半秒的原位快爆（字一个接一个弹一下）；文章：只一闪。
    let quick: Bool
    @State private var pop = false
    @State private var glow = false
    @State private var wave = -1

    var body: some View {
        let n = sentence.chars.count
        let size = WordColumns.fitSize(sentence.syllables, width: UIScreen.main.bounds.width - 32 - 24, gap: 2)
        let parts = partsTyped()
        HStack(alignment: .top, spacing: 2) {
            ForEach(0..<n, id: \.self) { k in
                VStack(spacing: 2) {
                    Text(String(sentence.chars[k])).font(Fonts.hanzi(size))
                        .foregroundStyle(parts[k].done ? Palette.red : Palette.ink)
                    ZStack {                             // 先按完整拼音占好宽度，长拼音不压到旁边的字
                        Text(sentence.syllables[k]).opacity(0)
                        Text(parts[k].text.isEmpty ? " " : parts[k].text)
                            .foregroundStyle(parts[k].done ? Palette.red : Palette.navy)
                    }
                    .font(Fonts.mono(max(9, size * 0.38), weight: .bold))
                    .lineLimit(1).fixedSize()
                }
                .scaleEffect(wave == k ? 1.35 : 1)
                .animation(.spring(duration: 0.12, bounce: 0.6), value: wave)
                .overlay(Burst(trigger: parts[k].done ? 1 : 0, volume: themed ? RankFx.volume(of: sentence.syllables[k]) : nil))
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 104)                              // 牌高固定：翻页钟上下两半才对得齐
        .background(Color(hex: 0xFFF6D6))
        .overlay(Rectangle().stroke(glow ? Palette.gold : Palette.ink, lineWidth: glow ? 5 : 3))
        .background(Rectangle().fill(Palette.ink).offset(x: 4, y: 4))
        .overlay(alignment: .topTrailing) {
            if glow && perfect {
                Text("完美").font(Fonts.display(16)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Palette.red))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.ink, lineWidth: 2))
                    .rotationEffect(.degrees(-10)).offset(x: 8, y: -12)
                    .transition(.scale(scale: 2).combined(with: .opacity))
            }
        }
        .scaleEffect(pop ? 1.06 : 1)
        .modifier(Shake(trigger: shake, enabled: true))
        .animation(.spring(duration: 0.25), value: shake)
        .onChange(of: flash) { _, _ in
            withAnimation(.spring(duration: 0.12, bounce: 0.6)) { pop = true; glow = true }
            if quick {                                   // 字一个接一个弹一下，0.4 秒内弹完
                let n = sentence.chars.count
                for k in 0..<n {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 * Double(k) / Double(max(1, n))) { wave = k }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (quick ? 0.42 : 0.15)) {
                withAnimation(.easeOut(duration: 0.15)) { pop = false; glow = false; wave = -1 }
            }
        }
    }

    /// 已打的字母按字分到每个字下面。
    private func partsTyped() -> [(text: String, done: Bool)] {
        var left = typed
        return sentence.syllables.map { s in
            let take = min(left, s.count)
            left -= take
            return (String(s.prefix(take)), take == s.count && !s.isEmpty)
        }
    }
}

/// 战斗动效的这句牌：用比武的字和拼音列（正在打的音节有下划线，打完一个字变红弹一下、迸粒子），回顾牌按它的位置翻出来。
struct BattleSentenceCard: View {
    let card: DuelController.CardVM
    let shake: Int
    /// 翻页时翻下去的那张不报位置，免得回顾牌对着它。
    var reportsFrame = true

    var body: some View {
        WordColumns(card: card, fitWidth: UIScreen.main.bounds.width - 32 - 24)   // 牌宽减去内边距：字号按这个宽度算
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 104)                          // 牌高固定：翻页钟上下两半才对得齐
            .background(Color(hex: 0xFFF6D6))
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            .background(Rectangle().fill(Palette.ink).offset(x: 4, y: 4))
            .background(GeometryReader { g in
                Color.clear.preference(key: CardFrameKey.self, value: reportsFrame ? [0: g.frame(in: .named("duel"))] : [:])
            })
            .modifier(Shake(trigger: shake, enabled: true))
            .animation(.spring(duration: 0.25), value: shake)
    }
}

/// 不要回顾时：打完一句又快又没错，牌角弹出「完美」，0.7 秒内缩回淡掉，不挡着打下一句。
struct PerfectStamp: View {
    let at: Double

    var body: some View {
        TimelineView(.animation(paused: CACurrentMediaTime() - at > 0.8)) { tl in
            let dt = CACurrentMediaTime() - at
            let k = min(1, max(0, dt / 0.7))
            Text("完美").font(Fonts.display(18)).foregroundStyle(.white)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Palette.red))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Palette.ink, lineWidth: 2))
                .rotationEffect(.degrees(-10))
                .scaleEffect(dt < 0.12 ? 1.8 - 6.6 * dt : 1)
                .opacity(dt < 0 || dt > 0.7 ? 0 : 1 - pow(k, 3))
                .padding(.trailing, 22).padding(.top, 14)
                .id(tl.date)
        }
        .allowsHitTesting(false)
    }
}

/// 翻页钟（从下往上翻，因为下一句露在牌下面）：back（刚打完的那句）的下半截往上翻起，露出 front（这一句）的下半截；
/// front 的上半截再从中间往上翻、落平，盖住旧的上半截。两张牌一样高，按中线切成上下两半各自翻。
struct SplitFlap: View {
    let back: AnyView?
    let front: AnyView
    let start: Double
    static let duration = 0.34 * DuelController.fxSlow   // -slowfx 时放慢 5 倍，方便截图看

    var body: some View {
        TimelineView(.animation(paused: back == nil || CACurrentMediaTime() - start > Self.duration)) { _ in
            let p = back == nil ? 1 : min(1, max(0, (CACurrentMediaTime() - start) / Self.duration))
            if p >= 1 || back == nil {
                front
            } else if let back {
                ZStack {
                    front.mask(Self.half(top: false))
                    back.mask(Self.half(top: true))
                    if p < 0.5 {                         // 旧的下半截往上翻起，翻到一半看不见
                        back.mask(Self.half(top: false))
                            .brightness(-0.25 * p * 2)
                            .rotation3DEffect(.degrees(180 * p), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.45)
                    } else {                             // 新的上半截从水平往上翻、落平
                        front.mask(Self.half(top: true))
                            .brightness(-0.25 * (1 - p) * 2)
                            .rotation3DEffect(.degrees(-180 * (1 - p)), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.45)
                    }
                }
            }
        }
    }

    /// 上半截或下半截的遮罩（按整张牌的中线切）。
    static func half(top: Bool) -> some View {
        VStack(spacing: 0) {
            Rectangle().fill(top ? Color.black : Color.clear)
            Rectangle().fill(top ? Color.clear : Color.black)
        }
    }
}
