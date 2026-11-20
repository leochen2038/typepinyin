import LearningCore
import SwiftUI

// 地图上的小卷轴（2026-11-20，调参「地图小卷轴」能关）：日历盖印、拿到勋章都在这里演，结算页不演。
// 什么时候展开：每天第一次回到地图；或者有还没盖的印、还没落下的勋章时回到地图（打完一场、从后台回来、地图上过了半夜）。
// 展开后：今天还空着就描一圈虚线（一天只描一次），今天的印盖下去（只演今天的：昨天没看到的不补，直接摆好），
// 再落新拿到的秘籍、一枚一枚落新勋章（每枚重震、一声），最后换上下一枚。只报已有的，不写还差、不写今天还没练。
// 收起时卷成一卷、飞进地图顶上的「收获」按钮，按钮弹一下、扩一圈波纹（Motion Prompt #071），告诉玩家去那里看。

/// 卷轴演过什么（只记在本机：另一台设备拿到的，回到这台的地图也演一次）。
enum ScrollReveal {
    private static let badgesKey = "scroll.revealedBadges", daysKey = "scroll.stampedDays", firstKey = "dailyScroll.day"
    private static let traceKey = "scroll.tracedDay", booksKey = "scroll.revealedBooks"

    /// 在卷轴上落过的新秘籍（卷名）。
    static var books: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: booksKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: booksKey) }
    }

    /// 今天那格的虚线描过没有（一天只描一次）。
    static func traced(on day: Int) -> Bool { UserDefaults.standard.integer(forKey: traceKey) == day + 1 }
    static func markTraced(_ day: Int) { UserDefaults.standard.set(day + 1, forKey: traceKey) }
    static func clearTraced() { UserDefaults.standard.removeObject(forKey: traceKey) }

    /// 清空进度时一起清掉：演过的印和勋章、今天展开过没有、描过没有。
    static func resetAll() {
        for k in [badgesKey, daysKey, firstKey, traceKey, booksKey] { UserDefaults.standard.removeObject(forKey: k) }
    }

    static var badges: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: badgesKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: badgesKey) }
    }

    static var days: Set<Int> {
        get { Set((UserDefaults.standard.array(forKey: daysKey) as? [Int]) ?? []) }
        set { UserDefaults.standard.set(Array(newValue.filter { $0 >= (newValue.max() ?? 0) - 60 }), forKey: daysKey) }   // 只留近两个月
    }

    /// 第一次用这一版：已有的印和勋章算演过了（不一下子补演一堆）。
    static var started: Bool { UserDefaults.standard.object(forKey: badgesKey) != nil }

    /// 今天展开过没有（+1：第 0 天也和「没展开过」分得开）。
    static func shownFirst(on day: Int) -> Bool { UserDefaults.standard.integer(forKey: firstKey) == day + 1 }
    static func markFirst(_ day: Int) { UserDefaults.standard.set(day + 1, forKey: firstKey) }
    static func clearFirst() { UserDefaults.standard.removeObject(forKey: firstKey) }
}

extension JourneyController {
    /// 打开 App 时：第一次用这一版，把已有的都算演过。
    func startScrollReveal() {
        guard !ScrollReveal.started else { return }
        ScrollReveal.badges = Set(progress.badges.keys)
        ScrollReveal.days = Set(practicedDays)
    }

    /// 还没盖的印：只算今天（今天练过、还没在卷轴上盖过）；以前没看到的不补演，日历上直接摆好。
    var pendingStamps: [Int] { daySummary(today) != nil && !ScrollReveal.days.contains(today) ? [today] : [] }

    /// 还没落下的勋章（按拿到的先后、台阶顺序）。
    var pendingBadges: [BadgeRecord] {
        let seen = ScrollReveal.badges
        let order = BadgeTrack.allCases
        return progress.badges.values.filter { !seen.contains($0.key) }
            .sorted { ($0.day, order.firstIndex(of: $0.track) ?? 0, $0.step) < ($1.day, order.firstIndex(of: $1.track) ?? 0, $1.step) }
    }

    /// 拿到了、还没在卷轴上落过的新秘籍。
    var pendingBooks: [String] { booksToUnveil.filter { !ScrollReveal.books.contains($0) } }

    /// 地图「收获」按钮上新秘籍的红点：卷轴上落过的就不算（书架上第一次翻开的演出照旧）。
    var hasNewBookDot: Bool {
        duel.tuning.dailyScrollOn ? !pendingBooks.isEmpty : !booksToUnveil.isEmpty
    }

    /// 回到地图（或在地图上回到前台、过了半夜）时：该展开就展开。
    func maybeShowDailyScroll() {
        guard duel.tuning.dailyScrollOn, screen == .map, !AppResources.isUITest, !Self.autoplay, !showDailyScroll,
              backfillCard == nil, !showInvitation, !invitationPending, !needsMapGuide, !practicedDays.isEmpty else { return }
        let fresh = !pendingStamps.isEmpty || !pendingBooks.isEmpty || (badgesOn && !pendingBadges.isEmpty)
        guard fresh || !ScrollReveal.shownFirst(on: today) else { return }
        ScrollReveal.markFirst(today)
        scrollShow = ScrollShow(day: today, stamps: pendingStamps, books: pendingBooks, badges: badgesOn ? pendingBadges : [])
        // 一展开就算演过（中途点「出发」收起，下次也不重演）
        ScrollReveal.days.formUnion(practicedDays)
        ScrollReveal.badges.formUnion(progress.badges.keys)
        ScrollReveal.books.formUnion(booksToUnveil)
        showDailyScroll = true
    }

    /// 调参面板：再看一次（今天的印和今天拿到的勋章重演一遍）。
    func replayDailyScroll() {
        ScrollReveal.clearFirst()
        ScrollReveal.clearTraced()
        ScrollReveal.days.remove(today)
        ScrollReveal.badges.subtract(progress.badges.values.filter { $0.day == today }.map(\.key))
        ScrollReveal.books.subtract(booksToUnveil)
        screen = .map
        maybeShowDailyScroll()
    }

    /// 调参面板「看今天那格描虚线」：回地图展开卷轴，今天那格当成还没练，演一遍描虚线（不改记录、不重演勋章）。
    func previewTodayTrace() {
        screen = .map
        scrollShow = ScrollShow(day: today, stamps: [], books: [], badges: [], previewTrace: true)
        showDailyScroll = true
    }

    /// 下一枚：五条台阶里离拿到最近的那一枚（按这一级走过的比例）。都收齐了返回 nil。
    var nextBadge: (track: BadgeTrack, step: Int)? {
        guard badgesOn else { return nil }
        let rules = badgeRules
        var best: (BadgeTrack, Int, Double)?
        for t in BadgeTrack.allCases {
            let steps = rules.steps(t)
            guard let k = steps.indices.first(where: { progress.badges[BadgeRecord.key(t, $0)] == nil }) else { continue }
            let hi = Double(rules.threshold(t, k, total: cardsInAll))
            let lo = k > 0 ? Double(rules.threshold(t, k - 1, total: cardsInAll)) : 0
            let r = (Double(badgeValue(t)) - lo) / max(1, hi - lo)
            if best == nil || r > best!.2 { best = (t, k, r) }
        }
        return best.map { ($0.0, $0.1) }
    }
}

/// 这一次卷轴要演的：展开那天、要盖的印、要落的勋章（展开时定下来，演的过程中不跟着变）。
struct ScrollShow: Equatable {
    var day: Int
    var stamps: [Int]
    /// 新拿到的秘籍（卷名）。
    var books: [String] = []
    var badges: [BadgeRecord]
    /// 调参面板「看今天那格描虚线」：今天那格当成还没练（不画印），演一遍描虚线；不改任何记录。
    var previewTrace = false
}

struct DailyScrollView: View {
    let j: JourneyController
    let show: ScrollShow
    let onClose: () -> Void
    /// 展开到多少（0 合着，1 全开）。
    @State private var open: CGFloat = 0
    /// 已经盖下去的印、已经落下的勋章（第几枚）。
    @State private var stamped: Set<Int> = []
    @State private var landed = 0
    @State private var booksLanded = 0
    /// 收起后飞向「收获」按钮走了多少（0…1）；卷轴在屏幕上的位置。
    @State private var fly: CGFloat = 0
    @State private var frame: CGRect = .zero
    @State private var closing = false
    /// 甩出去前往回缩、压扁蓄力（0…1）。
    @State private var wind: CGFloat = 0
    /// 「收获」按钮在屏幕上的位置（收起那一刻读）；nil = 不飞，原地收起。
    @State private var target: CGRect?
    /// 都演完了：换上下一枚。
    @State private var done = false
    /// 今天那格还空着：展开后描一圈虚线（0…1）。
    @State private var trace: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(j: JourneyController, show: ScrollShow, onClose: @escaping () -> Void) {
        self.j = j
        self.show = show
        self.onClose = onClose
        _trace = State(initialValue: ScrollReveal.traced(on: show.day) && !show.previewTrace ? 1 : 0)      // 今天描过了：虚线框直接摆着
    }

    static let weekNames = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.35 * open).ignoresSafeArea()
                .onTapGesture { close() }
                .accessibilityLabel("收起")
                .accessibilityAddTraits(.isButton)
            paper
                .modifier(ScrollRoll(p: open, fade: reduceMotion))
                .background(GeometryReader { g in
                    Color.clear.onAppear { frame = g.frame(in: .global) }
                        .onChange(of: g.frame(in: .global)) { _, f in if fly == 0 && wind == 0 { frame = f } }
                })
                .modifier(TossToTarget(t: fly, wind: wind, from: rollPoint, to: target.map { CGPoint(x: $0.midX, y: $0.midY) }))
                .padding(.horizontal, 22)
                .allowsHitTesting(!closing)
        }
        .task { await play() }
        .accessibilityAddTraits(.isModal)
    }

    /// 展开 → 盖印（每个 0.25 秒，轻震）→ 一枚一枚落勋章（每枚隔 0.45 秒，落定重震、一声）→ 换上下一枚。
    private func play() async {
        let fast = reduceMotion
        withAnimation(fast ? .easeOut(duration: 0.2) : .easeOut(duration: 0.55)) { open = 1 }
        try? await Task.sleep(for: .seconds(fast ? 0.25 : 0.6))
        if !fast { j.duel.sounds.hitHaptic(heavy: false) }               // 轴拉到头
        if todayEmpty && (show.previewTrace || !ScrollReveal.traced(on: show.day)) {   // 今天那格空着：描一圈虚线（一天只描一次）
            if !show.previewTrace { ScrollReveal.markTraced(show.day) }
            withAnimation(fast ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.6)) { trace = 1 }
            try? await Task.sleep(for: .seconds(fast ? 0.2 : 0.6))
        }
        for d in show.stamps where d == show.day {
            try? await Task.sleep(for: .seconds(fast ? 0.05 : 0.2))
            if Task.isCancelled { return }
            withAnimation(fast ? .easeOut(duration: 0.2) : .easeIn(duration: 0.25)) { _ = stamped.insert(d) }
            try? await Task.sleep(for: .seconds(fast ? 0.2 : 0.25))
            j.duel.sounds.play(.hitHeavy)                                  // 盖下去：和勋章落下一样，重击一声、重震
            j.duel.sounds.hitHaptic(heavy: true)
        }
        for i in show.books.indices {                                    // 新秘籍：一本一本落下
            try? await Task.sleep(for: .seconds(i == 0 ? 0.3 : fast ? 0.15 : 0.45))
            if Task.isCancelled { return }
            withAnimation(fast ? .easeOut(duration: 0.2) : .easeOut(duration: 0.32)) { booksLanded = i + 1 }
            try? await Task.sleep(for: .seconds(fast ? 0.2 : 0.32))
            j.duel.sounds.play(.hitHeavy)
            j.duel.sounds.hitHaptic(heavy: true)
        }
        for i in show.badges.indices {
            try? await Task.sleep(for: .seconds(i == 0 ? 0.3 : fast ? 0.15 : 0.45))
            if Task.isCancelled { return }
            withAnimation(fast ? .easeOut(duration: 0.2) : .easeOut(duration: 0.32)) { landed = i + 1 }
            try? await Task.sleep(for: .seconds(fast ? 0.2 : 0.32))
            j.duel.sounds.play(.hitHeavy)
            j.duel.sounds.hitHaptic(heavy: true)
        }
        try? await Task.sleep(for: .seconds(show.badges.isEmpty ? 0 : 0.3))
        withAnimation(.easeOut(duration: 0.3)) { done = true }
        if ProcessInfo.processInfo.arguments.contains("-scrollAutoClose") {    // 开发用：演完自己收起，看飞进「收获」
            try? await Task.sleep(for: .seconds(1))
            close()
        }
    }

    /// 今天还没练（这一格没有印），而且卷轴上画的是这一周。
    private var todayEmpty: Bool {
        show.previewTrace || j.daySummary(show.day) == nil
    }

    /// 卷好的纸卷在屏幕上的位置：卷到纸的顶边。
    private var rollPoint: CGPoint { CGPoint(x: frame.midX, y: frame.minY) }

    /// 收起：下边往上卷、越卷越粗，卷到顶成一个纸卷（0.45 秒）；纸卷往回缩、压扁蓄力（0.22 秒），
    /// 顺着弧线甩进「收获」按钮（0.5 秒，身子跟着路线倾斜、先拉长后收小），按钮弹一下。
    private func close() {
        guard !closing else { return }
        closing = true
        target = j.harvestButtonFrame
        let flies = target != nil && frame != .zero && !reduceMotion
        withAnimation(reduceMotion ? .easeIn(duration: 0.2) : .easeInOut(duration: 0.45)) { open = 0 }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.22 : 0.47))
            if flies {
                withAnimation(.easeInOut(duration: 0.22)) { wind = 1 }
                try? await Task.sleep(for: .seconds(0.22))
                withAnimation(.timingCurve(0.3, 0, 0.2, 1, duration: 0.5)) { fly = 1; wind = 0 }
                try? await Task.sleep(for: .seconds(0.5))
            }
            j.harvestPing += 1                                              // 「收获」按钮弹一下、扩一圈波纹
            j.duel.sounds.hitHaptic(heavy: false)
            onClose()
        }
    }

    private var paper: some View {
        let today = show.day
        let week = j.week(of: today)
        let practiced = week.filter { $0 <= today && j.daySummary($0) != nil }.count
        let total = j.practicedDays.count
        return VStack(spacing: 14) {
            Text(j.dateText(today) + " · 周" + Self.weekNames[DayClock.weekday(of: today)]).font(Fonts.display(26))
            HStack(spacing: 4) {
                ForEach(Array(week.enumerated()), id: \.offset) { i, d in
                    let isToday = d == today
                    VStack(spacing: 4) {
                        Text(Self.weekNames[i])
                            .font(.system(size: 12, weight: isToday ? .black : .bold))
                            .foregroundStyle(isToday ? Palette.ink : Palette.slate2)
                            .overlay(alignment: .bottom) { if isToday { Rectangle().fill(Palette.ink).frame(height: 2).offset(y: 2) } }
                        ZStack {
                            Rectangle().fill(Color(hex: 0xF4EFE3)).frame(width: 34, height: 34)
                            stamp(d)
                            if isToday && todayEmpty {
                                Rectangle().trim(from: 0, to: trace)
                                    .stroke(Palette.slate, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                    .frame(width: 34, height: 34)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text(practiced > 0 ? "本周练了 \(practiced) 天 · 一共练了 \(total) 天" : "一共练了 \(total) 天")
                .font(.system(size: 14, weight: .black)).foregroundStyle(Palette.navy)
            if !j.badgesOn && !show.books.isEmpty { newBooks }
            if j.badgesOn {
                Rectangle().fill(.clear).frame(height: 2)
                    .overlay(Rectangle().stroke(Color(hex: 0xCBC3AE), style: StrokeStyle(lineWidth: 2, dash: [5, 3])))
                if !show.books.isEmpty { newBooks }
                if !show.badges.isEmpty { newBadges }
                bottomRow
            }
            Button { close() } label: {
                Text("出发").font(Fonts.display(24)).foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Palette.gold).overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            }
            .buttonStyle(.pop)
            .padding(.top, 2)
        }
        .padding(.horizontal, 18).padding(.vertical, 24)
        .background(Color(hex: 0xFBF7EE))
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2.5))
    }

    /// 一格的印：要盖的那天先空着，轮到时从 1.5 倍盖下去。
    @ViewBuilder private func stamp(_ d: Int) -> some View {
        if !(show.previewTrace && d == show.day), j.daySummary(d) != nil {
            let pending = show.stamps.contains(d)
            let on = !pending || stamped.contains(d)
            DayStamp(side: 28, day: d)
                .scaleEffect(on || reduceMotion ? 1 : 1.5)
                .opacity(on ? 1 : 0)
        }
    }

    /// 新拿到的秘籍：封面加名字，一本一本从上面落下来。
    private var newBooks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("新秘籍").font(.system(size: 13, weight: .black)).foregroundStyle(Palette.slate)
            FlowRow(spacing: 14, lineSpacing: 8) {
                ForEach(Array(show.books.enumerated()), id: \.element) { i, v in
                    let on = i < booksLanded
                    HStack(spacing: 8) {
                        BookCover(title: "", seal: "", sealColor: .clear, dim: false, volume: v)
                            .frame(width: 30, height: 41)
                            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                        Text(j.bookName(v)).font(Fonts.display(18))
                    }
                    .scaleEffect(on || reduceMotion ? 1 : 1.4)
                    .offset(y: on || reduceMotion ? 0 : -40)
                    .opacity(on ? 1 : 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("新秘籍：" + show.books.map(j.bookName).joined(separator: "、"))
    }

    /// 这次拿到的勋章：一枚一枚从上面落下来（多了换行）。
    private var newBadges: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("新勋章").font(.system(size: 13, weight: .black)).foregroundStyle(Palette.slate)
            FlowRow(spacing: 10, lineSpacing: 8) {
                ForEach(Array(show.badges.enumerated()), id: \.element.key) { i, b in
                    let on = i < landed
                    VStack(spacing: 2) {
                        j.medal(b.track, b.step, size: show.badges.count > 4 ? 40 : 52)
                            .scaleEffect(on || reduceMotion ? 1 : 1.4)
                            .offset(y: on || reduceMotion ? 0 : -40)
                        Text(j.badgeShortName(b.track, b.step)).font(.system(size: 10, weight: .black)).lineLimit(1)
                    }
                    .opacity(on ? 1 : 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("新勋章：" + show.badges.map { j.badgeShortName($0.track, $0.step) }.joined(separator: "、"))
    }

    /// 最下面一行：最新三枚和一共几枚（落勋章时跟着涨）｜下一枚（演完才换上新的）。
    private var bottomRow: some View {
        let count = j.progress.badges.count - (show.badges.count - landed)
        let latest = show.badges.isEmpty ? j.latestBadges(3) : []
        return HStack(alignment: .center, spacing: 14) {
            VStack(spacing: 6) {
                if !latest.isEmpty {
                    HStack(spacing: -10) { ForEach(latest, id: \.key) { b in j.medal(b.track, b.step, size: 40) } }
                }
                Text(count > 0 ? "拿到 \(count) 枚" : "还没有勋章").font(.system(size: 12, weight: .black)).foregroundStyle(Palette.slate)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            if let n = j.nextBadge {                                   // 位置先留好，演完才淡入（卷轴不跳）
                Rectangle().fill(Color(hex: 0xCBC3AE)).frame(width: 2, height: 60)
                HStack(spacing: 8) {
                    j.medal(n.track, n.step, state: .next, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("下一枚 · " + j.badgeCaption(n.track, n.step)).font(Fonts.display(17))
                        Text(j.badgeNextLine(n.track, n.step)).font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(done || show.badges.isEmpty ? 1 : 0)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("下一枚，\(j.badgeNextLine(n.track, n.step))")
            }
        }
    }
}

// Motion Prompt #126 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#126
// Motion Prompt #121 · MIT License (c) 2026 Shohei Ohtaki · https://showheyohtaki.github.io/motion-prompt/#121

/// 卷轴开合：上面一根轴不动，下边是一卷纸。展开时纸卷往下滚、越滚越细，纸跟着露出来；收起反过来往上卷、越卷越粗，
/// 卷到顶就是一个纸卷（同一样东西，不换图）。p：1 全开，0 卷好。减弱动态效果时只淡入淡出。
private struct ScrollRoll: ViewModifier, @preconcurrency Animatable {
    var p: CGFloat
    var fade: Bool
    var animatableData: CGFloat {
        get { p }
        set { p = newValue }
    }

    func body(content: Content) -> some View {
        if fade {
            content.opacity(Double(p))
        } else {
            content
                .mask(GeometryReader { g in
                    Rectangle().frame(height: g.size.height * p).frame(maxHeight: .infinity, alignment: .top)
                })
                .overlay(GeometryReader { g in
                    let w = g.size.width, h = g.size.height
                    PaperRoll(width: w, wound: 0).position(x: w / 2, y: 0).opacity(Double(min(1, p / 0.12)))   // 上面那根：和下面同一个画法
                    PaperRoll(width: w, wound: 1 - p).position(x: w / 2, y: h * p)
                })
        }
    }
}

/// 卷轴的一根（上下两根同一个画法）：米色纸筒，两头卷边，露一小截木轴，套金色轴头。wound = 卷进去多少（0 最细，1 全卷好）：
/// 卷得越多纸筒越粗、卷边越明显，卷好时系上红绳。
private struct PaperRoll: View {
    let width: CGFloat
    let wound: CGFloat

    var body: some View {
        let thick = 14 + 14 * wound                                       // 纸筒粗细：14（展开时）→ 28（一卷纸）
        HStack(spacing: 0) {
            cap(thick)
            stub
            ZStack {
                RoundedRectangle(cornerRadius: thick / 2).fill(Color(hex: 0xFBF7EE))
                HStack {                                                  // 两头卷边
                    Ellipse().stroke(Palette.ink.opacity(0.55), lineWidth: 1.5).frame(width: thick * 0.3, height: thick * 0.8)
                    Spacer()
                    Ellipse().stroke(Palette.ink.opacity(0.55), lineWidth: 1.5).frame(width: thick * 0.3, height: thick * 0.8)
                }
                .padding(.horizontal, 6)
                Rectangle().fill(Color.white.opacity(0.8)).frame(height: 2.5).offset(y: -thick * 0.22).padding(.horizontal, 18)
                Rectangle().fill(Palette.red).frame(width: 10, height: thick + 6)  // 红绳：快卷好时系上
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                    .scaleEffect(y: max(0, (wound - 0.75) / 0.25), anchor: .center)
                RoundedRectangle(cornerRadius: thick / 2).stroke(Palette.ink, lineWidth: 2.5)
            }
            .frame(height: thick)
            stub
            cap(thick)
        }
        .frame(width: width + 24)
    }

    /// 纸筒两头露出来的一小截木轴（木头一直在轴心，纸卷在外面）。
    private var stub: some View {
        Rectangle().fill(Color(hex: 0x5C3B22)).frame(width: 5, height: 10).overlay(Rectangle().stroke(Palette.ink, lineWidth: 1.5))
    }

    private func cap(_ thick: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(Palette.gold).frame(width: 10 + 2 * wound, height: thick + 8)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.ink, lineWidth: 2))
    }
}

/// 纸卷甩进「收获」按钮（Motion Prompt #121 蓄力 + #126 沿路线走、身子跟着路线转）：
/// wind：往回缩、压扁（宽 1.06、高 0.8、往后仰 6°）；t：顺着一条先往上、再拐向按钮的弧线走，
/// 身子跟着路线方向倾斜（只转路线角度的三成，长条转太多不好看），前六成拉长、之后越走越小，到按钮缩成一小卷。
private struct TossToTarget: ViewModifier, @preconcurrency Animatable {
    var t: CGFloat
    var wind: CGFloat
    let from: CGPoint
    let to: CGPoint?
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(t, wind) }
        set { t = newValue.first; wind = newValue.second }
    }

    func body(content: Content) -> some View {
        guard let to else { return AnyView(content) }
        // 弧线：从纸卷出发，控制点在纸卷正上方、和按钮一样高，先往上走再拐过去
        let c = CGPoint(x: from.x - 30, y: to.y - 40)
        let u = 1 - t
        let pos = CGPoint(x: u * u * from.x + 2 * u * t * c.x + t * t * to.x, y: u * u * from.y + 2 * u * t * c.y + t * t * to.y)
        let d = CGPoint(x: 2 * u * (c.x - from.x) + 2 * t * (to.x - c.x), y: 2 * u * (c.y - from.y) + 2 * t * (to.y - c.y))
        let heading = atan2(d.y, d.x) + .pi / 2                          // 一开始往上走算 0°
        let tilt = t > 0 && t < 1 ? Double(heading) * 0.3 : 0
        let stretch = t < 0.6 ? sin(Double(t / 0.6) * .pi) * 0.12 : 0    // 前六成拉长一下
        let shrink = 1 - 0.85 * t
        let back = 18 * wind                                              // 蓄力：往回（往下）缩
        return AnyView(content
            .scaleEffect(x: shrink * (1 + 0.06 * wind) * (1 + stretch), y: shrink * (1 - 0.2 * wind) * (1 - stretch * 0.5),
                         anchor: UnitPoint(x: 0.5, y: 0))
            .rotationEffect(.radians(tilt - 0.1 * Double(wind)), anchor: UnitPoint(x: 0.5, y: 0))
            .offset(x: pos.x - from.x, y: pos.y - from.y + back)
            .opacity(Double(1 - max(0, t - 0.85) / 0.15 * 0.7)))
    }
}
