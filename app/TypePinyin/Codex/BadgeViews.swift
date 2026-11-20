import LearningCore
import SwiftUI

// MARK: - 勋章的写法（docs/calendar-badges.md 3.5、3.6，正式版规格板「文案」）

extension JourneyController {
    func medalKind(_ t: BadgeTrack) -> MedalView.Kind {
        switch t {
        case .cards: .card
        case .books: .seal
        case .levels: .book
        case .fights: .sword
        case .days: .sun
        }
    }

    /// 勋章上写的：「1000」「全部」「葫」「盟」「8」「150」「21」。
    func badgeValueText(_ t: BadgeTrack, _ step: Int) -> String {
        let rules = badgeRules
        switch t {
        case .cards: return rules.steps(t)[step] <= 0 ? "全部" : "\(rules.steps(t)[step])"
        case .books:
            guard let id = bookBadgeRegion(step) else { return "" }
            return id == "盟" ? "盟" : String(content.region(id)?.name.prefix(1) ?? "")
        default: return "\(rules.threshold(t, step, total: cardsInAll))"
        }
    }

    /// 收集册格子下面的第一行：「500 张」「第 2 本」「盟主」「升 8 次」「150 场」「21 天」。
    func badgeCaption(_ t: BadgeTrack, _ step: Int) -> String {
        let n = badgeRules.threshold(t, step, total: cardsInAll)
        switch t {
        case .cards: return badgeRules.steps(t)[step] <= 0 ? "全部" : "\(n) 张"
        case .books: return bookBadgeRegion(step) == "盟" ? "盟主" : "第 \(step + 1) 本"
        case .levels: return "升 \(n) 次"
        case .fights: return "\(n) 场"
        case .days: return "\(n) 天"
        }
    }

    /// 结算页、日历、收获页卡片上的短名：「词卡 · 1000 张」「秘籍 · 第 3 本」「等级 · 升 8 次」「打几场 · 150 场」「来了几天 · 21 天」。
    func badgeShortName(_ t: BadgeTrack, _ step: Int) -> String {
        let head: String
        switch t {
        case .cards: head = "词卡"
        case .books: head = "秘籍"
        case .levels: head = "等级"
        case .fights, .days: head = t.name
        }
        return head + " · " + badgeCaption(t, step)
    }

    /// 展示卡标题：「收集词卡 · 1000 张」。
    func badgeTitle(_ t: BadgeTrack, _ step: Int) -> String { t.name + " · " + badgeCaption(t, step) }

    /// 那一刻（3.5）：「第 1000 张词卡是『白菜』」「白梅台掌门盖印」「第 8 次：白梅台秘籍升到 2 级」
    /// 「第 100 场：半山镇，打赢了镇上的镖师林大」「第 21 天：在长风城，那天掌门盖印」。不知道的（补发的）写拿到它的条件。
    func badgeMoment(_ b: BadgeRecord) -> String {
        let n = badgeRules.threshold(b.track, b.step, total: cardsInAll)
        switch b.track {
        case .cards:
            return b.memento.isEmpty ? "收满 \(n) 张词卡" : "第 \(n) 张词卡是「\(b.memento)」"
        case .books:
            if b.memento == "盟" || bookBadgeRegion(b.step) == "盟" { return "当选武林盟主" }
            return (content.region(b.memento)?.name ?? "") + "掌门盖印"
        case .levels:
            let p = b.memento.split(separator: "|")
            guard p.count == 2 else { return "秘籍一共升了 \(n) 次级" }
            return "第 \(n) 次：\(bookName(String(p[0])))升到 \(p[1]) 级"
        case .fights:
            return b.memento.isEmpty ? "打满 \(n) 场" : "第 \(n) 场：\(b.memento)"
        case .days:
            guard let s = daySummary(b.day), let r = stampRegion(s) else { return "来了 \(n) 天" }
            let extra = s.crowned ? "，那天当选武林盟主" : s.seals.isEmpty ? "" : "，那天掌门盖印"
            return "第 \(n) 天：在\(r.name)\(extra)"
        }
    }

    /// 下一枚的条件：「收满 1500 张词卡，就拿到这一枚」。
    func badgeNextLine(_ t: BadgeTrack, _ step: Int) -> String {
        let n = badgeRules.threshold(t, step, total: cardsInAll)
        switch t {
        case .cards: return badgeRules.steps(t)[step] <= 0 ? "收齐全部词卡，就拿到这一枚" : "收满 \(n) 张词卡，就拿到这一枚"
        case .books:
            if bookBadgeRegion(step) == "盟" { return "在武林大会当选盟主，就拿到这一枚" }
            return (content.region(bookBadgeRegion(step) ?? "")?.name ?? "") + "掌门盖印，就拿到这一枚"
        case .levels: return "秘籍一共升满 \(n) 次级，就拿到这一枚"
        case .fights: return "打满 \(n) 场，就拿到这一枚"
        case .days: return "来满 \(n) 天，就拿到这一枚"
        }
    }

    /// 下一枚格子下面写的条件：「1500 张」「白梅台」「升 10 次」「200 场」「30 天」。
    func badgeNextCaption(_ t: BadgeTrack, _ step: Int) -> String {
        guard t == .books else { return badgeCaption(t, step) }
        let id = bookBadgeRegion(step) ?? ""
        return id == "盟" ? "武林大会" : content.region(id)?.name ?? ""
    }

    /// 每一页段头下面的小字：「已收 1032 张」「打通了 3 座岛」「一共升了 9 次级」「已打 150 场」「来了 26 天」。
    func badgeSub(_ t: BadgeTrack) -> String {
        let v = badgeValue(t)
        switch t {
        case .cards: return "已收 \(v) 张"
        case .books: return crowned ? "当选武林盟主" : "打通了 \(sealedRegions.count) 座岛"
        case .levels: return "一共升了 \(v) 次级"
        case .fights: return "已打 \(v) 场"
        case .days: return "来了 \(v) 天"
        }
    }

    /// 画一枚：方印里圈用那座岛秘籍的封面色（「盟」明黄），书用那次升级那本秘籍的封面色。
    func medal(_ t: BadgeTrack, _ step: Int, state: MedalView.Status = .got, size: CGFloat, isNew: Bool = false) -> MedalView {
        var cover = MedalView.bandColor(badgeRules.band(t, step))
        var coverInk = false
        var word = ""
        let rec = progress.badges[BadgeRecord.key(t, step)]
        switch t {
        case .books:
            if let id = bookBadgeRegion(step), let r = content.region(id) {
                cover = BookCover.colors(r.volume).cover
                coverInk = BookCover.inkOnCover(r.volume)
            } else {
                cover = Palette.gold
                coverInk = true
            }
        case .levels:
            if let v = rec?.memento.split(separator: "|").first.map(String.init), !v.isEmpty { cover = BookCover.colors(v).cover }
        case .cards:
            word = rec?.memento ?? ""
        default: break
        }
        return MedalView(shape: medalKind(t), state: state, band: badgeRules.band(t, step), cover: cover, coverInk: coverInk,
                         word: word, value: badgeValueText(t, step), size: size, isNew: isNew)
    }

    /// 「11 月 19 日」。
    func dateText(_ day: Int) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: DayClock.date(of: day))
        return "\(c.month ?? 1) 月 \(c.day ?? 1) 日"
    }

    /// 「11.19」。
    func shortDate(_ day: Int) -> String {
        let c = Calendar.current.dateComponents([.month, .day], from: DayClock.date(of: day))
        return "\(c.month ?? 1).\(c.day ?? 1)"
    }
}

// MARK: - 勋章页：收集册

/// 勋章页（3.6）：一本收集册，五页、一页一条台阶；拿到的摆出来带日期，紧挨着的下一枚虚线写条件，再往后只留淡轮廓。
/// 不放进度条、不写还差。点拿到的弹展示卡（放大、哪天拿到、那一刻）；点虚线的只写条件；点空格没反应。
struct BadgeBookView: View {
    @State var j: JourneyController
    /// 进来时还没看过的（这一趟角上一直挂「新」，进来就记成看过，下次进来就不挂了）。
    @State private var fresh: Set<String> = []
    @State private var picked: Picked?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Picked: Equatable { var track: BadgeTrack; var step: Int; var got: Bool }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("拿到").font(.system(size: 15, weight: .black))
                        Text("\(j.progress.badges.count)").font(Fonts.display(28))
                        Text("枚勋章").font(.system(size: 15, weight: .black))
                    }
                    .foregroundStyle(Palette.navy)
                    .accessibilityElement(children: .combine)
                    ForEach(BadgeTrack.allCases, id: \.self) { t in page(t) }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 24)
            }
            if let p = picked { detail(p) }
        }
        .onAppear {
            fresh = j.unseenBadges
            j.markBadgesSeen()
        }
    }

    private func page(_ t: BadgeTrack) -> some View {
        let steps = j.badgeRules.steps(t)
        let got = steps.indices.filter { j.progress.badges[BadgeRecord.key(t, $0)] != nil }
        let next = steps.indices.first { j.progress.badges[BadgeRecord.key(t, $0)] == nil }
        let full = got.count == steps.count
        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(t.name).font(Fonts.display(21))
                    Spacer()
                    Text(full ? "收齐了" : "\(got.count) / \(steps.count)").font(Fonts.display(18)).foregroundStyle(Palette.navy)
                }
                Text(j.badgeSub(t)).font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.slate)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 10) {
                ForEach(steps.indices, id: \.self) { i in
                    let rec = j.progress.badges[BadgeRecord.key(t, i)]
                    cell(t, i, rec: rec, isNext: rec == nil && i == next)
                }
            }
        }
        .padding(12)
        .background(Color(hex: 0xF4EFE3))
        .overlay(Rectangle().inset(by: 1.25 + 2).stroke(Color(hex: 0xFBF7EE), lineWidth: 4))
        .overlay(Rectangle().stroke(full ? Palette.gold : Palette.ink, lineWidth: 2.5))
    }

    @ViewBuilder private func cell(_ t: BadgeTrack, _ i: Int, rec: BadgeRecord?, isNext: Bool) -> some View {
        let state: MedalView.Status = rec != nil ? .got : isNext ? .next : .empty
        let isNew = rec.map { fresh.contains($0.key) } ?? false
        Button {
            guard state != .empty else { return }
            open(Picked(track: t, step: i, got: rec != nil))
        } label: {
            VStack(spacing: 2) {
                j.medal(t, i, state: state, size: 58, isNew: isNew)
                Text(rec != nil ? j.badgeCaption(t, i) : isNext ? "下一枚" : " ")
                    .font(.system(size: 10, weight: .black)).lineLimit(1).minimumScaleFactor(0.7)
                Text(rec.map { j.shortDate($0.day) } ?? (isNext ? j.badgeNextCaption(t, i) : " "))
                    .font(.system(size: 9.5, weight: .bold)).foregroundStyle(Palette.slate).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(state == .empty)
        .accessibilityLabel(rec.map { "\(j.badgeTitle(t, i))，\(j.dateText($0.day))拿到\(isNew ? "，新" : "")" }
                            ?? (isNext ? "下一枚，\(j.badgeNextLine(t, i))" : "还没拿到"))
    }

    private func open(_ p: Picked) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .easeOut(duration: 0.22)) { picked = p }
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.2)) { picked = nil }
    }

    /// 展示卡：放大的那一枚、标题、哪天拿到、那一刻；虚线的下一枚只写条件。
    private func detail(_ p: Picked) -> some View {
        let rec = j.progress.badges[BadgeRecord.key(p.track, p.step)]
        return ZStack(alignment: .top) {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { close() }
                .accessibilityLabel("关上")
                .accessibilityAddTraits(.isButton)
            VStack(spacing: 8) {
                j.medal(p.track, p.step, state: p.got ? .got : .next, size: 150)
                Text(p.got ? j.badgeTitle(p.track, p.step) : "下一枚 · " + j.badgeCaption(p.track, p.step))
                    .font(Fonts.display(24)).padding(.top, 4)
                if let rec { Text("\(j.dateText(rec.day))拿到").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.slate) }
                Text(rec.map(j.badgeMoment) ?? j.badgeNextLine(p.track, p.step))
                    .font(.system(size: 15, weight: .black)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button { close() } label: {
                    Text("好").font(Fonts.display(24)).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Palette.gold).overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
                }
                .buttonStyle(.pop)
                .padding(.top, 8)
            }
            .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0xFBF7EE))
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            .background(Rectangle().fill(Palette.ink).offset(x: 6, y: 6))
            .padding(.horizontal, 28).padding(.top, 100)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
        }
        .zIndex(2)
    }
}

// MARK: - 收获页的勋章卡片

/// 收获页右边的「勋章」卡片：最新三枚（新的在右，微微叠着）、一共几枚、最新那枚的名字；有新的右上角一个「新」。
struct BadgeCard: View {
    let j: JourneyController

    var body: some View {
        let latest = j.latestBadges(3)
        VStack(alignment: .leading, spacing: 8) {
            HarvestCardTitle(title: "勋章")
            if latest.isEmpty {
                Spacer(minLength: 0)
                Text("打完一场就拿到第一枚").font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate)
                    .lineLimit(1).minimumScaleFactor(0.7)
            } else {
                HStack(spacing: 8) {
                    HStack(spacing: -8) {
                        ForEach(latest, id: \.key) { b in j.medal(b.track, b.step, size: 36) }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(j.progress.badges.count)").font(Fonts.display(30))
                        Text("枚").font(.system(size: 13, weight: .black))
                    }
                }
                .frame(height: 38)
                Spacer(minLength: 0)
                Text("最新：" + (latest.last.map { j.badgeShortName($0.track, $0.step) } ?? ""))
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(Palette.slate).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .harvestCard()
        .overlay(alignment: .topTrailing) { if j.hasNewBadges { NewDot().offset(x: 9, y: -9) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("勋章，\(j.progress.badges.count) 枚\(j.hasNewBadges ? "，有新勋章" : "")")
    }
}

/// 收获页卡片的标题：标题字 + 右箭头。
struct HarvestCardTitle: View {
    let title: String

    var body: some View {
        HStack {
            Text(title).font(Fonts.display(19))
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .black))
        }
    }
}

extension View {
    /// 收获页的两张卡片：白底、2.5 粗黑边，最小高 118（投影和按下去由按钮样式给）。
    func harvestCard() -> some View {
        padding(10)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .background(Color.white)
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 2.5))
    }
}

// MARK: - 旧存档补发的卡片

/// 上线后第一次回到地图（3.8）：「之前的收获，补发了 N 枚勋章」，每条台阶列补到的最高那一枚；「去看看」进勋章页，「好」关上。
struct BackfillCard: View {
    let j: JourneyController
    let awards: [BadgeRecord]
    let onLook: () -> Void
    let onClose: () -> Void

    var body: some View {
        let top = BadgeTrack.allCases.compactMap { t in awards.filter { $0.track == t }.max { $0.step < $1.step } }
        ZStack(alignment: .top) {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("之前的收获").font(Fonts.display(28))
                Text("补发了 \(awards.count) 枚勋章").font(.system(size: 15, weight: .black))
                HStack(spacing: 18) {
                    ForEach(top, id: \.key) { b in
                        VStack(spacing: 4) {
                            j.medal(b.track, b.step, size: 56)
                            Text(j.badgeShortName(b.track, b.step)).font(.system(size: 12, weight: .black)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                }
                .padding(.vertical, 4)
                Text("「身经百战」「日积月累」从今天开始数").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.slate)
                HStack(spacing: 12) {
                    button("去看看", primary: true, action: onLook)
                    button("好", primary: false, action: onClose)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 18)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0xFBF7EE))
            .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            .background(Rectangle().fill(Palette.ink).offset(x: 6, y: 6))
            .padding(.leading, 20).padding(.trailing, 24).padding(.top, 150)
        }
        .accessibilityAddTraits(.isModal)
    }

    private func button(_ label: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(Fonts.display(22)).foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(primary ? Palette.gold : Color.white)
                .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        }
        .buttonStyle(.pop)
    }
}
