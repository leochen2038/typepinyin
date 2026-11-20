import LearningCore
import SwiftUI

/// 练过那天的印（2.3，2026-11-21 改）：一律明黄底、墨字「练」，打完一场就盖、盖了不变（原来按当天经验最多那本秘籍的岛、会跟着变）。
/// 微微歪一点（按日期定，每次一样），像盖上去的。打 1 场和打 10 场一样大。那天有掌门盖印，右下角另压一个朱红小印。
struct DayStamp: View {
    var side: CGFloat = 28
    var line: CGFloat = 2
    let day: Int

    /// 左右 4 度以内，按日期定。
    static func tilt(_ day: Int) -> Double { Double(((day * 7) % 9 + 9) % 9 - 4) }

    var body: some View {
        Text("练")
            .font(.system(size: side * 0.54, weight: .black))
            .foregroundStyle(Palette.ink)
            .frame(width: side, height: side)
            .background(Palette.gold)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: line))
            .rotationEffect(.degrees(Self.tilt(day)))
    }
}

/// 掌门小印：15 × 15 朱红，纸色边，写岛名第一个字（当选那天写「盟」）。
struct DaySeal: View {
    let text: String

    var body: some View {
        Text(text).font(.system(size: 8, weight: .black)).foregroundStyle(Color(hex: 0xFBF7EE))
            .frame(width: 15, height: 15)
            .background(Color(hex: 0xC0392B))
            .overlay(Rectangle().stroke(Color(hex: 0xFBF7EE), lineWidth: 1.5))
            .rotationEffect(.degrees(-6))
    }
}

// MARK: - 日历页

/// 日历页（2.2–2.5）：按月看，左右箭头翻月（最早到第一次练的那个月，最晚到这个月）；练过的日子盖方块，
/// 点开弹出那天的收获。没练的日子只有淡墨的日期，不打叉、不标红。
struct CalendarPage: View {
    @State var j: JourneyController
    /// 翻到的月份（这个月的第一天是第几天）。
    @State private var month: Int
    @State private var picked: Int?
    @State private var sheetUp = false
    /// 翻月的方向（左右滑）。
    @State private var forward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(j: JourneyController) {
        _j = State(initialValue: j)
        _month = State(initialValue: Self.monthStart(of: j.today))
    }

    /// 这一天所在月份的第一天。
    static func monthStart(of day: Int) -> Int {
        let cal = Calendar.current
        let d = DayClock.date(of: day)
        let first = cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
        return DayClock.day(of: first)
    }

    static func shiftMonth(_ start: Int, by n: Int) -> Int {
        let d = Calendar.current.date(byAdding: .month, value: n, to: DayClock.date(of: start)) ?? DayClock.date(of: start)
        return DayClock.day(of: d)
    }

    var thisMonth: Int { Self.monthStart(of: j.today) }
    var firstMonth: Int { j.practicedDays.first.map(Self.monthStart(of:)) ?? thisMonth }
    var canBack: Bool { month > firstMonth }
    var canForward: Bool { month < thisMonth }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(topLine).font(.system(size: 15, weight: .black)).foregroundStyle(Palette.navy)
                        .frame(minHeight: 22, alignment: .leading)
                    monthCard
                        .padding(.trailing, 4)
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 260)
            }
            if let d = picked, let s = j.daySummary(d) {
                DaySheet(j: j, day: d, summary: s) { close() }
                    .padding(.leading, 12).padding(.trailing, 16).padding(.bottom, 16)
                    .offset(y: sheetUp ? 0 : 600)
            }
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments                 // 开发用：-calendarDay 2026-11-19 直接点开那一天
            if let k = args.firstIndex(of: "-calendarDay"), k + 1 < args.count {
                let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                if let d = f.date(from: args[k + 1]) { pick(DayClock.day(of: d)) }
            }
        }
    }

    /// 顶上那一行（2.4）：不写连续几天，也不写还差几天。
    var topLine: String {
        let total = j.practicedDays.count
        if total == 0 { return "打完一场，这里就盖上第一个印" }
        if month == thisMonth {
            let w = j.practicedThisWeek
            return w > 0 ? "本周练了 \(w) 天 · 一共练了 \(total) 天" : "一共练了 \(total) 天"
        }
        let end = Self.shiftMonth(month, by: 1)
        return "这个月练了 \(j.practicedDays.filter { $0 >= month && $0 < end }.count) 天"
    }

    private var monthTitle: String {
        let c = Calendar.current.dateComponents([.year, .month], from: DayClock.date(of: month))
        return "\(c.year ?? 2026) 年 \(c.month ?? 1) 月"
    }

    private var monthCard: some View {
        VStack(spacing: 8) {
            HStack {
                arrow(back: true)
                Spacer()
                Text(monthTitle).font(Fonts.display(22))
                Spacer()
                arrow(back: false)
            }
            HStack(spacing: 3) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { w in
                    Text(w).font(.system(size: 12, weight: .black)).foregroundStyle(Palette.slate).frame(maxWidth: .infinity)
                }
            }
            grid
                .id(month)
                .transition(reduceMotion ? .opacity : .push(from: forward ? .trailing : .leading))
        }
        .padding(.horizontal, 10).padding(.vertical, 12)
        .background(Color.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2.5))
        .clipped()
        .gesture(DragGesture(minimumDistance: 30).onEnded { g in
            if g.translation.width < -40, canForward { flip(1) }
            if g.translation.width > 40, canBack { flip(-1) }
        })
    }

    private func arrow(back: Bool) -> some View {
        let on = back ? canBack : canForward
        return Button { flip(back ? -1 : 1) } label: {
            Image(systemName: back ? "chevron.left" : "chevron.right")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(on ? Palette.ink : Color(hex: 0xC9CEDB))
                .frame(width: 36, height: 36)
                .background(Color.white)
                .overlay(Rectangle().stroke(on ? Palette.ink : Color(hex: 0xC9CEDB), lineWidth: 2))
        }
        .buttonStyle(.popSmall)
        .disabled(!on)
        .accessibilityLabel(back ? "上个月" : "下个月")
    }

    private func flip(_ n: Int) {
        forward = n > 0
        close()
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeInOut(duration: 0.25)) { month = Self.shiftMonth(month, by: n) }
    }

    private var grid: some View {
        let lead = DayClock.weekday(of: month)
        let end = Self.shiftMonth(month, by: 1)
        let days = Array(month..<end)
        let cells: [Int?] = Array(repeating: nil, count: lead) + days.map { Optional($0) }
        let rows = (cells.count + 6) / 7
        return VStack(spacing: 3) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { c in
                        let k = r * 7 + c
                        if k < cells.count, let d = cells[k] { cell(d) } else { Color.clear.frame(maxWidth: .infinity).frame(height: 44) }
                    }
                }
            }
        }
    }

    @ViewBuilder private func cell(_ d: Int) -> some View {
        let s = j.daySummary(d)
        let isToday = d == j.today
        let future = d > j.today
        let num = Calendar.current.component(.day, from: DayClock.date(of: d))
        let face = ZStack(alignment: .topLeading) {
            Rectangle().fill(picked == d ? Color(hex: 0xFFF1C9) : Color(hex: 0xF5F6FA))
            Text("\(num)").font(.system(size: 10, weight: isToday ? .black : .bold))
                .foregroundStyle(isToday ? Palette.ink : future ? Palette.faint : Palette.slate2)
                .padding(.leading, 3).padding(.top, 2)
            if let s {
                DayStamp(day: d)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 6)
                if let m = j.sealMark(s) {
                    DaySeal(text: m).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(1)
                }
            }
        }
        .frame(maxWidth: .infinity).frame(height: 44)
        .overlay { if isToday { Rectangle().stroke(Palette.ink, lineWidth: 2.5) } }
        let label = "\(j.dateText(d))，周\(["一", "二", "三", "四", "五", "六", "日"][DayClock.weekday(of: d)])"
            + (s != nil ? "，练过" : "")
        if s != nil {
            Button { pick(d) } label: { face }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
        } else {
            face.accessibilityElement(children: .ignore).accessibilityLabel(label)
        }
    }

    /// 点练过的格子弹出那天；再点别的练过的格子换成那天。
    private func pick(_ d: Int) {
        if picked != nil {
            picked = d
            return
        }
        picked = d
        sheetUp = false
        DispatchQueue.main.async {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.32, bounce: 0.12)) { sheetUp = true }
        }
    }

    private func close() {
        guard picked != nil else { return }
        withAnimation(.easeIn(duration: 0.22)) { sheetUp = false }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.24))
            if !sheetUp { picked = nil }
        }
    }
}

/// 点开一天（2.5）：标题「11 月 19 日 · 周四」，最多 6 行，只列收获；最后一排是那天拿到的勋章。
struct DaySheet: View {
    let j: JourneyController
    let day: Int
    let summary: DaySummary
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(j.dateText(day)).font(Fonts.display(30))
                Text("周" + ["一", "二", "三", "四", "五", "六", "日"][DayClock.weekday(of: day)])
                    .font(.system(size: 13, weight: .black)).foregroundStyle(Palette.slate)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .black)).foregroundStyle(Palette.ink)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .padding(.trailing, -10)
                .accessibilityLabel("关上")
            }
            ForEach(Array(j.dayLines(summary).enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Rectangle().fill(Palette.gold).frame(width: 9, height: 9).overlay(Rectangle().stroke(Palette.ink, lineWidth: 2))
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                    let parts = line.components(separatedBy: "\n")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(parts[0]).font(.system(size: 15, weight: .bold))
                        if parts.count > 1 {
                            Text(parts[1]).font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.slate)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            let medals = summary.badges.compactMap { k in j.progress.badges[k] }
            if !medals.isEmpty {
                Rectangle().fill(.clear).frame(height: 2)
                    .overlay(Rectangle().stroke(Palette.mist2, style: StrokeStyle(lineWidth: 2, dash: [5, 3])))
                FlowRow(spacing: 14) {
                    ForEach(medals, id: \.key) { b in
                        HStack(spacing: 6) {
                            j.medal(b.track, b.step, size: 40)
                            Text(j.badgeShortName(b.track, b.step)).font(.system(size: 12, weight: .black)).foregroundStyle(Palette.slate)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        .background(Rectangle().fill(Palette.ink).offset(x: 5, y: 5))
        .accessibilityElement(children: .contain)
    }
}

/// 一行放不下就换行（点开一天的勋章一排）。
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > w { y += line + lineSpacing; x = 0; line = 0 }
            x += sz.width + spacing
            line = max(line, sz.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(w, widest), height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX { y += line + lineSpacing; x = bounds.minX; line = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += sz.width + spacing
            line = max(line, sz.height)
        }
    }
}

// MARK: - 收获页的日历卡片

/// 收获页左边的「日历」卡片（5.1）：这一周七格，练过的那天盖岛名小方块；今天那格的表头字加粗。
struct CalendarCard: View {
    let j: JourneyController

    var body: some View {
        let week = j.week(of: j.today)
        let total = j.practicedDays.count
        let thisWeek = j.practicedThisWeek
        VStack(alignment: .leading, spacing: 8) {
            HarvestCardTitle(title: "日历")
            HStack(spacing: 0) {
                ForEach(Array(week.enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 3) {
                        let today = d == j.today
                        Text(["一", "二", "三", "四", "五", "六", "日"][i])
                            .font(.system(size: 10, weight: today ? .black : .bold))
                            .foregroundStyle(today ? Palette.ink : Palette.slate2)
                            .overlay(alignment: .bottom) { if today { Rectangle().fill(Palette.ink).frame(height: 2).offset(y: 2) } }
                        if j.daySummary(d) != nil {
                            DayStamp(side: 18, line: 1.5, day: d)
                        } else {
                            Color.clear.frame(width: 18, height: 18)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Spacer(minLength: 0)
            Text(total == 0 ? "打完一场就盖上第一个印" : thisWeek > 0 ? "本周练了 \(thisWeek) 天 · 共 \(total) 天" : "共 \(total) 天")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate).lineLimit(1).minimumScaleFactor(0.7)
        }
        .harvestCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(total == 0 ? "日历，还没盖印" : "日历，\(thisWeek > 0 ? "本周练了 \(thisWeek) 天，" : "")一共 \(total) 天")
    }
}

/// 放大字体时压成一行（5.1）：左「日历 · 本周 3 天」，右「勋章 · 32 枚」，不画七格和勋章图。
struct CompactHarvestCard: View {
    let title: String
    let line: String
    var dot = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(Fonts.display(22))
            Text(line).font(.system(size: 16, weight: .black)).foregroundStyle(Palette.slate).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2.5))
        .overlay(alignment: .topTrailing) { if dot { NewDot().offset(x: 9, y: -9) } }
    }
}
