import Foundation

/// 秘籍的经验和等级（2026-11-17）：打这本秘籍的牌就涨经验，打得干净、打得快涨得多；只涨不扣，输了也涨。
/// 一张牌归哪本秘籍，看它的词归哪一关（一个词只归一关）。等级只管粒子华丽程度，不加伤害。
public enum BookXP {
    /// 打完一张牌 +1；没打错、没看提示再 +1；完美（又快又没错）再 +1；第一次收到这张词卡再 +2。
    public static func gain(clean: Bool, perfect: Bool, new: Bool) -> Int {
        1 + (clean ? 1 : 0) + (clean && perfect ? 1 : 0) + (new ? 2 : 0)
    }

    /// 升到 2、3、4、5 级要的累计经验。一趟岛大约得 400：第一趟头几场到 2 级，走完时离 3 级不远，之后大约一趟一级，五趟上下满级。
    public static let thresholds = [0, 100, 500, 1100, 2000]
    public static let maxLevel = 5

    /// 这么多经验是几级（1…5）。
    public static func level(_ xp: Int) -> Int {
        (thresholds.lastIndex { xp >= $0 } ?? 0) + 1
    }

    /// 这一级里走了多少（0…1）；满级是 1。
    public static func progress(_ xp: Int) -> Double {
        let lv = level(xp)
        guard lv < maxLevel else { return 1 }
        let lo = thresholds[lv - 1], hi = thresholds[lv]
        return min(1, max(0, Double(xp - lo) / Double(hi - lo)))
    }

    /// 旧存档（按词卡算的重数，没有经验）：按已有的等级补上那一级起步的经验，等级不掉。
    public static func seed(rank: Int) -> Int { thresholds[min(maxLevel, max(1, rank)) - 1] }
}
