import CoreText
import DuelCore
import Foundation

/// 打包的只读数据：测试词表、键盘尺寸表、默认调参；以及本机保存的调参覆盖值。
@MainActor
enum AppResources {
    static let bank: WordBank = {
        guard let url = Bundle.main.url(forResource: "duel-words", withExtension: "json"),
              let data = try? Data(contentsOf: url), let bank = try? WordBank.load(from: data) else {
            fatalError("duel-words.json 缺失或格式不对")
        }
        return bank
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
