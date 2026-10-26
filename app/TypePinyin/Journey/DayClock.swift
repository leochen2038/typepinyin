import Foundation
import LearningCore

/// 本机日历日（从 2026-01-01 起的天数）。调参「日子 +1」把它往后挪，用来不等真实日子就能试熟练和复习。
enum DayClock {
    private static let offsetKey = "journey.dayOffset"
    private static let origin: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 1
        return Calendar.current.date(from: c) ?? Date(timeIntervalSince1970: 1_767_225_600)
    }()

    static var offset: Int { UserDefaults.standard.integer(forKey: offsetKey) }

    static func today(_ now: Date = Date()) -> DayIndex {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: origin), to: cal.startOfDay(for: now)).day ?? 0
        return days + offset
    }

    static func advanceOneDay() { UserDefaults.standard.set(offset + 1, forKey: offsetKey) }
    static func resetOffset() { UserDefaults.standard.removeObject(forKey: offsetKey) }
}
