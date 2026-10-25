import Foundation

extension DuelEngine {
    func nextAttackDelay() -> Double {
        let j = tuning.attackIntervalJitter
        return tuning.attackInterval * rng.uniform(1 - j, 1 + j)
    }

    func scheduleNextAttack(from t: Double) {
        let base = max(t, opponent.stunnedUntil)
        opponent.nextAttackAt = base + nextAttackDelay()
    }

    /// 蓄力时长 = 字母数 × 每字母用时 × 2.0 + 0.9 秒，至少 2.4 秒。
    func chargeDuration(for word: Word) -> Double {
        max(tuning.chargeMinSeconds, Double(word.letterCount) * player.secondsPerLetter * tuning.chargePerLetterFactor + tuning.chargeBaseSeconds)
    }

    func stepIncoming() {
        guard features.contains(.incoming) else { return }
        if let inc = opponent.incoming {
            if clock >= inc.startedAt + inc.duration { hitByIncoming() }
            return
        }
        guard !opponent.isStunned(at: clock), clock >= opponent.nextAttackAt else { return }
        // 来招只用已学会的音节，首字母避开场上三张牌；找不到就下一帧再试
        let taken = takenFirstLetters(excludingSlot: nil)
        let table = onTable(excludingSlot: nil)
        let pool = bank.plainWords.filter {
            $0.syllables.allSatisfy(learner.learned.contains) && !taken.contains($0.firstLetter) && !table.contains($0.text)
        }
        guard !pool.isEmpty else { return }
        let w = pool[Int(rng.next() % UInt64(pool.count))]
        let d = chargeDuration(for: w)
        opponent.incoming = IncomingAttack(word: w, startedAt: clock, duration: d)
        emit(.incomingStarted(word: w.text, duration: d))
    }

    func hitByIncoming() {
        let dmg = tuning.incomingDamage
        if target == .incoming {
            target = .none
            firstLetterAt = nil
        }
        opponent.incoming = nil
        player.hp = max(0, player.hp - dmg)
        emit(.hitByIncoming(damage: dmg))
        breakCombo()
        scheduleNextAttack(from: clock)
        if player.hp <= 0 { finish(won: false) }
    }

    /// 打完来招：前 45% 内是弹反（对手晕 1.6 秒），否则是格挡。
    func checkIncomingDone() {
        guard let inc = opponent.incoming, inc.typed.count == inc.word.letterCount else { return }
        let frac = (clock - inc.startedAt) / inc.duration
        if frac <= tuning.parryFraction {
            opponent.stunnedUntil = clock + tuning.stunSeconds
            parries += 1
            emit(.parried)
            gainQi(tuning.qiParry)
        } else {
            emit(.blocked)
            gainQi(tuning.qiBlock)
        }
        opponent.incoming = nil
        target = .none
        firstLetterAt = nil
        player.lastStrikeAt = clock
        readyAt = clock
        scheduleNextAttack(from: clock)
    }
}
