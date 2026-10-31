import Testing
@testable import DuelCore

/// 气、必杀
@Suite struct QiFinisherTests {
    @Test func qiPerStrikeCappedAtFifteen() {
        let e = Fixture.engine(features: [.qi])
        e.player.combo = 20
        e.player.lastStrikeAt = e.gameClock
        let clock = FakeClock()
        clock.type(e, "pengyou")
        #expect(e.player.qi == 15)
    }

    /// 攒气倍数（测试用）：5 倍时一招攒的气是平时的 5 倍。
    @Test func qiMultiplierSpeedsUpQi() {
        func qi(_ m: Double) -> Int {
            var t = Fixture.hpMode
            t.qiMultiplier = m
            let e = Fixture.engine(features: [.qi], tuning: t)
            FakeClock().type(e, "pengyou")
            return e.player.qi
        }
        #expect(qi(1) > 0)
        #expect(qi(5) == 5 * qi(1))
    }

    /// 默认按血量打：打空对手血条才赢，气条开着。
    @Test func defaultsEndByHPWithQi() {
        #expect(Tuning.standard.movesPerDuel == 0)
        #expect(Tuning.standard.qiBar)
    }

    /// 关掉气条：出招不攒气，气快满了也不会多出一张成语牌。
    @Test func qiBarOffStopsQi() {
        var t = Fixture.hpMode
        t.qiBar = false
        let e = Fixture.engine(features: [.qi], tuning: t)
        e.player.qi = 95
        let clock = FakeClock()
        let ev = clock.type(e, "pengyou")
        #expect(e.player.qi == 95)
        #expect(!ev.contains(.qiFull))
        #expect(e.cards.filter(\.isFinisher).isEmpty)
    }

    /// 默认：伤害只看字母数（连招、重数都不加），完美多攒气，必杀打掉对手总血量的四分之一。
    @Test func defaultDamageIsLettersOnly() {
        var t = Fixture.hpMode
        t.comboBonusPerHit = Tuning.standard.comboBonusPerHit
        t.rankBonusPerLevel = Tuning.standard.rankBonusPerLevel
        let e = Fixture.engine(features: [], tuning: t)
        let card = e.cards[0]
        #expect(e.damage(for: card, combo: 1, store: 1) == e.damage(for: card, combo: 10, store: 1))
        #expect(e.damage(for: card, combo: 1, store: 1) == card.word.letterCount)
    }

    @Test func perfectMoveGivesExtraQi() {
        var t = Fixture.hpMode
        t.perfectQi = 5
        let e = Fixture.engine(features: [.qi], tuning: t)
        let clock = FakeClock()
        clock.type(e, "pengyou", dt: 0.1)            // 快又没错：完美
        #expect(e.player.qi == 5 + 1 + 5)
    }

    @Test func finisherTakesShareOfMaxHP() throws {
        var t = Fixture.hpMode
        t.finisherShare = 0.25
        let e = Fixture.engine(features: [.qi], tuning: t)
        e.player.qi = 95
        let clock = FakeClock()
        clock.type(e, "pengyou")
        let finisher = e.cards.filter(\.isFinisher).first
        let gold = try #require(finisher)
        #expect(e.damage(for: gold, combo: 7, store: 1) == Int((Double(e.opponent.maxHP) * 0.25).rounded()))
    }

    @Test func parryAndBlockGiveQi() {
        let e = Fixture.engine(features: [.qi, .incoming])
        e.opponent.nextAttackAt = 0
        let clock = FakeClock()
        clock.wait(e, 0.01)
        clock.type(e, e.opponent.incoming!.word.letters, dt: 0.01)
        #expect(e.player.qi == 18)
    }

    @Test func fullQiDealsGoldenIdiomAndFinisher() throws {
        let e = Fixture.engine(features: [.qi])
        e.player.qi = 95
        let clock = FakeClock()
        let ev = clock.type(e, "pengyou")
        #expect(ev.contains(.qiFull))
        let goldCard = e.cards.first(where: \.isFinisher)
        let gold = try #require(goldCard)
        #expect(gold.word.isIdiom)
        e.player.combo = 2
        e.player.lastStrikeAt = e.gameClock
        let hit = clock.type(e, gold.word.letters)
        let dmg = hit.compactMap { if case .strike(_, let d, _, true, _) = $0 { return d } else { return nil } }.first
        #expect(dmg == Int((45 * (1 + 0.03 * 3)).rounded()))
        #expect(e.player.qi == 0)
    }

    @Test func heavyMoveInterruptsCharge() {
        let e = Fixture.engine(["装修工", "朋友", "光明"], features: [.incoming])
        e.opponent.nextAttackAt = 0
        let clock = FakeClock()
        clock.wait(e, 0.01)
        #expect(e.opponent.incoming != nil)
        let ev = clock.type(e, "zhuangxiugong", dt: 0.01)
        #expect(ev.contains(.chargeInterrupted))
        #expect(e.opponent.incoming == nil)
    }

    @Test func cardWeightThresholds() {
        let t = Tuning.standard
        let e = Fixture.engine(["朋友", "装修", "装修工"], features: [])
        #expect(e.cards[0].weight(t) == .medium)       // pengyou 7
        #expect(e.cards[1].weight(t) == .medium)       // zhuangxiu 9
        #expect(e.cards[2].weight(t) == .heavy)        // 12
        let f = Fixture.engine(["吃饭", "妈妈", "开心"], features: [])
        #expect(f.cards[0].weight(t) == .light)
    }
}
