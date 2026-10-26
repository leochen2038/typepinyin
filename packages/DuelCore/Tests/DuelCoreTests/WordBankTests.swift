import Foundation
import Testing
@testable import DuelCore
import LearningCore

@Suite struct WordBankTests {
    @Test func loadsFixture() {
        #expect(Fixture.bank.words.count == 19)
        #expect(Fixture.bank.idioms.count == 2)
        #expect(Fixture.word("熊猫").letters == "xiongmao")
    }

    @Test func rejectsCountMismatch() {
        let w = Word(text: "熊猫", syllables: ["xiong"], volume: "x")
        #expect(throws: WordBankError.countMismatch("熊猫")) { try w.validate(knownSpellings: ["xiong"]) }
    }

    @Test func rejectsUnknownSyllable() {
        let w = Word(text: "熊猫", syllables: ["xiong", "mao"], volume: "x")
        #expect(throws: WordBankError.unknownSyllable("熊猫", "mao")) { try w.validate(knownSpellings: ["xiong"]) }
    }

    @Test func syllableIndexByLetter() {
        let w = Fixture.word("装修")
        #expect(w.syllableIndex(atLetter: 0) == 0)
        #expect(w.syllableIndex(atLetter: 5) == 0)
        #expect(w.syllableIndex(atLetter: 6) == 1)
        #expect(w.letterOffset(ofSyllable: 1) == 6)
    }

    /// 打包进 App 的内容包，转成比武词表后也要通过校验（每个词的字数 = 拼音数、拼音都在 404 个音节里）。
    @Test func bundledContentIsValidForDuels() throws {
        let here = URL(fileURLWithPath: #filePath)
        let url = here.deletingLastPathComponent().appendingPathComponent("../../../../app/TypePinyin/Resources/content.json").standardized
        let c = try LearningContent.load(from: Data(contentsOf: url))
        let syl = c.syllables.map { Syllable(spelling: $0.spelling, volume: $0.volume, isHard: $0.hardReason != nil,
                                             parts: .init(initial: $0.parts.initial, medial: $0.parts.medial, final: $0.parts.final)) }
        let words = c.words.map { Word(text: $0.text, syllables: $0.syllables, volume: $0.volume, isIdiom: $0.isIdiom) }
        let bank = WordBank(syllables: syl, words: words, learned: [])
        try bank.validate()
        #expect(bank.words.count >= 1000)
        #expect(bank.idioms.count >= 100)
    }
}
