import Testing
@testable import LearningCore

/// 一趟路：5–6 站、终点掌门；奇遇 1–2 站、不在掌门前一站；同一种子同一路线。
@Suite struct RouteTests {
    let c = TestContent.shared

    @Test func shapeOfARoute() {
        let region = c.region("shilipo")!
        for seed in 1...40 as ClosedRange<UInt64> {
            let r = RoutePlanner.plan(region: region, content: c, seed: seed)
            #expect((5...6).contains(r.stations.count))
            #expect(r.stations.last?.kind == .boss)
            let enc = r.stations.indices.filter { r.stations[$0].kind == .encounter }
            #expect((1...2).contains(enc.count))
            #expect(!enc.contains(r.stations.count - 2))
            #expect(Set(enc.compactMap { r.stations[$0].encounterId }).count == enc.count)
            for s in r.stations where s.kind == .duel {
                #expect(s.foe != nil)
                #expect(!s.line.isEmpty)
            }
        }
    }

    @Test func sameSeedSameRoute() {
        let region = c.region("banshanzhen")!
        #expect(RoutePlanner.plan(region: region, content: c, seed: 9) == RoutePlanner.plan(region: region, content: c, seed: 9))
    }

    /// 奇遇挑这一卷的字多的篇目。
    @Test func encountersFavourTheVolume() {
        let region = c.region("banshanzhen")!
        let best = RoutePlanner.encounterCandidates(region: region, content: c)
        let counts = best.map { e in e.syllables.filter { c.volume(of: $0) == region.volume }.count }
        #expect(counts == counts.sorted(by: >))
    }
}
