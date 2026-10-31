import Testing
@testable import LearningCore

/// 一趟路：8–10 战（第一关固定 5 战：单挑、3 人群战、单挑、5 人群战、掌门），倒数第二站一定是群战，最后是掌门；
/// 第一关没有奇遇；别的地区 1–2 场奇遇。通关后再进：随机一场（第一关不出奇遇）。
@Suite struct RouteTests {
    let c = TestContent.shared

    func fights(_ r: Route) -> Int { r.stations.filter { $0.kind != .encounter }.count }

    @Test func shapeOfARoute() {
        for id in ["huluji", "banshanzhen"] {
            let region = c.region(id)!
            for seed in 1...40 as ClosedRange<UInt64> {
                let r = RoutePlanner.plan(region: region, content: c, seed: seed)
                let n = r.stations.count
                #expect(id == "huluji" ? fights(r) == 5 : (8...10).contains(fights(r)), "\(id) \(seed)")
                #expect(r.stations[n - 1].kind == .boss)
                #expect(r.stations[n - 2].kind == .group)
                let enc = r.stations.indices.filter { r.stations[$0].kind == .encounter }
                if id == "huluji" {
                    #expect(enc.isEmpty)
                    #expect(r.stations.map(\.kind) == [.duel, .group, .duel, .group, .boss])
                    #expect(r.stations.map(\.groupSize) == [nil, 3, nil, 5, nil])
                } else {
                    #expect((1...2).contains(enc.count))
                    #expect(Set(enc.compactMap { r.stations[$0].encounterId }).count == enc.count)
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

    /// 通关后再进：不走地图，随机来一场掌门、奇遇、单挑或群战。
    @Test func replayIsOneRandomStation() {
        let region = c.region("banshanzhen")!
        var kinds = Set<Station.Kind>()
        for seed in 1...60 as ClosedRange<UInt64> {
            let r = RoutePlanner.replay(region: region, content: c, seed: seed)
            #expect(r.stations.count == 1)
            kinds.insert(r.stations[0].kind)
        }
        #expect(kinds == [.boss, .encounter, .duel, .group])
        var first = Set<Station.Kind>()
        for seed in 1...60 as ClosedRange<UInt64> {
            first.insert(RoutePlanner.replay(region: c.region("huluji")!, content: c, seed: seed).stations[0].kind)
        }
        #expect(first == [.boss, .duel, .group])
    }
}
