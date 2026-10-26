import Foundation
import SwiftData

// 存档模型。为以后接用户自己的 iCloud 准备：所有属性可选或有默认值、没有唯一约束、没有必填的关系。
// 每台设备只写自己的记录（deviceId），读的时候把各设备的记录合起来。

@Model final class DeviceSyllable {
    var deviceId: String = ""
    var spelling: String = ""
    var proficiency: Int = 0
    var correct: Int = 0
    var wrong: Int = 0
    var recentData: Data?
    var correctDaysData: Data?
    var lastSeen: Double?
    var reviewStep: Int = 0
    var nextReview: Int?

    init(deviceId: String, spelling: String) {
        self.deviceId = deviceId
        self.spelling = spelling
    }
}

@Model final class DeviceVolume {
    var deviceId: String = ""
    var volume: String = ""
    var obtained: Bool = false
    var rank: Int = 0

    init(deviceId: String, volume: String) {
        self.deviceId = deviceId
        self.volume = volume
    }
}

@Model final class DeviceRegion {
    var deviceId: String = ""
    var regionId: String = ""
    var phase: String = "untouched"
    var stationIndex: Int = 0
    var routeData: Data?

    init(deviceId: String, regionId: String) {
        self.deviceId = deviceId
        self.regionId = regionId
    }
}

@Model final class DeviceJourney {
    var deviceId: String = ""
    var openingDone: Bool = false
    var openingBattle: Int = 0
    var tipsSeenData: Data?
    var fogCleared: Bool = false
    var probeData: Data?
    var newToday: Int = 0
    var newTodayDay: Int = 0
    var updatedAt: Date = Date.distantPast

    init(deviceId: String) { self.deviceId = deviceId }
}

@Model final class DeviceSpeed {
    var deviceId: String = ""
    var secondsPerLetter: Double = 0
    var startSeconds: Double = 0
    var samples: Int = 0
    var updatedAt: Date = Date.distantPast

    init(deviceId: String) { self.deviceId = deviceId }
}
