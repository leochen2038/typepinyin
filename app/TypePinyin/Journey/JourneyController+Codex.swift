import LearningCore
import ProgressStore

/// 秘籍页要的：哪本书刚拿到还没揭开、哪些音节是上次来过以后新学会的、一个音节玩家打过哪些词。
/// 「看过」记在 tipsSeen 里（两台设备取并集）：揭开过的卷记 book:卷名，看过的音节记 syl:拼法。
extension JourneyController {
    static func bookSeenKey(_ v: String) -> String { "book:\(v)" }
    static func syllableSeenKey(_ s: String) -> String { "syl:\(s)" }

    /// 拿到了、还没在秘籍页揭开过的卷（按卷的顺序）。
    var booksToUnveil: [String] {
        Volumes.all.filter { progress.volumes[$0]?.obtained == true && !progress.journey.tipsSeen.contains(Self.bookSeenKey($0)) }
    }

    /// 上次看秘籍以后新学会的音节。
    var newlyLearned: [String] {
        let best = cardBest
        return content.syllables.map(\.spelling).filter {
            best[$0] != nil && !progress.journey.tipsSeen.contains(Self.syllableSeenKey($0))
        }
    }

    func markCodexSeen(books: [String] = [], syllables: [String] = []) {
        let keys = books.map(Self.bookSeenKey) + syllables.map(Self.syllableSeenKey)
        var j = progress.journey
        guard !Set(keys).isSubset(of: j.tipsSeen) else { return }
        j.tipsSeen.formUnion(keys)
        var ch = ProgressChange()
        ch.journey = j
        save(ch)
    }

    /// 玩家打过的、含这个音节的词，打得多的在前。
    func typedWords(with s: String) -> [String] { cards(with: s).map(\.text) }

    /// 含这个音节的词卡：练得好的在前（累计打对的场数多的、打得多的）。
    func cards(with s: String) -> [PracticeWord] {
        cards.filter { $0.syllables.contains(s) }.sorted { ($0.cleanDuels, $0.seen) > ($1.cleanDuels, $1.seen) }
    }

    /// 这一卷的词卡（含这一卷音节的都算）：练得好的在前，同样的按最近打过的在前。
    func cards(in volume: String) -> [PracticeWord] {
        cards.filter { $0.syllables.contains { content.volume(of: $0) == volume } }
            .sorted { ($0.cleanDuels, $0.lastSeen) > ($1.cleanDuels, $1.lastSeen) }
    }

    /// 秘籍的叫法：按经验升级时用岛名叫（「白梅台秘籍」），原来的叫法是卷名（「两字诀·上卷」）。
    func bookName(_ v: String) -> String {
        guard xpLevels, let r = region(giving: v) else { return Volumes.name(v) }
        return r.name + "秘籍"
    }

    /// 这本秘籍练什么（「an en in」），写在名字旁边。
    func bookFocus(_ v: String) -> String { region(giving: v)?.hint ?? "" }

    /// 等级的写法：「3 级」；原来是「第三重」。
    func levelText(_ rank: Int) -> String {
        let r = max(1, min(5, rank))
        return xpLevels ? "\(r) 级" : "第\(["", "一", "二", "三", "四", "五"][r])重"
    }

    /// 这本秘籍这一级走了多少（0…1）。
    func bookProgress(_ v: String) -> Double {
        xpLevels ? BookXP.progress(progress.volumes[v]?.xp ?? 0) : cardProgress(of: v)
    }

    /// 地图上点开岛的卡片里写秘籍的那一行：拿到了写「葫芦集秘籍 · 2 级」；没拿到写怎么拿。
    func sheetBookLine(_ r: Region) -> String {
        let name = bookName(r.volume)
        if let st = progress.volumes[r.volume], st.obtained { return "\(name) · \(levelText(xpLevels ? BookXP.level(st.xp) : st.rank))" }
        return obtainAtStele ? "打完碑文即可获得\(name)" : "打赢掌门即可获得\(name)"
    }

    /// 这一卷在哪个地区、谁手里。
    func region(giving v: String) -> Region? { content.regions.first { $0.volume == v } }
}
