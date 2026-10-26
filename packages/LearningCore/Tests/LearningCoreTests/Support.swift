import Foundation
@testable import LearningCore

/// 测试用的内容：直接读 App 里生成好的 content.json（和 App 用的是同一份）。
enum TestContent {
    static let shared: LearningContent = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("app/TypePinyin/Resources/content.json")
        return try! LearningContent.load(from: Data(contentsOf: url))
    }()

    static func fixture(_ name: String) -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")!
        return try! Data(contentsOf: url)
    }
}
