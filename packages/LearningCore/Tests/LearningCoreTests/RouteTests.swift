import Testing
@testable import LearningCore

/// 一趟路：8–10 战，倒数第二站一定是群战，最后是掌门；1–2 场奇遇（葫芦集只有一段，就一场）。葫芦集和别的岛一样（2026-11-09 起）。
/// 原来的课程（shortFirstLevel）：第一关固定 6 战：单挑、3 人群战、单挑、单挑、5 人群战、掌门，没有奇遇。
/// 通关后再去一趟也是这样完整的一趟（2026-11-01 起，原来是随机一场）。
@Suite struct RouteTests {
    let c = TestContent.shared

    func fights(_ r: Route) -> Int { r.stations.filter { $0.kind != .encounter }.count }

    @Test func shapeOfARoute() {
        for id in ["huluji", "banshanzhen"] {
            let region = c.region(id)!
            for seed in 1...40 as ClosedRange<UInt64> {
                let r = RoutePlanner.plan(region: region, content: c, seed: seed)
                let n = r.stations.count
                #expect((8...10).contains(fights(r)), "\(id) \(seed)")
                #expect(r.stations[n - 1].kind == .boss)
                #expect(r.stations[n - 2].kind == .group)
                let enc = r.stations.indices.filter { r.stations[$0].kind == .encounter }
                #expect((1...2).contains(enc.count))
                #expect(Set(enc.compactMap { r.stations[$0].encounterId }).count == enc.count)
                if id == "huluji" {
                    let old = RoutePlanner.plan(region: region, content: c, seed: seed, shortFirstLevel: true)
                    #expect(old.stations.map(\.kind) == [.duel, .group, .duel, .duel, .group, .boss])
                    #expect(old.stations.map(\.groupSize) == [nil, 3, nil, nil, 5, nil])
                }
                for s in r.stations where s.kind == .duel || s.kind == .group {
                    #expect(s.foe != nil)
                    #expect(!s.line.isEmpty)
                }
            }
        }
    }

    @Test func sameSeedSameRoute() {
        let region = c.region("banshanzhen")!
        #expect(RoutePlanner.plan(region: region, content: c, seed: 9) == RoutePlanner.plan(region: region, content: c, seed: 9))
    }

    @Test func encountersFavourTheVolume() {
        let region = c.region("banshanzhen")!
        let best = RoutePlanner.encounterCandidates(region: region, content: c)
        let counts = best.map { e in e.syllables.filter { c.volume(of: $0) == region.volume }.count }
        #expect(counts == counts.sorted(by: >))
    }
}
