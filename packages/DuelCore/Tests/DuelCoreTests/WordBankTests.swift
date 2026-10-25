import Foundation
import Testing
@testable import DuelCore

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

    /// 打包进 App 的正式词表也要通过校验。
    @Test func bundledAppWordListIsValid() throws {
        let here = URL(fileURLWithPath: #filePath)
        let url = here.deletingLastPathComponent().appendingPathComponent("../../../../app/TypePinyin/Resources/duel-words.json").standardized
        let bank = try WordBank.load(from: Data(contentsOf: url))
        #expect(bank.words.count >= 50)
        #expect(bank.idioms.count >= 6)
        for s in bank.learned { #expect(bank.syllableTable[s] != nil) }
    }
}
