import Foundation

/// 群战（试玩）：一张牌照常打，场上最多 groupSize 个敌人各自蓄力；打完一张牌自动打蓄力最多的那个并打断它的蓄力，
/// 必杀打全场；倒下一个，队里的下一个补到空出来的站位上。一共 groupTotal 个，打完最后一个才赢。
/// 一场多长用敌人的等级来控制（喽啰血少、头目血多），不单独调每个人的血。
extension DuelEngine {
    var groupMode: Bool { tuning.groupFight && singleCard }

    /// 出场顺序：最后一个是头目，每第三个是镖师，其余是喽啰（五个人：喽啰、喽啰、镖师、喽啰、头目）。
    static func groupLineup(total: Int) -> [FoeTier] {
        (0..<max(1, total)).map { i in
            if i == total - 1 { return .boss }
            return i % 3 == 2 ? .guardsman : .minion
        }
    }

    func startGroup() {
        unitHP = opponent.maxHP
        foeQueue = Self.groupLineup(total: tuning.groupTotal)
        foes = []
        let n = min(max(1, tuning.groupSize), foeQueue.count)
        for slot in 0..<n { joinFoe(slot: slot, stagger: Double(slot) / Double(n)) }
        refreshGroupHP()
        opponent.maxHP = max(1, opponent.hp)
    }

    /// 队里的下一个站到 slot 上。stagger 是开局错开的比例：蓄力晚这么多份才开始，免得几条一起满。
    func joinFoe(slot: Int, stagger: Double = 0) {
        guard !foeQueue.isEmpty else { return }
        let tier = foeQueue.removeFirst()
        let hp = max(1, Int((Double(unitHP) * tier.hpFactor).rounded()))
        var f = Foe(id: nextFoeId, tier: tier, slot: slot, maxHP: hp, hp: hp, pressureStart: clock, pressureDuration: 1)
        nextFoeId += 1
        f.pressureDuration = foePressureDuration(tier, onField: foes.count + 1)
        f.pressureStart = clock + stagger * f.pressureDuration
        foes.append(f)
        lastJoined.append(f.id)
        emit(.foeJoined(id: f.id, tier: tier, slot: slot))
    }

    /// 蓄力时长：和单挑一样按这张牌的字母数和玩家手速算，再乘场上人数（人多每个人就慢，总的挨打频率和单挑差不多）和等级倍数。
    func foePressureDuration(_ tier: FoeTier, onField: Int) -> Double {
        let letters = Double(cards.first(where: { !$0.inactive })?.word.letterCount ?? 6)
        let single = max(tuning.pressureMinSeconds, letters * player.secondsPerLetter * tuning.pressureFactor + tuning.pressureBaseSeconds)
        return single * Double(max(1, onField)) * tier.pressureFactor
    }

    func restartFoePressure(_ i: Int) {
        foes[i].pressureDuration = foePressureDuration(foes[i].tier, onField: foes.count)
        foes[i].pressureStart = clock
    }

    /// 对手的总血条 = 场上剩下的血 + 还没上场的满血，状态栏照旧显示一条。
    func refreshGroupHP() {
        let queued = foeQueue.reduce(0) { $0 + max(1, Int((Double(unitHP) * $1.hpFactor).rounded())) }
        opponent.hp = max(0, foes.reduce(0) { $0 + max(0, $1.hp) } + queued)
        opponent.name = "群战"
        opponent.title = "还剩 \(foes.count + foeQueue.count) 人"
    }

    /// 打完一张牌：打蓄力最多的那个（一样多就打离主角近的），打断它的蓄力；必杀打全场。
    func groupStrike(damage: Int, finisher: Bool) {
        lastStruck = []; lastDowned = []; lastJoined = []
        if finisher {
            let hit = max(1, Int((Double(unitHP) * tuning.finisherShare).rounded()))
            for i in foes.indices { foes[i].hp -= hit; restartFoePressure(i) }
            lastStruck = foes.map(\.id)
        } else if let i = foes.indices.max(by: { a, b in
            let pa = foes[a].pressureProgress(at: clock), pb = foes[b].pressureProgress(at: clock)
            return pa != pb ? pa < pb : foes[a].slot > foes[b].slot
        }) {
            foes[i].hp -= damage
            restartFoePressure(i)
            lastStruck = [foes[i].id]
        }
        for f in foes where f.hp <= 0 {
            lastDowned.append(f.id)
            emit(.foeDefeated(id: f.id))
        }
        let freed = foes.filter { $0.hp <= 0 }.map(\.slot).sorted()
        foes.removeAll { $0.hp <= 0 }
        for slot in freed { joinFoe(slot: slot) }
        refreshGroupHP()
    }

    /// 谁的蓄力条满了谁出手；被盖着演回顾时不走。
    func stepGroup() {
        guard !awaitingReveal else { return }
        for i in foes.indices where foes[i].pressureProgress(at: clock) >= 1 {
            let dmg = foes[i].tier.hit
            player.hp = max(0, player.hp - dmg)
            emit(.foeAttacked(id: foes[i].id, damage: dmg))
            breakCombo()
            if player.hp <= 0 { finish(won: false); return }
            restartFoePressure(i)
        }
    }
}
