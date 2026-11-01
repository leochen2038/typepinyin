import DuelCore
import LearningCore
import UIKit

/// 把 LearningCore 的出字器接到比武引擎上。
final class JourneyCardSource: CardSource {
    let dealer: Dealer
    /// 每卷现在的重数（牌上显示、回顾爆字母用）。
    let rankOf: (String) -> Int
    /// 这一场拼错过的没学过的音节（交给出字器排复现）。
    private(set) var newMoves: [String] = []
    /// 每打完一张牌（练功房记打过的词）。
    let onCard: (Word, Bool, Double) -> Void

    init(dealer: Dealer, rankOf: @escaping (String) -> Int, onCard: @escaping (Word, Bool, Double) -> Void = { _, _, _ in }) {
        self.dealer = dealer
        self.rankOf = rankOf
        self.onCard = onCard
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
        dealer.note(Self.content(word), clean: clean)
    }

    func cardDone(_ word: Word, clean: Bool, secondsPerLetter: Double) {
        dealer.note(Self.content(word), clean: clean, secondsPerLetter: secondsPerLetter)
        onCard(word, clean, secondsPerLetter)
    }

    static func content(_ w: Word) -> ContentWord {
        ContentWord(text: w.text, syllables: w.syllables, volume: w.volume, isIdiom: w.isIdiom, freq: 0)
    }

    /// 没学过的音节第一次拼错：交给出字器排复现，先出拼错的这个词。
    func newMove(_ spelling: String, in word: Word) {
        newMoves.append(spelling)
        dealer.newMove(spelling, word: word.text)
    }
}

extension UIColor {
    /// 「#RRGGBB」。
    convenience init(hexString: String) {
        let v = UInt32(hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x8A8F9E
        self.init(hex: v)
    }
}
