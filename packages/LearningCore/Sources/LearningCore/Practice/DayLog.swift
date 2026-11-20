import Foundation

/// 一台设备一天的记录（日历用，「打几场」「来了几天」也从这里数）。打完一场的结算时记一次。
/// 只记收获：几场、新词卡、每本秘籍涨的经验和升级、掌门印、比武最快的速度、拿到的勋章。
public struct DayLog: Codable, Sendable, Equatable {
    /// 本机日历日（DayClock 的天数）。
    public var day: Int
    /// 哪台设备写的（读的时候把各设备的合起来）。
    public var deviceId: String
    /// 设备的叫法：「iPhone」「Mac」。
    public var device: String
    public var duels = 0
    public var texts = 0
    public var newCards = 0
    /// 每本秘籍涨的经验（按卷）。
    public var xp: [String: Int] = [:]
    /// 每本秘籍最后一次涨经验的时刻（经验一样多时取最后打的那本）。
    public var xpAt: [String: Double] = [:]
    /// 这一天的升级：「卷|升到几级」。
    public var levelUps: [String] = []
    /// 这一天掌门盖印的岛。
    public var seals: [String] = []
    /// 这一天当选武林盟主。
    public var crowned = false
    /// 这一天比武里最快的一场（字/分）；0 = 没有比武。
    public var bestCPM: Double = 0
    /// 这一天最后去的岛和时刻（没涨经验时，日历的方块按它）。
    public var lastRegion = ""
    public var lastAt: Double = 0
    /// 这一天拿到的勋章（「台阶:第几级」，第几级从 0 数）。
    public var badges: [String] = []

    public init(day: Int, deviceId: String, device: String) {
        self.day = day
        self.deviceId = deviceId
        self.device = device
    }

    public var fights: Int { duels + texts }
}

/// 同一天各台设备的记录合起来：场数、经验相加，升级、掌门印、勋章并起来；速度分设备。
public struct DaySummary: Sendable, Equatable {
    public var day: Int
    public var duels = 0
    public var texts = 0
    public var newCards = 0
    public var xp: [String: Int] = [:]
    public var xpAt: [String: Double] = [:]
    public var levelUps: [String] = []
    public var seals: [String] = []
    public var crowned = false
    public var lastRegion = ""
    public var lastAt: Double = 0
    public var badges: [String] = []
    /// 每台设备：叫法、几场、比武最快的速度（只有一台时也有一项）。
    public var devices: [(device: String, fights: Int, bestCPM: Double)] = []

    public var fights: Int { duels + texts }

    public init(_ logs: [DayLog]) {
        day = logs.first?.day ?? 0
        for l in logs.sorted(by: { $0.deviceId < $1.deviceId }) {
            duels += l.duels
            texts += l.texts
            newCards += l.newCards
            for (v, n) in l.xp { xp[v, default: 0] += n }
            for (v, t) in l.xpAt { xpAt[v] = max(xpAt[v] ?? 0, t) }
            for u in l.levelUps where !levelUps.contains(u) { levelUps.append(u) }
            for s in l.seals where !seals.contains(s) { seals.append(s) }
            crowned = crowned || l.crowned
            if l.lastAt >= lastAt, !l.lastRegion.isEmpty { lastRegion = l.lastRegion; lastAt = l.lastAt }
            for b in l.badges where !badges.contains(b) { badges.append(b) }
            if l.fights > 0 { devices.append((l.device, l.fights, l.bestCPM)) }
        }
    }

    /// 方块用哪本秘籍：当天经验涨得最多的那本；一样多取最后打的那本；没涨经验返回 nil。
    public var topVolume: String? {
        xp.filter { $0.value > 0 }.max { ($0.value, xpAt[$0.key] ?? 0) < ($1.value, xpAt[$1.key] ?? 0) }?.key
    }

    /// 这一天每本秘籍升到的最高等级。
    public var levelReached: [String: Int] {
        var out: [String: Int] = [:]
        for u in levelUps {
            let p = u.split(separator: "|")
            guard p.count == 2, let lv = Int(p[1]) else { continue }
            out[String(p[0])] = max(out[String(p[0])] ?? 0, lv)
        }
        return out
    }

    public static func == (a: DaySummary, b: DaySummary) -> Bool {
        a.day == b.day && a.fights == b.fights && a.xp == b.xp && a.badges == b.badges && a.seals == b.seals
    }
}
