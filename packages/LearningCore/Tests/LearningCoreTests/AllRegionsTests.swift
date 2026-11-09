import Testing
@testable import LearningCore

/// 十片地区全部开放：用真实 content.json 看每片地区都能进去、内容写齐、路排得出来。
@Suite struct AllRegionsTests {
    let c = TestContent.shared

    @Test func allTenPlayable() {
        #expect(c.regions.count == 10)
        for r in c.regions { #expect(r.playable, "\(r.name) 还没开放") }
    }

    /// 和生成脚本的校验同一套条件：过场、掌门台词、两种对手、配色、例字都属于这一卷。
    @Test(arguments: TestContent.shared.regions.map(\.id)) func contentComplete(_ id: String) {
        let r = c.region(id)!
        #expect(r.stationLines.count >= 5, "\(r.name) 过场不够")
        #expect(!(r.boss.intro ?? "").isEmpty, "\(r.name) 掌门没有开打的话")
        #expect((r.boss.lifeLines ?? []).count >= 2, "\(r.name) 掌门丢命的话不够")
        #expect(!(r.boss.defeatLine ?? "").isEmpty, "\(r.name) 掌门没有被打赢的话")
        #expect(r.foes.count >= 2, "\(r.name) 对手不到两种")
        for f in r.foes { #expect(!(f.intro ?? "").isEmpty, "\(r.name) 的 \(f.name) 没有出场话") }
        #expect(r.theme != nil, "\(r.name) 没有配色")
        for e in r.examples { #expect(c.volume(of: e.pinyin) == r.volume, "\(r.name) 的例字 \(e.char) 不属于这一卷") }
        if id != "huluji" {
            for kind in ["tibishi", "tuobei"] {
                #expect(c.encounters.filter { $0.regions.contains(id) && $0.kind == kind }.count >= 2, "\(r.name) 的「\(kind)」不到两段")
            }
        }
    }

    /// 每片地区排出的路：8–10 战（葫芦集 6 战），掌门前一站是群战，除葫芦集外有奇遇；对手和奇遇都是这片地区自己的。
    @Test(arguments: TestContent.shared.regions.map(\.id)) func routeShape(_ id: String) {
        let r = c.region(id)!
        let foes = Set(r.foes.map(\.name))
        for seed in 1...20 as ClosedRange<UInt64> {
            let route = RoutePlanner.plan(region: r, content: c, seed: seed)
            let st = route.stations
            let fights = st.filter { $0.kind != .encounter }.count
            #expect((8...10).contains(fights), "\(r.name) \(seed) 打 \(fights) 战")
            #expect(st.last?.kind == .boss)
            #expect(st[st.count - 2].kind == .group)
            let enc = st.compactMap(\.encounterId)
            #expect(!enc.isEmpty, "\(r.name) \(seed) 奇遇数不对")
            for e in enc { #expect(c.encounters.first { $0.id == e }?.regions.contains(id) == true, "\(r.name) 排到了别处的奇遇 \(e)") }
            for s in st where s.kind == .duel { #expect(foes.contains(s.foe?.name ?? ""), "\(r.name) 出现了别处的对手") }
        }
    }
}
