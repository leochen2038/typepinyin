import Foundation
import LearningCore

/// 学会了几个音节（武林大会收尾写「学会了 N 个音节」）：只报收获，不写总数、不写还差多少。
extension JourneyController {
    /// 学会的音节：碰到过就算；基本功大多数人本来就会，不算进来（和结算里「这一场学会了 N 个音节」一样）。
    var learnedSyllables: Int {
        learner.records.values.filter { $0.proficiency >= .met && content.volume(of: $0.spelling) != "base" }.count
    }
}

/// 打字速度（字/分）：记第一场和最近一场，按设备存在本机（不跟 iCloud 同步）。
enum TypingSpeedNote {
    private static let firstKey = "typingSpeed.first", lastKey = "typingSpeed.last"

    static func record(_ cpm: Double) {
        guard cpm >= 1 else { return }
        let d = UserDefaults.standard
        if d.object(forKey: firstKey) == nil { d.set(cpm, forKey: firstKey) }
        d.set(cpm, forKey: lastKey)
    }

    static var first: Double? { UserDefaults.standard.object(forKey: firstKey) as? Double }
    static var last: Double? { UserDefaults.standard.object(forKey: lastKey) as? Double }
}
