import Foundation

public struct KPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
}

public struct KRect: Sendable, Equatable {
    public var x: Double, y: Double, w: Double, h: Double
    public init(x: Double, y: Double, w: Double, h: Double) { self.x = x; self.y = y; self.w = w; self.h = h }
    public var maxX: Double { x + w }
    public var maxY: Double { y + h }
    public var midX: Double { x + w / 2 }
    public var midY: Double { y + h / 2 }
    public func contains(_ p: KPoint) -> Bool { p.x >= x && p.x < maxX && p.y >= y && p.y < maxY }
    public func insetBy(_ d: Double) -> KRect { KRect(x: x + d, y: y + d, w: w - 2 * d, h: h - 2 * d) }
    /// 点到矩形的距离（在矩形内为 0）。
    public func distance(to p: KPoint) -> Double {
        let dx = max(x - p.x, 0, p.x - maxX)
        let dy = max(y - p.y, 0, p.y - maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
    /// 两个矩形之间的间隙（相交为 0）。
    public func gap(to o: KRect) -> Double {
        let dx = max(o.x - maxX, x - o.maxX, 0)
        let dy = max(o.y - maxY, y - o.maxY, 0)
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// 一档屏幕宽度的系统键盘实测尺寸（keyboard-metrics.json）。
public struct KeyboardMetrics: Codable, Sendable, Equatable {
    public var screenWidth: Double
    public var keyboardHeight: Double
    public var keyWidth: Double
    public var keyHeight: Double
    public var gapX: Double
    public var gapY: Double
    public var topInset: Double
    public var row2Inset: Double
    public var functionKeyWidth: Double
    public var cornerRadius: Double?

    public init(screenWidth: Double, keyboardHeight: Double, keyWidth: Double, keyHeight: Double, gapX: Double,
                gapY: Double, topInset: Double, row2Inset: Double, functionKeyWidth: Double, cornerRadius: Double? = nil) {
        self.screenWidth = screenWidth
        self.keyboardHeight = keyboardHeight
        self.keyWidth = keyWidth
        self.keyHeight = keyHeight
        self.gapX = gapX
        self.gapY = gapY
        self.topInset = topInset
        self.row2Inset = row2Inset
        self.functionKeyWidth = functionKeyWidth
        self.cornerRadius = cornerRadius
    }

    /// 等比缩放到另一个屏幕宽度（高度方向不缩放，和系统键盘一致）。
    public func scaled(toWidth w: Double) -> KeyboardMetrics {
        let k = w / screenWidth
        var m = self
        m.screenWidth = w
        m.keyWidth *= k
        m.gapX *= k
        m.row2Inset *= k
        m.functionKeyWidth *= k
        return m
    }
}

public struct KeyboardMetricsTable: Codable, Sendable {
    public var source: String
    public var entries: [KeyboardMetrics]

    public init(source: String, entries: [KeyboardMetrics]) {
        self.source = source
        self.entries = entries
    }

    /// 取最接近的一档；宽度不同时等比缩放。
    public func metrics(forWidth w: Double) -> KeyboardMetrics {
        guard let best = entries.min(by: { abs($0.screenWidth - w) < abs($1.screenWidth - w) }) else {
            return KeyboardMetrics(screenWidth: w, keyboardHeight: 216, keyWidth: w / 10 - 6, keyHeight: 42, gapX: 6,
                                   gapY: 12, topInset: 8, row2Inset: w / 20, functionKeyWidth: w / 10 * 1.3)
        }
        return best.screenWidth == w ? best : best.scaled(toWidth: w)
    }
}

/// 键盘上的一个键。
public struct KeyCap: Sendable, Equatable {
    public enum Kind: Sendable, Hashable { case letter(Character), teach, backspace }
    public var kind: Kind
    /// 画出来的键面。
    public var face: KRect
    /// 判定区：键面 + 一半间距，边上的键延伸到键盘边缘。
    public var hit: KRect
}

/// 三排字母键盘的几何：键面、判定区、相邻关系、对预期字母的轻微放宽、「按偏了」判断。
public struct KeyGeometry: Sendable {
    public static let rows: [[Character]] = [Array("qwertyuiop"), Array("asdfghjkl"), Array("zxcvbnm")]

    public let metrics: KeyboardMetrics
    public let keys: [KeyCap]

    public init(metrics m: KeyboardMetrics) {
        self.metrics = m
        var caps: [KeyCap] = []
        let w = m.screenWidth
        func rowY(_ r: Int) -> Double { m.topInset + Double(r) * (m.keyHeight + m.gapY) }
        func hitRect(_ f: KRect, row: Int) -> KRect {
            let top = row == 0 ? 0 : f.y - m.gapY / 2
            let bottom = row == 2 ? m.keyboardHeight : f.maxY + m.gapY / 2
            return KRect(x: f.x - m.gapX / 2, y: top, w: f.w + m.gapX, h: bottom - top)
        }
        // 第一排：10 个键居中
        let row1W = 10 * m.keyWidth + 9 * m.gapX
        let left1 = (w - row1W) / 2
        for (i, c) in Self.rows[0].enumerated() {
            let f = KRect(x: left1 + Double(i) * (m.keyWidth + m.gapX), y: rowY(0), w: m.keyWidth, h: m.keyHeight)
            caps.append(KeyCap(kind: .letter(c), face: f, hit: hitRect(f, row: 0)))
        }
        // 第二排：9 个键居中
        let row2W = 9 * m.keyWidth + 8 * m.gapX
        let left2 = (w - row2W) / 2
        for (i, c) in Self.rows[1].enumerated() {
            let f = KRect(x: left2 + Double(i) * (m.keyWidth + m.gapX), y: rowY(1), w: m.keyWidth, h: m.keyHeight)
            caps.append(KeyCap(kind: .letter(c), face: f, hit: hitRect(f, row: 1)))
        }
        // 第三排：拆招 + 7 个字母居中 + 退格
        let row3W = 7 * m.keyWidth + 6 * m.gapX
        let left3 = (w - row3W) / 2
        for (i, c) in Self.rows[2].enumerated() {
            let f = KRect(x: left3 + Double(i) * (m.keyWidth + m.gapX), y: rowY(2), w: m.keyWidth, h: m.keyHeight)
            caps.append(KeyCap(kind: .letter(c), face: f, hit: hitRect(f, row: 2)))
        }
        let teach = KRect(x: left1, y: rowY(2), w: m.functionKeyWidth, h: m.keyHeight)
        let back = KRect(x: w - left1 - m.functionKeyWidth, y: rowY(2), w: m.functionKeyWidth, h: m.keyHeight)
        caps.append(KeyCap(kind: .teach, face: teach, hit: hitRect(teach, row: 2)))
        caps.append(KeyCap(kind: .backspace, face: back, hit: hitRect(back, row: 2)))
        // 每排两端的键延伸到键盘边缘
        for r in 0..<3 {
            let idx = caps.indices.filter { abs(caps[$0].face.y - rowY(r)) < 0.01 }
            if let l = idx.min(by: { caps[$0].face.x < caps[$1].face.x }) {
                caps[l].hit.w += caps[l].hit.x
                caps[l].hit.x = 0
            }
            if let rr = idx.max(by: { caps[$0].face.x < caps[$1].face.x }) {
                caps[rr].hit.w = w - caps[rr].hit.x
            }
        }
        self.keys = caps
    }

    public func cap(for c: Character) -> KeyCap? { keys.first { $0.kind == .letter(c) } }

    /// 命中测试。`expected` 里的字母判定区向外扩 `grow`（最多 6 pt），其余按原判定区。
    public func key(at p: KPoint, expected: Set<Character> = [], grow: Double = 0) -> KeyCap? {
        let g = min(6, max(0, grow))
        if g > 0 {
            for c in expected {
                if let k = cap(for: c), k.hit.insetBy(-g).contains(p) { return k }
            }
        }
        if let k = keys.first(where: { $0.hit.contains(p) }) { return k }
        return keys.min { $0.face.distance(to: p) < $1.face.distance(to: p) }
    }

    /// 两个字母键是否相邻：横向间隙不超过一个横向间距，且纵向间隙不超过一个行间距（含斜对角）。
    public func areAdjacent(_ a: Character, _ b: Character) -> Bool {
        guard a != b, let ka = cap(for: a), let kb = cap(for: b) else { return false }
        let dx = max(kb.face.x - ka.face.maxX, ka.face.x - kb.face.maxX, 0)
        let dy = max(kb.face.y - ka.face.maxY, ka.face.y - kb.face.maxY, 0)
        return dx <= metrics.gapX + 0.5 && dy <= metrics.gapY + 0.5
    }

    /// 「按偏了」：命中的字母不是预期字母，但和预期字母相邻，且触点离预期键面不超过 `maxDistance`。
    /// 预期字母有多个时（还没锁定目标），不判按偏。
    public func nearMiss(hit: Character, at p: KPoint, expected: Set<Character>, maxDistance: Double) -> Character? {
        guard expected.count == 1, let e = expected.first, e != hit, areAdjacent(hit, e),
              let ke = cap(for: e), ke.face.distance(to: p) <= maxDistance else { return nil }
        return e
    }
}
