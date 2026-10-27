import Foundation

extension DuelEngine {
    /// 一次只出一张牌。
    var singleCard: Bool { tuning.cardsOnTable <= 1 }

    /// 掌门蓄力打不断：对手 3 条命以上、开关打开时。
    var bossMode: Bool { (setup.bossPressure ?? tuning.bossPressure) && singleCard && livesOn && opponent.maxLives >= 3 }

    /// 掌门一轮蓄力：bossCycleCards 张牌的时间（一张按 6 个字母、玩家的手速，再加 0.8 秒看牌），丢一条命快一次。
    var bossCycleSeconds: Double {
        max(tuning.pressureMinSeconds, tuning.bossCycleCards * (6 * player.secondsPerLetter + 0.8)) * lifePressureFactor
    }

    /// 掌门：打完一张普通牌，蓄力往回推一截；必杀打断，清零重来。
    func bossStruck(finisher: Bool) {
        guard bossMode, let s = opponent.pressureStart else { return }
        if finisher {
            opponent.pressureStart = nil
            emit(.chargeInterrupted)
        } else {
            opponent.pressureStart = min(max(clock, s), s + tuning.bossPushBack * opponent.pressureDuration)
        }
    }

    /// 1 张牌模式：每张新牌都开始一次对手蓄力（掌门打不断时只在没在蓄力时开始）。
    func startPressure() {
        guard singleCard, features.contains(.incoming), let card = cards.first(where: { !$0.inactive }) else { return }
        if setup.firstCardFree && moveMarks.isEmpty { return }      // 教学：第一张牌打完之前不蓄力
        if bossMode {
            guard opponent.pressureStart == nil else { return }
            let d = bossCycleSeconds
            opponent.pressureStart = max(clock, foeDownUntil)
            opponent.pressureDuration = d
            emit(.pressureStarted(duration: d))
            return
        }
        let d = max(tuning.pressureMinSeconds,
                    Double(card.word.letterCount) * player.secondsPerLetter * tuning.pressureFactor + tuning.pressureBaseSeconds) * lifePressureFactor
        opponent.pressureStart = max(clock, foeDownUntil)           // 丢了一条命正跪着：站起来再蓄力
        opponent.pressureDuration = d
        emit(.pressureStarted(duration: d))
    }

    /// 条满之前没打完：对手出手，掉血、断连招，同一张牌重新蓄力（牌上已打的字母保留）。
    func stepPressure() {
        guard singleCard, let s = opponent.pressureStart, clock >= s + opponent.pressureDuration else { return }
        if bossMode && awaitingReveal { return }                    // 演回顾时掌门也停着
        let dmg = bossMode ? tuning.bossHit : tuning.incomingDamage
        let dead = hurtPlayer(dmg)
        emit(.hitByIncoming(damage: dmg))
        breakCombo()
        if dead {
            opponent.pressureStart = nil
            finish(won: false)
            return
        }
        if bossMode { opponent.pressureStart = nil }
        startPressure()
    }
}
