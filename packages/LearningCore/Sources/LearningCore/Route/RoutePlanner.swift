import Foundation

/// 一趟路上的一站。
public struct Station: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case duel, group, encounter, boss }
    public var kind: Kind
    /// 比武、群战和掌门站的对手（群战是领头的那个）。
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

/// 排路线：8–10 战（单挑、群战、掌门），倒数第二站一定是群战，最后是掌门；中间也可能再有一场群战。
/// 奇遇另算：第一关只有一场、放在倒数第三站（掌门前那场群战的前面）；别的地区 1–2 场，随机放在前面。
public enum RoutePlanner {
    public static func plan(region: Region, content: LearningContent, seed: UInt64) -> Route {
        var rng = SplitMix(seed: seed)
        let fights = Int(rng.next() % 3) + 8                     // 8–10 战
        let encs = encounterCandidates(region: region, content: content)
        var lines = region.stationLines.shuffled(using: &rng)
        func line(for foe: Fighter) -> String {
            if lines.isEmpty { lines = region.stationLines.shuffled(using: &rng) }
            return lines.popLast() ?? foe.intro ?? ""
        }
        func foe() -> Fighter { region.foes[Int(rng.next() % UInt64(max(1, region.foes.count)))] }

        // 掌门之前的战：最后一场是群战，前面再随机放一场群战（一半的机会）
        var kinds = Array(repeating: Station.Kind.duel, count: fights - 1)
        kinds[fights - 2] = .group
        if rng.next() % 2 == 0, fights - 2 > 2 {
            kinds[Int(rng.next() % UInt64(fights - 3)) + 1] = .group
        }
        var stations = kinds.map { k -> Station in
            let f = foe()
            return Station(kind: k, foe: f, encounterId: nil, line: k == .group ? groupLine(region) : line(for: f))
        }
        // 奇遇
        if region.volume == "base" {
            if let e = encs.first {                               // 第一关：一场，倒数第三站
                stations.insert(Station(kind: .encounter, foe: nil, encounterId: e.id, line: e.intro), at: stations.count - 1)
            }
        } else {
            let count = min(Int(rng.next() % 2) + 1, encs.count)
            let picks = Array(encs.prefix(3)).shuffled(using: &rng).prefix(count)
            for e in picks {
                let at = Int(rng.next() % UInt64(max(1, stations.count - 1)))   // 不放在掌门前那场群战之后
                stations.insert(Station(kind: .encounter, foe: nil, encounterId: e.id, line: e.intro), at: at)
            }
        }
        stations.append(Station(kind: .boss, foe: region.boss, encounterId: nil, line: region.boss.intro ?? ""))
        return Route(regionId: region.id, stations: stations)
    }

    /// 通关以后再进：不走地图，随机来一场掌门、奇遇、单挑或群战。
    public static func replay(region: Region, content: LearningContent, seed: UInt64) -> Route {
        var rng = SplitMix(seed: seed)
        let kinds: [Station.Kind] = [.boss, .encounter, .duel, .group]
        let kind = kinds[Int(rng.next() % UInt64(kinds.count))]
        let station: Station
        switch kind {
        case .boss:
            station = Station(kind: .boss, foe: region.boss, encounterId: nil, line: region.boss.intro ?? "")
        case .encounter:
            let encs = encounterCandidates(region: region, content: content)
            if let e = encs.isEmpty ? nil : encs[Int(rng.next() % UInt64(encs.count))] {
                station = Station(kind: .encounter, foe: nil, encounterId: e.id, line: e.intro)
            } else {
                station = Station(kind: .duel, foe: region.foes.first, encounterId: nil, line: region.stationLines.first ?? "")
            }
        case .group:
            station = Station(kind: .group, foe: region.foes.first, encounterId: nil, line: groupLine(region))
        case .duel:
            let f = region.foes[Int(rng.next() % UInt64(max(1, region.foes.count)))]
            let l = region.stationLines.isEmpty ? (f.intro ?? "") : region.stationLines[Int(rng.next() % UInt64(region.stationLines.count))]
            station = Station(kind: .duel, foe: f, encounterId: nil, line: l)
        }
        return Route(regionId: region.id, stations: [station])
    }

    static func groupLine(_ region: Region) -> String {
        "一伙人从路两边围了上来，领头的是\(region.foes.first?.name ?? "")。"
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
