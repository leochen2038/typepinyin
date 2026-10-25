import Foundation

/// 键盘对比记录：同一段文字在系统键盘和自带键盘上的用时、每分钟字数、按错次数。只存在本机。
struct ComparisonRecord: Codable, Identifiable, Equatable {
    enum Keyboard: String, Codable { case system, custom }
    var id = UUID()
    var participant: String
    var passageId: String
    var keyboard: Keyboard
    var seconds: Double
    var charactersPerMinute: Double
    var mistakes: Int
    var date: Date
}

@MainActor
enum ComparisonStore {
    private static let key = "comparison.records.v1"

    static func all() -> [ComparisonRecord] {
        guard let d = UserDefaults.standard.data(forKey: key), let r = try? JSONDecoder().decode([ComparisonRecord].self, from: d) else { return [] }
        return r
    }

    static func add(_ r: ComparisonRecord) {
        var list = all()
        list.append(r)
        if let d = try? JSONEncoder().encode(list) { UserDefaults.standard.set(d, forKey: key) }
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
