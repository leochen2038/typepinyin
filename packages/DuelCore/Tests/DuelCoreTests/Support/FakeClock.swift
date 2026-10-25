import Foundation
@testable import DuelCore

/// 测试用的词表、引擎和按键工具。
enum Fixture {
    static let bank: WordBank = {
        let url = Bundle.module.url(forResource: "test-words", withExtension: "json", subdirectory: "Fixtures")!
        return try! WordBank.load(from: Data(contentsOf: url))
    }()

    static func word(_ text: String) -> Word { bank.words.first { $0.text == text }! }

    /// 开一场比武，再把三张牌换成指定的词（关掉破绽时不带破绽）。
    /// 旧的规则测试按对手血量判输赢；按招数的一场在 MovesRoundTests 里单独测。
    static var hpMode: Tuning { var t = Tuning.standard; t.movesPerDuel = 0; t.cardsOnTable = 3; t.qiBar = true; t.prdDamage(); return t }
    /// 按招数、3 张牌（MovesRoundTests 用）。
    static var threeCards: Tuning { var t = Tuning.standard; t.cardsOnTable = 3; t.qiBar = true; t.prdDamage(); return t }

    static func engine(_ cards: [String] = ["朋友", "装修", "光明"], features: DuelEngine.Features = .all,
                       tuning: Tuning = Fixture.hpMode, seed: UInt64 = 1, at t0: Double = 100) -> DuelEngine {
        let e = DuelEngine(bank: bank, tuning: tuning, opponent: Opponent(name: "林大", title: "镇上的镖师"),
                           seed: seed, features: features)
        e.start(at: t0)
        e.opponent.nextAttackAt = .infinity
        e.cards = cards.enumerated().map { MoveCard(id: 100 + $0.offset, word: word($0.element), dealtAt: 0, rank: 0) }
        return e
    }
}

/// 假时钟：每次按键往前走 `dt` 秒。
final class FakeClock {
    var now: Double
    init(_ start: Double = 100) { now = start }

    @discardableResult
    func type(_ e: DuelEngine, _ letters: String, dt: Double = 0.1) -> [DuelEvent] {
        var out: [DuelEvent] = []
        for c in letters {
            now += dt
            out += e.handle(.letter(c, at: now), at: now)
        }
        return out
    }

    @discardableResult
    func wait(_ e: DuelEngine, _ seconds: Double) -> [DuelEvent] {
        now += seconds
        return e.advance(to: now)
    }
}

extension Tuning {
    /// 旧版的伤害和攒气（连招、重数加伤害，必杀按 45 算，完美不多攒气）。旧规则的测试用它。
    mutating func prdDamage() { comboBonusPerHit = 0.08; rankBonusPerLevel = 0.1; finisherShare = 0; perfectQi = 0 }
}
