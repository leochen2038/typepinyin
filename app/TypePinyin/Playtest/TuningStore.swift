import DuelCore
import Foundation

/// 调参覆盖值存在本机偏好设置里，覆盖打包的默认值；可以一键恢复默认。
/// 只存和默认值不一样的那几项：没动过的项跟着默认值走，App 更新改了默认值也能生效。
@MainActor
enum TuningStore {
    private static let key = "tuning.overrides.v2"
    /// v1 把整套参数都存下来，App 改了默认值也到不了已经开过面板的手机上。
    private static let legacyKey = "tuning.overrides.v1"
    /// 从 v1 迁移时丢掉的项：这些默认值在 v1 之后改过，旧存档里的值不是玩家特意选的。
    private static let changedDefaults: Set<String> = ["movesPerDuel", "qiBar"]

    static func load() -> Tuning {
        migrate()
        let base = AppResources.defaultTuning
        guard let data = UserDefaults.standard.data(forKey: key),
              let over = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var all = fields(base) else { return base }
        // learning 一节按子字段合并：只覆盖改过的子字段，其余跟着新版本的默认值
        for (k, v) in over {
            if let sub = v as? [String: Any], var cur = all[k] as? [String: Any] {
                cur.merge(sub) { $1 }
                all[k] = cur
            } else {
                all[k] = v
            }
        }
        guard let merged = try? JSONSerialization.data(withJSONObject: all),
              let t = try? JSONDecoder().decode(Tuning.self, from: merged) else { return base }
        return t
    }

    static func save(_ t: Tuning) {
        guard let over = overrides(t),
              let data = try? JSONSerialization.data(withJSONObject: over) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func reset() -> Tuning {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        return AppResources.defaultTuning
    }

    /// 和默认值不一样的项。
    private static func overrides(_ t: Tuning) -> [String: Any]? {
        guard let cur = fields(t), let def = fields(AppResources.defaultTuning) else { return nil }
        var out: [String: Any] = [:]
        for (k, v) in cur {
            if let sub = v as? [String: Any], let dsub = def[k] as? [String: Any] {     // learning：再往下比一层
                let diff = sub.filter { sk, sv in !((dsub[sk] as AnyObject?)?.isEqual(sv) ?? false) }
                if !diff.isEmpty { out[k] = diff }
            } else if !((def[k] as AnyObject?)?.isEqual(v) ?? false) {
                out[k] = v
            }
        }
        return out
    }

    private static func fields(_ t: Tuning) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(t) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func migrate() {
        let d = UserDefaults.standard
        guard let data = d.data(forKey: legacyKey) else { return }
        d.removeObject(forKey: legacyKey)
        guard d.data(forKey: key) == nil, let old = try? JSONDecoder().decode(Tuning.self, from: data),
              var over = overrides(old) else { return }
        for k in changedDefaults { over.removeValue(forKey: k) }
        if let v2 = try? JSONSerialization.data(withJSONObject: over) { d.set(v2, forKey: key) }
    }
}
