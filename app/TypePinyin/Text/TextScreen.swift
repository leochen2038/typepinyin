import DuelCore
import SwiftUI

/// 打文字的界面（试玩）：上面是故事（短句）或和之前的你赛跑（文章），中间是这一句的牌，下面是同一个键盘。
struct TextScreen: View {
    let c: DuelController
    @State private var t: TextController
    @State private var showPanel = false
    /// 边打边爆的最后一击：震屏走到第几秒（从 0 动画到 1.1）。
    @State private var shakeT: CGFloat = 0

    /// 旅程的奇遇：篇目和打完后的按钮。
    var encounter: TextController.Passage?
    var onEncounterDone: (() -> Void)?
    /// 练习场：顶上多一个「返回」，打到一半也能走；打完的按钮写 doneLabel。
    var onLeave: (() -> Void)?
    var doneLabel: String?
    /// 打完的结算里多写一行（比如「你已经能打出 N 个常用字」）。
    var resultNote: (() -> String?)?
    /// 碑文：中间写这一关的概况（练什么、例字、几个音节 / 词卡 / 比武）。
    var brief: SteleBrief?

    init(c: DuelController, encounter: TextController.Passage? = nil, onFinish: ((TextController) -> Void)? = nil,
         onEncounterDone: (() -> Void)? = nil, onLeave: (() -> Void)? = nil, doneLabel: String? = nil,
         guided: Bool = false, guideSyllables: Set<String> = [], resultNote: (() -> String?)? = nil, brief: SteleBrief? = nil,
         raceBest: Bool = false) {
        self.c = c
        self.brief = brief
        self.encounter = encounter
        self.onEncounterDone = onEncounterDone
        self.onLeave = onLeave
        self.doneLabel = doneLabel
        self.resultNote = resultNote
        let tc = TextController(c: c)
        tc.given = encounter
        tc.onFinish = onFinish
        tc.guided = guided
        tc.guideSyllables = guideSyllables
        tc.raceBest = raceBest
        _t = State(initialValue: tc)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 返回放在手势层外面：顶栏整条盖着调参面板的手势，会挡住按钮
                if let onLeave {
                    Button(action: onLeave) {
                        Text("返回").font(.system(size: 15, weight: .black)).foregroundStyle(Palette.ink)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.white).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                }
                header
                    .overlay(PanelGesture { showPanel = true })
            }
            Rectangle().fill(Palette.ink).frame(height: 3)
            VStack(spacing: 0) {
                top
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.navy)
                    .overlay { InkImpact(at: t.impactAt, below: 3 + SentenceArea.cardCenterY) }
                Rectangle().fill(Palette.ink).frame(height: 3)
                SentenceArea(t: t)
                    .zIndex(1)
            }
            .modifier(ImpactShake(t: shakeT))
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
        .onChange(of: t.impactAt) { _, at in
            if at < 0 { shakeT = 0 } else { withAnimation(.linear(duration: ImpactShake.duration)) { shakeT = ImpactShake.duration } }
        }
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
        if t.raceBest, t.bestCPM != nil {
            // 练习场打完过的篇目：和最好的你赛跑
            VStack(alignment: .leading, spacing: 18) {
                Text(t.passage?.source ?? t.passage?.intro ?? "").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                // 要追的在上面，自己在下面、挨着正在打的那句（眼睛在牌上，往上一瞟先看到自己这条在长）
                RaceLane(label: "最好的你", done: t.ghostChars, total: Double(t.totalChars), color: .white.opacity(0.45))
                RaceLane(label: "你", done: Double(t.charsDone), total: Double(t.totalChars), color: Palette.gold)
                Text(String(format: "%.0f 字/分　最好的你 %.0f 字/分", t.cpm, t.ghostCPM))
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white).monospacedDigit()
            }
            .padding(20)
        } else if t.isArticle {
            VStack(alignment: .leading, spacing: 18) {
                Text(t.passage?.intro ?? "").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                // 要追的在上面，自己在下面、挨着正在打的那句（眼睛在牌上，往上一瞟先看到自己这条在长）
                RaceLane(label: "之前的你", done: t.ghostChars, total: Double(t.totalChars), color: .white.opacity(0.45))
                RaceLane(label: "你", done: Double(t.charsDone), total: Double(t.totalChars), color: Palette.gold)
                Text(String(format: "%.0f 字/分　之前的你 %.0f 字/分", t.cpm, t.ghostCPM))
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(.white).monospacedDigit()
            }
            .padding(20)
        } else if let brief {
            SteleBriefView(intro: t.passage?.intro ?? "", brief: brief)
                .padding(.horizontal, 16).padding(.vertical, 12)
        } else {
            VStack(spacing: 14) {
                Text(t.passage?.intro ?? "")
                    .font(Fonts.hanzi(18)).foregroundStyle(.white).multilineTextAlignment(.center)
                if let src = t.passage?.source {
                    Text(src).font(Fonts.hanzi(14)).foregroundStyle(.white.opacity(0.7))
                }
                Text("第 \(min(t.index + 1, t.sentences.count)) / \(t.sentences.count) 句")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.gold)
                if t.raceBest {                              // 练习场、还没打完过：告诉玩家下次能比
                    Text("打完一次，下次就能和这次的你比速度")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(24)
        }
    }

    private var result: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                Text(t.isArticle ? "打完了" : (t.passage?.reply ?? "")).font(Fonts.display(26))
                if t.raceBest {
                    raceBestResult
                } else if t.isArticle {
                    let diff = t.cpm - t.ghostCPM
                    if diff > 0.5 { Text(String(format: "比之前的你快了 %.0f 字/分！", diff)).font(.system(size: 16, weight: .black)).foregroundStyle(Palette.red) }
                    else { Text("和之前的你差不多").font(.system(size: 16, weight: .bold)) }
                    Text(String(format: "速度 %.0f 字/分", t.cpm)).font(.system(size: 15, weight: .bold))
                } else if t.perfects > 0 {
                    Text("打出 \(t.perfects) 句完美").font(.system(size: 15, weight: .bold))
                }
                Text(String(format: "用时 %d:%02d　打了 %d 个字", Int(t.elapsed) / 60, Int(t.elapsed) % 60, t.totalChars))
                    .font(.system(size: 15, weight: .bold))
                if let note = resultNote?() {
                    Text(note).font(.system(size: 15, weight: .black)).foregroundStyle(Palette.red)
                }
                Button {
                    if let done = onEncounterDone { done() } else { t.start(mode: c.tuning.textMode) }
                } label: {
                    Text(doneLabel ?? (onEncounterDone != nil ? "接着走" : "再来一次")).font(Fonts.display(20)).frame(maxWidth: .infinity).padding(.vertical, 10)
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

extension TextScreen {
    /// 练习场打完一篇：只报收获——新纪录说快了多少，第一次说记下了、下次能比；没破纪录就报这次的速度，差得不多说「差不多」。
    @ViewBuilder var raceBestResult: some View {
        Text(String(format: "速度 %.0f 字/分", t.cpm)).font(.system(size: 16, weight: .black))
        if let old = t.previousBest {
            if t.newBest {
                Text("新纪录！比最好的你快了 \(Int(t.cpm.rounded() - old.rounded())) 字/分").font(.system(size: 16, weight: .black)).foregroundStyle(Palette.red)
            } else if t.cpm >= old * 0.9 {
                Text("和最好的你差不多").font(.system(size: 15, weight: .bold))
            }
        } else {
            Text("记下了，下次和这次的你比").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.red)
        }
    }
}

/// 碑上写的这一关概况。
struct SteleBrief {
    /// 这一关练什么，比如「an en in」。
    var focus: String
    /// 一句说明。
    var note: String
    /// 「43 个新音节」「465 张词卡」「9 场比武」。
    var facts: [String]
}

/// 碑文页中间：门口的一句话，下面一块写这一关练什么和几个数。放不下时去掉说明。
struct SteleBriefView: View {
    let intro: String
    let brief: SteleBrief

    var body: some View {
        ViewThatFits(in: .vertical) {
            layout(note: true)
            layout(note: false)
        }
    }

    private func layout(note: Bool) -> some View {
        VStack(spacing: 12) {
            Text(intro).font(Fonts.hanzi(16)).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 8) {
                Text("这一关练").font(.system(size: 13, weight: .black)).foregroundStyle(Palette.gold)
                Text(brief.focus).font(Fonts.display(28)).foregroundStyle(.white)
                if note {
                    Text(brief.note).font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
                Text(brief.facts.joined(separator: " · ")).font(.system(size: 14, weight: .black)).foregroundStyle(Palette.gold)
                    .monospacedDigit().padding(.top, 2)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.07))
            .overlay(Rectangle().stroke(.white.opacity(0.3), lineWidth: 2))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("steleBrief")
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
    /// 牌中心离这一块顶上多远（上下各留 10，150 高里牌 104、下一句一行，竖着居中）：冲击帧的线朝这里收。
    static let cardCenterY: CGFloat = 10 + 61

    var body: some View {
        content
            .overlay(alignment: .topTrailing) { PerfectStamp(at: t.perfectAt) }
            .coordinateSpace(.named("duel"))             // 牌的位置按这一块量，回顾牌画在同一块里，位置不会量偏
            .onPreferenceChange(CardFrameKey.self) { cardFrames = $0 }
            .overlay {                                   // 战斗动效：回顾牌就在这句牌原位（和比武同一个回顾层）
                ReviewLayer(reviews: t.reviews, cardFrames: cardFrames, big: true,
                            rank: t.c.tuning.rankFx, theme: t.c.tuning.rankFxTheme)
            }
            .overlay {                                   // 边打边爆：打完的句子从牌位往上翻走、一路爆字母
                if let f = cardFrames[0] {
                    ZStack(alignment: .topLeading) {
                        ForEach(t.bursts) { r in
                            FlyingCard(review: r, frame: f, rank: t.c.tuning.rankFx, theme: t.c.tuning.rankFxTheme)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
                }
            }
            .overlay {                                   // 同行边爆边出：旧的这句盖在原位，刀光扫过的地方爆开、露出下面的新句子
                if let f = cardFrames[0], !t.sweeps.isEmpty {
                    ZStack(alignment: .topLeading) {
                        ForEach(t.sweeps) { s in SweepLayer(sweep: s, frame: f) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
                }
            }
            .padding(.vertical, 10)
    }

    private var content: some View {
        VStack(spacing: 8) {
            if t.current != nil {
                if t.burstMode && t.rollsIn {
                    // 边打边爆：这一句从下面升上来；牌的位置在升的外面量，回顾牌、飞走的牌对着它停好的地方
                    card(at: t.index, typed: t.typed, reportsFrame: false)
                        .modifier(RollIn())
                        .id(t.index)
                        .background(GeometryReader { g in
                            Color.clear.preference(key: CardFrameKey.self, value: [0: g.frame(in: .named("duel"))])
                        })
                        .opacity(t.covered ? 0 : 1)
                } else if t.burstMode {
                    card(at: t.index, typed: t.typed).id(t.index)   // 同行边爆边出：新的一句就在原位，上面盖着正被扫掉的旧句子
                        .opacity(t.covered ? 0 : 1)
                } else {
                    // 换句子像翻页钟，从下往上翻：旧的下半截往上翻起，新的上半截再翻上来
                    SplitFlap(back: t.flipFrom.map { AnyView(card(at: $0, typed: nil).allowsHitTesting(false)) },
                              front: AnyView(card(at: t.index, typed: t.typed).id(t.index)),
                              start: t.flipAt)
                        .opacity(t.covered ? 0 : 1)
                }
            }
            Text(t.sentences.indices.contains(t.index + 1) ? t.sentences[t.index + 1].text : " ")
                .font(Fonts.hanzi(15)).foregroundStyle(Palette.slate.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .frame(height: 150)                              // 固定高度：句子长短不同，上面的故事区不跟着跳
    }

    /// 第 k 句的牌；typed 为 nil 时是打完的样子（翻页时翻下去的那张）。
    @ViewBuilder private func card(at k: Int, typed: Int?, reportsFrame: Bool? = nil) -> some View {
        let s = t.sentences[k]
        let n = typed ?? s.letters.count
        if t.battleStyle {
            BattleSentenceCard(card: DuelController.CardVM(id: k, text: String(s.chars), syllables: s.syllables,
                                                           typed: String(s.letters.prefix(n)), weight: "", volumeLabel: "",
                                                           store: 1, flaw: false, finisher: false, locked: true, inactive: false),
                               shake: typed == nil ? 0 : t.shake, reportsFrame: reportsFrame ?? (typed != nil))
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

// Motion Prompt #156 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#156
/// 边打边爆：下一句从下面升上来（参考 Motion Prompt #156 テキストロール：0.36 秒，从 40 点下面升到原位）。
/// 原版藏在一个只露一行的框里，这里不裁，改成从半透明渐显，升的时候就能打。
/// 先顿 0.08 秒再升（和飞走的那句一起）：新牌、飞走的牌都在打完那一帧建好，那一帧慢，放在不动的时候就看不出卡。
struct RollIn: ViewModifier {
    static let duration = 0.36
    static let rise: CGFloat = 40
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? 0 : Self.rise)
            .opacity(up ? 1 : 0.2)
            .onAppear { withAnimation(FlyingCard.curve.delay(TextController.popDelay)) { up = true } }
    }
}

/// 边打边爆：打完的这句从牌位往上翻出去（参考 Motion Prompt #156：0.36 秒；原版走一行高，这里走一整张牌高，让出牌位），
/// 一路一个字母接一个字母爆开（回顾牌同一种画法），爆完放大散去。
/// 缓动改成三次缓出（原版缓入缓出）：缓入那一段牌停着不动、字母已经在爆，看着像卡住再猛地一窜；缓出是一下被打飞、慢慢停住。
struct FlyingCard: View {
    let review: DuelController.Review
    let frame: CGRect
    let rank: Int
    let theme: String
    @State private var up = false
    /// 三次缓出（easeOutCubic）。
    static let curve = Animation.timingCurve(0.215, 0.61, 0.355, 1, duration: RollIn.duration)

    var body: some View {
        // 收掉时只改外面的缩放和透明，牌里面不重画（重画会把字母、纸屑的图再画一遍，又卡一下）
        var still = review
        still.leaving = false
        return ReviewCard(review: still, card: frame.size, rank: rank, theme: theme, nudges: false)
            .equatable()
            .offset(y: up ? -(frame.height + 12) : 0)
            .scaleEffect(review.leaving ? 1.12 : 1)       // 比原位回顾的 1.3 小：下面就是正在打的这句，别盖住它
            .opacity(review.leaving ? 0 : 1)
            .animation(.easeOut(duration: 0.18), value: review.leaving)
            .position(x: frame.midX, y: frame.midY)
            .onAppear { withAnimation(Self.curve.delay(TextController.popDelay)) { up = true } }   // 先顿一下（同 RollIn）
    }
}

// Motion Prompt #024 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#024
/// 边打边爆的最后一击：震屏（Motion Prompt #024 インパクトシェイク），落下后 1.1 秒：
/// x 15·e^(−5t)·sin(2π·5t)，y 11·e^(−5t)·cos(2π·6.5t)，绕中心转 0.02·e^(−5t)·sin(2π·5t + 0.6) 弧度。
struct ImpactShake: GeometryEffect {
    static let duration: CGFloat = 1.1
    var t: CGFloat
    var animatableData: CGFloat {
        get { t }
        set { t = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard t > 0 && t < Self.duration else { return ProjectionTransform(.identity) }
        let e = exp(-5 * t), ph = 2 * CGFloat.pi * 5 * t
        let dx = 15 * e * sin(ph), dy = 11 * e * cos(ph * 1.3), rot = 0.02 * e * sin(ph + 0.6)
        let m = CGAffineTransform(translationX: size.width / 2 + dx, y: size.height / 2 + dy)
            .rotated(by: rot)
            .translatedBy(x: -size.width / 2, y: -size.height / 2)
        return ProjectionTransform(m)
    }
}

/// 边打边爆的最后一击：冲击帧，和比武最后一刀同一套（墨色和米白，按 30 帧算）：
/// 前 2 帧米白底、64 道墨色放射线从画面外冲向牌（约两成是粗线），接 2 帧反色（墨底白线），再 4 帧线往外退出画面、淡掉，一共约 0.27 秒。
/// 盖在上面的故事区（相当于比武的场景），牌和键盘不盖；线朝下面的牌收（below = 牌中心在这块底边下面多远）。
struct InkImpact: View {
    let at: Double
    let below: CGFloat
    static let frame = 1.0 / 30
    static let total = 8 * frame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: CACurrentMediaTime() - at > Self.total + 0.1)) { _ in
            let dt = CACurrentMediaTime() - at
            if !reduceMotion && dt >= 0 && dt < Self.total {
                Canvas { ctx, size in
                    let paper = Color(red: 0.965, green: 0.945, blue: 0.902)
                    let phase = dt < 2 * Self.frame ? 0 : dt < 4 * Self.frame ? 1 : 2
                    if phase < 2 { ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(phase == 0 ? paper : Palette.ink)) }
                    let p = phase == 2 ? min(1, (dt - 4 * Self.frame) / (4 * Self.frame)) : 0
                    var g = ctx
                    g.translateBy(x: size.width / 2, y: size.height + below)
                    g.scaleBy(x: 1 + 1.4 * p * p, y: 1 + 1.4 * p * p)
                    g.opacity = 1 - 0.8 * p
                    g.fill(Self.lines(width: size.width, reach: hypot(size.width, size.height + below) + 40),
                           with: .color(phase == 1 ? paper : Palette.ink))
                }
                .allowsHitTesting(false)
            }
        }
    }

    /// 64 道放射线：尖头朝着牌，往外变宽，伸出画面（固定的随机数，每次一样）。
    static func lines(width: CGFloat, reach: CGFloat) -> Path {
        var rng = SeededRandom(seed: 0x1D2C)
        let k = width / 320
        var path = Path()
        let n = 64
        for i in 0..<n {
            let thick = rng.uniform(0, 1) < 0.18
            let a = (Double(i) + rng.uniform(0.1, 0.9)) / Double(n) * 2 * .pi
            let inner = CGFloat(thick ? rng.uniform(30, 48) : rng.uniform(18, 70)) * k
            let half = CGFloat(thick ? rng.uniform(5, 8) : rng.uniform(1.2, 3.6)) * k
            let d = CGVector(dx: cos(a), dy: sin(a)), q = CGVector(dx: -d.dy, dy: d.dx)
            path.move(to: CGPoint(x: d.dx * inner, y: d.dy * inner))
            path.addLine(to: CGPoint(x: d.dx * reach + q.dx * half, y: d.dy * reach + q.dy * half))
            path.addLine(to: CGPoint(x: d.dx * reach - q.dx * half, y: d.dy * reach - q.dy * half))
            path.closeSubpath()
        }
        return path
    }
}

/// 同行边爆边出：旧的这句原样盖在牌位上，只露刀光右边还没扫到的那截；刀光、爆开的字、彩纸画在上面（不裁）。
struct SweepLayer: View {
    let sweep: TextController.Sweep
    let frame: CGRect

    var body: some View {
        BattleSentenceCard(card: sweep.old, shake: 0, reportsFrame: false)
            .environment(\.reportsColumns, true)
            .frame(width: frame.width, height: frame.height)
            .mask(alignment: .leading) {
                // 只有遮罩跟着时间走，旧句子本身不重排
                TimelineView(.animation(paused: Date().timeIntervalSinceReferenceDate > sweep.start + sweep.duration + 0.1)) { tl in
                    Rectangle().padding(.leading, frame.width * sweep.progress(at: tl.date.timeIntervalSinceReferenceDate))
                }
            }
            .overlayPreferenceValue(ColumnBoundsKey.self) { anchors in
                GeometryReader { g in
                    SweepSparks(sweep: sweep, columns: anchors.map { g[$0] }, size: frame.size)
                        .position(x: frame.width / 2, y: frame.height / 2)
                }
            }
            .position(x: frame.midX, y: frame.midY)
    }
}

/// 同行边爆边出的刀光和爆开的字（一块画布按时间画，字和彩纸先画成符号）：
/// 刀光是一道斜的红芯墨边的刀痕，带一圈白光，从左匀速扫到右；扫到一个字的中线，这个字和它的拼音一起
/// 白光一圈（0.2 秒）、放大到 1.45 倍淡掉（0.22 秒），字上迸一团彩纸、拼音上迸一小撮（和打完一个字迸的同一种）。
/// 放大、淡掉都收着点：下面就是新的一句，旧字放太大、留太久会挡着看。
struct SweepSparks: View {
    let sweep: TextController.Sweep
    let columns: [CGRect]
    let size: CGSize
    static let pad: CGFloat = 90

    private enum Tag { static let pinyin = 1000, char = 2000, confetti = 3000 }

    var body: some View {
        let chars = Array(sweep.old.text)
        let charSize = WordColumns.fitSize(sweep.old.syllables, width: UIScreen.main.bounds.width - 32 - 24, gap: 4)
        TimelineView(.animation(paused: Date().timeIntervalSinceReferenceDate > sweep.start + sweep.duration + 1.6)) { tl in
            let now = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, _ in draw(ctx, now: now, charSize: charSize) } symbols: {
                ForEach(symbolIDs(chars.count), id: \.self) { id in
                    switch id {
                    case Tag.confetti...: Confetti.symbol(id, base: Tag.confetti).tag(id)
                    case Tag.char...:
                        Text(String(chars[id - Tag.char])).font(Fonts.hanzi(charSize)).foregroundStyle(Palette.red).tag(id)
                    default:
                        let k = id - Tag.pinyin
                        Text(k < sweep.old.syllables.count ? sweep.old.syllables[k] : "")
                            .font(Fonts.mono(charSize * 0.5, weight: .bold)).foregroundStyle(Palette.red).tag(id)
                    }
                }
            }
        }
        .frame(width: size.width + Self.pad * 2, height: size.height + Self.pad * 2)
        .allowsHitTesting(false)
    }

    private func symbolIDs(_ n: Int) -> [Int] {
        (0..<n).map { Tag.pinyin + $0 } + (0..<n).map { Tag.char + $0 } + Confetti.symbolIDs(base: Tag.confetti)
    }

    private func draw(_ ctx: GraphicsContext, now: Double, charSize: CGFloat) {
        var g = ctx
        g.translateBy(x: Self.pad, y: Self.pad)
        let p = sweep.progress(at: now)
        // 刀光：上头往右斜一点，像一刀从上往下劈过去的痕
        if p > 0 && p < 1 {
            let x = size.width * p
            var cut = Path()
            cut.move(to: CGPoint(x: x + 9, y: -10))
            cut.addLine(to: CGPoint(x: x - 9, y: size.height + 10))
            g.stroke(cut, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 16, lineCap: .round))
            g.stroke(cut, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 8, lineCap: .round))
            g.stroke(cut, with: .color(Palette.red), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
        for (k, col) in columns.enumerated() {
            let at = sweep.start + sweep.duration * Double(min(1, max(0, col.midX / max(1, size.width))))
            let dt = now - at
            guard dt >= 0 && dt < 1.5 else { continue }
            // 一列里上面是字、下面是拼音（字那行约占三分之二高）
            let charP = CGPoint(x: col.midX, y: col.minY + col.height * 0.34)
            let pyP = CGPoint(x: col.midX, y: col.minY + col.height * 0.84)
            if dt < 0.2 {                                 // 一圈白光
                let e = 1 - pow(1 - dt / 0.2, 3)
                let r = charSize * (0.3 + 0.8 * e)
                g.stroke(Path(ellipseIn: CGRect(x: charP.x - r, y: charP.y - r, width: r * 2, height: r * 2)),
                         with: .color(.white.opacity(1 - dt / 0.2)), lineWidth: 5 * (1 - dt / 0.2) + 1)
            }
            if dt < 0.22 {                                // 字和拼音放大淡掉
                let e = 1 - pow(1 - dt / 0.22, 3)
                for (id, pt) in [(Tag.char + k, charP), (Tag.pinyin + k, pyP)] {
                    var l = g
                    l.translateBy(x: pt.x, y: pt.y)
                    l.scaleBy(x: 1 + 0.45 * e, y: 1 + 0.45 * e)
                    l.opacity = 1 - dt / 0.22
                    if let sym = l.resolveSymbol(id: id) { l.draw(sym, at: .zero) }
                }
            }
            Confetti.draw(g, at: charP, seed: k, t: dt, base: Tag.confetti)
            Confetti.draw(g, at: pyP, seed: k + 40, t: dt, count: 4, base: Tag.confetti)
        }
    }
}
