import DuelCore
import LearningCore
import UIKit

/// 把 LearningCore 的出字器接到比武引擎上。
final class JourneyCardSource: CardSource {
    let dealer: Dealer
    /// 每卷现在的重数（牌上显示、回顾爆字母用）。
    let rankOf: (String) -> Int
    /// 这一场新招的音节（交给出字器排复现）。
    private(set) var newMoves: [String] = []

    init(dealer: Dealer, rankOf: @escaping (String) -> Int) {
        self.dealer = dealer
        self.rankOf = rankOf
    }

    static func word(_ w: ContentWord) -> Word {
        Word(text: w.text, syllables: w.syllables, volume: w.volume, isIdiom: w.isIdiom)
    }

    func nextCard(avoidingFirstLetters: Set<Character>, avoidingTexts: Set<String>) -> (word: Word, rank: Int) {
        let d = dealer.next(avoidingFirstLetters: avoidingFirstLetters, avoidingTexts: avoidingTexts)
        return (Self.word(d.word), rankOf(d.word.volume))
    }

    func nextIdiom() -> (word: Word, rank: Int)? {
        let w = dealer.nextIdiom()
        return (Self.word(w), rankOf(w.volume))
    }

    func cardDone(_ word: Word, clean: Bool) {
        dealer.note(ContentWord(text: word.text, syllables: word.syllables, volume: word.volume, isIdiom: word.isIdiom, freq: 0), clean: clean)
    }

    func newMove(_ spelling: String) {
        newMoves.append(spelling)
        dealer.newMove(spelling)
    }
}

extension UIColor {
    /// 「#RRGGBB」。
    convenience init(hexString: String) {
        let v = UInt32(hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x8A8F9E
        self.init(hex: v)
    }
}
