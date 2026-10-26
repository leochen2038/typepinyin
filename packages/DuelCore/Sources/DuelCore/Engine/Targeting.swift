import Foundation

extension DuelEngine {
    /// 比武中的一次按键。
    func process(_ key: KeyEvent, at g: Double) {
        switch key.kind {
        case .backspace:
            clearTarget()
        case .teach:
            break                                           // 读音键：界面自己读，引擎不管
        case .letter(let raw):
            let c = Character(raw.lowercased())
            guard c != " " else { return }                 // 空格被忽略
            if let expected = key.nearMissOf {               // 按偏了：不进输入、不罚
                emit(.nearMiss(expected: expected))
                return
            }
            switch target {
            case .none: lock(c)
            case .card(let i): typeOnCard(i, c)
            case .incoming: typeOnIncoming(c)
            }
        }
    }

    // MARK: 锁定

    func lock(_ c: Character) {
        if let inc = opponent.incoming, inc.word.firstLetter == c {
            target = .incoming
            beginTarget(readyFrom: inc.startedAt)
            opponent.incoming?.typed = String(c)
            emit(.locked(.incoming))
            emit(.letterAccepted(.incoming, c))
            checkIncomingDone()
            return
        }
        if let i = cards.firstIndex(where: { $0.word.firstLetter == c && !$0.inactive }) {
            target = .card(i)
            if features.contains(.store) { cards[i].frozenStore = storeAt(cards[i], clock) }
            beginTarget(readyFrom: max(readyAt, cards[i].dealtAt))
            checkComboGapOnLock()
            resetTrack(for: cards[i].word)
            if hintPendingFirst { track.hinted[0] = true }
            hintPendingFirst = false
            cards[i].typed = String(c)
            trackAccepted(word: cards[i].word, pos: 0)
            emit(.locked(.card(i)))
            emit(.letterAccepted(.card(i), c))
            checkCardDone(i)
            return
        }
        emit(.letterRejected(c))
    }

    func beginTarget(readyFrom: Double) {
        readyAt = min(readyFrom, clock)
        firstLetterAt = clock
        lastAcceptedAt = clock
        wordClean = !hintedBeforeLock
        hintedBeforeLock = false
    }

    func clearTarget() {
        switch target {
        case .none: return
        case .card(let i):
            cards[i].typed = ""
            if let f = cards[i].frozenStore {                // 松开后蓄势接着涨，不归零
                cards[i].dealtAt = clock - (f - 1) / max(0.0001, tuning.storeGainPerSecond)
                cards[i].frozenStore = nil
            }
        case .incoming:
            opponent.incoming?.typed = ""
        }
        target = .none
        firstLetterAt = nil
        emit(.targetCleared)
    }

    // MARK: 逐字母

    func typeOnCard(_ i: Int, _ c: Character) {
        let letters = Array(cards[i].word.letters)
        let pos = cards[i].typed.count
        guard pos < letters.count else { return }
        if letters[pos] == c {
            cards[i].typed.append(c)
            trackAccepted(word: cards[i].word, pos: pos)
            lastAcceptedAt = clock
                emit(.letterAccepted(.card(i), c))
            checkCardDone(i)
        } else {
            trackWrong(word: cards[i].word, pos: pos)
            wrongLetter(word: cards[i].word, typed: pos, onIncoming: false)
        }
    }

    func typeOnIncoming(_ c: Character) {
        guard let inc = opponent.incoming else { target = .none; return }
        let letters = Array(inc.word.letters)
        let pos = inc.typed.count
        guard pos < letters.count else { return }
        if letters[pos] == c {
            opponent.incoming?.typed.append(c)
            lastAcceptedAt = clock
                emit(.letterAccepted(.incoming, c))
            checkIncomingDone()
        } else {
            wrongLetter(word: inc.word, typed: pos, onIncoming: true)
        }
    }

    /// 打错一个字母：没学过的音节第一次错是「新招」，不罚；已学会的才罚。
    func wrongLetter(word: Word, typed: Int, onIncoming: Bool) {
        let idx = word.syllableIndex(atLetter: typed)
        let s = word.syllables[idx]
        wordClean = false
        if features.contains(.teaching), learner.isNew(s) {
            let n = (learner.missCount[s] ?? 0) + 1
            learner.missCount[s] = n
            if n == 1 {
                if !newMoves.contains(s) { newMoves.append(s) }
                emit(.newMove(s))
                learner.taught.insert(s)
                if let source {
                    source.newMove(s)                           // 旅程：复现由出牌来源安排
                } else {
                    // 新招：接下来补的第 2 张、第 5 张牌里再出现它
                    for k in tuning.replayOffsets { learner.replayQueue.append((deal: dealCount + k - 1, syllable: s)) }
                }
            }
            hintNow(word: word, typed: typed)
            return
        }
        if onIncoming {                                       // 打来招时按错不额外掉血
            emit(.mistake(s, damage: 0))
            hintNow(word: word, typed: typed)
            return
        }
        let dmg = tuning.mistakeDamage
        let dead = hurtPlayer(dmg)
        emit(.mistake(s, damage: dmg))
        breakCombo()
        if dead { finish(won: false); return }
        hintNow(word: word, typed: typed)
    }

    // MARK: 打完

    func checkCardDone(_ i: Int) {
        guard cards[i].typed.count == cards[i].word.letterCount else { return }
        strike(i)
    }

    func strike(_ i: Int) {
        let card = cards[i]
        let store = features.contains(.store) ? (card.frozenStore ?? storeAt(card, clock)) : 1
        addCombo()
        let dmg = damage(for: card, combo: player.combo, store: store)
        let heavy = card.word.letterCount >= tuning.heavyLetters
        let flawHit = features.contains(.flaw) && card.hasFlaw
        let perLetter = firstLetterAt.map { (clock - $0 + max(0, $0 - readyAt) * 0.5) / Double(max(1, card.word.letterCount)) } ?? 9
        let gold = wordClean && perLetter <= tuning.goldSecondsPerLetter
        recordSpeed(word: card.word)
        source?.cardDone(card.word, clean: wordClean)
        if heavy, opponent.incoming != nil {                  // 重招打断蓄力
            opponent.incoming = nil
            emit(.chargeInterrupted)
            scheduleNextAttack(from: clock)
        }
        charactersTyped += card.word.text.count
        let byMoves = tuning.movesPerDuel > 0
        moveMarks.append(gold)                                  // 每招金不金都记（回顾盖「金」印、小结数金招）
        if groupMode {
            groupStrike(damage: dmg, finisher: card.isFinisher)
        } else if byMoves {
            let left = max(0, tuning.movesPerDuel - moveMarks.count)
            opponent.hp = Int((Double(opponent.maxHP) * Double(left) / Double(tuning.movesPerDuel)).rounded())
        } else {
            hitWithLives(dmg, finisher: card.isFinisher)
            bossStruck(finisher: card.isFinisher)
        }
        emit(.strike(card: i, damage: dmg, flaw: flawHit, finisher: card.isFinisher, heavy: heavy))
        emit(.moveDone(index: moveMarks.count - 1, gold: gold))
        gainQiForStrike(flaw: flawHit, finisher: card.isFinisher, perfect: gold)
        player.lastStrikeAt = clock
        readyAt = clock
        target = .none
        firstLetterAt = nil
        if opponent.hp <= 0 {
            finish(won: true)
            return
        }
        if byMoves && moveMarks.count == tuning.movesPerDuel - 1 {   // 最后一招：金色成语牌，其余两张暂停
            finisherPending = false
            cards[i] = makeCard(slot: i, forceFinisher: true)
            for k in cards.indices where k != i { cards[k].inactive = true; cards[k].typed = "" }
            emit(.cardDealt(i))
            emit(.finale)
            dealtNewCard()
            return
        }
        cards[i] = makeCard(slot: i)
        emit(.cardDealt(i))
        dealtNewCard()
        if card.hasFlaw || !cards.contains(where: \.hasFlaw) { assignFlaw(excluding: i) }
    }

    /// 新牌发出来以后：界面要先盖着演回顾的话，等它露出来再开始蓄力；不然马上开始。
    func dealtNewCard() {
        if holdNewCards {
            if !groupMode && !bossMode { opponent.pressureStart = nil }     // 掌门不重来：盖着时停住，露出来再接着走
            holdFrom = clock
            awaitingReveal = true
        } else if !groupMode {
            startPressure()
        }
    }
}
