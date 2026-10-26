import Foundation

/// 一趟路上的一站。
public struct Station: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case duel, encounter, boss }
    public var kind: Kind
    /// 比武和掌门站的对手。
    public var foe: Fighter?
    /// 奇遇站的篇目。
    public var encounterId: String?
    /// 开打前的一句过场。
    public var line: String
}

/// 进一次地区排好的路线。
public struct Route: Codable, Sendable, Equatable {
    public var regionId: String
    public var stations: [Station]
}

/// 排路线：5–6 站，终点掌门；随机 1–2 站变成奇遇（不放在掌门前一站）；对手和过场随机组合。
public enum RoutePlanner {
    public static func plan(region: Region, content: LearningContent, seed: UInt64) -> Route {
        var rng = SplitMix(seed: seed)
        let total = Int(rng.next() % 2) + 5
        let duelSlots = total - 1                          // 掌门之前的站
        let encCount = min(Int(rng.next() % 2) + 1, max(0, duelSlots - 1))
        // 奇遇可以放的位置：掌门前一站除外
        var slots = Array(0..<(duelSlots - 1)).shuffled(using: &rng)
        let encSlots = Set(slots.prefix(encCount))
        let encs = Array(encounterCandidates(region: region, content: content).prefix(3)).shuffled(using: &rng)
        var lines = region.stationLines.shuffled(using: &rng)
        var stations: [Station] = []
        var k = 0
        for i in 0..<duelSlots {
            if encSlots.contains(i), k < encs.count {
                let e = encs[k]
                k += 1
                stations.append(Station(kind: .encounter, foe: nil, encounterId: e.id, line: e.intro))
            } else {
                let foe = region.foes[Int(rng.next() % UInt64(max(1, region.foes.count)))]
                if lines.isEmpty { lines = region.stationLines.shuffled(using: &rng) }
                let line = lines.popLast() ?? foe.intro ?? ""        // 过场按站点说，说完了再用对手自己的
                stations.append(Station(kind: .duel, foe: foe, encounterId: nil, line: line))
            }
        }
        stations.append(Station(kind: .boss, foe: region.boss, encounterId: nil, line: region.boss.intro ?? ""))
        return Route(regionId: region.id, stations: stations)
    }

    /// 这片地区的奇遇，按这一卷的字的多少排（多的在前）。
    public static func encounterCandidates(region: Region, content: LearningContent) -> [Encounter] {
        var scored: [(enc: Encounter, n: Int)] = []
        for e in content.encounters where e.regions.contains(region.id) {
            scored.append((e, e.syllables.filter { content.volume(of: $0) == region.volume }.count))
        }
        scored.sort { a, b in a.n != b.n ? a.n > b.n : a.enc.id < b.enc.id }
        return scored.map { $0.enc }
    }
}
