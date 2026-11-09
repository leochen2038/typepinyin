import CoreText
import DuelCore
import Foundation
import LearningCore

/// 打包的只读数据：内容包、键盘尺寸表、默认调参。
@MainActor
enum AppResources {
    /// 内容包：音节、常用字、词、地区、奇遇（生成脚本产出）。
    /// 调参「课程」选「原来」时，按旧规则归卷、地区按旧顺序排（重开 App 生效）。
    static let content: LearningContent = {
        let legacy = TuningStore.load().curriculum == 0
        Volumes.legacyCurriculum = legacy
        guard let url = Bundle.main.url(forResource: "content", withExtension: "json"),
              let data = try? Data(contentsOf: url), let c = try? LearningContent.load(from: data) else {
            fatalError("content.json 缺失或格式不对")
        }
        return legacy ? c.legacyCurriculum() : c
    }()

    /// 旅程用的词表：把内容包转成比武引擎认的格式（学会哪些音节由旅程按存档给）。
    static let journeyBank: WordBank = {
        let syl = content.syllables.map {
            Syllable(spelling: $0.spelling, volume: $0.volume, isHard: $0.hardReason != nil,
                     parts: .init(initial: $0.parts.initial, medial: $0.parts.medial, final: $0.parts.final), hardReason: $0.hardReason)
        }
        let words = content.words.map { Word(text: $0.text, syllables: $0.syllables, volume: $0.volume, isIdiom: $0.isIdiom) }
        let passages = content.comparisonPassages.map { WordBank.Passage(id: $0.id, text: $0.text, syllables: $0.syllables) }
        return WordBank(syllables: syl, words: words, learned: [], comparisonPassages: passages)
    }()

    static let keyboardMetrics: KeyboardMetricsTable = {
        guard let url = Bundle.main.url(forResource: "keyboard-metrics", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let table = try? JSONDecoder().decode(KeyboardMetricsTable.self, from: data) else {
            return KeyboardMetricsTable(source: "缺省", entries: [])
        }
        return table
    }()

    static let defaultTuning: Tuning = {
        guard let url = Bundle.main.url(forResource: "Tuning.default", withExtension: "json"),
              let data = try? Data(contentsOf: url), let t = try? JSONDecoder().decode(Tuning.self, from: data) else {
            return .standard
        }
        return t
    }()

    static func registerFonts() {
        guard let url = Bundle.main.url(forResource: "ZCOOLQingKeHuangYou-Regular", withExtension: "ttf") else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }

    static var isUITest: Bool { ProcessInfo.processInfo.arguments.contains("-uiTestMode") }
}
