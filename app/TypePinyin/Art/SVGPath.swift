import CoreGraphics
import Foundation

/// 把 SVG 路径字符串（M L H V Q C A Z，绝对和相对坐标）转成 CGPath。
/// 人物的矢量部件用 SVG 路径写成。
enum SVGPath {
    static func parse(_ d: String) -> CGPath {
        let path = CGMutablePath()
        var tokens = tokenize(d)
        var cmd: Character = "M"
        var cur = CGPoint.zero
        var start = CGPoint.zero
        var i = 0
        func num() -> CGFloat {
            defer { i += 1 }
            if case .number(let v) = tokens[i] { return CGFloat(v) }
            return 0
        }
        while i < tokens.count {
            if case .command(let c) = tokens[i] { cmd = c; i += 1 }
            let rel = cmd.isLowercase
            let base = rel ? cur : .zero
            switch Character(cmd.uppercased()) {
            case "M":
                let p = CGPoint(x: base.x + num(), y: base.y + num())
                path.move(to: p); cur = p; start = p
                cmd = rel ? "l" : "L"
            case "L":
                let p = CGPoint(x: base.x + num(), y: base.y + num())
                path.addLine(to: p); cur = p
            case "H":
                let x = (rel ? cur.x : 0) + num()
                cur = CGPoint(x: x, y: cur.y); path.addLine(to: cur)
            case "V":
                let y = (rel ? cur.y : 0) + num()
                cur = CGPoint(x: cur.x, y: y); path.addLine(to: cur)
            case "Q":
                let c = CGPoint(x: base.x + num(), y: base.y + num())
                let p = CGPoint(x: base.x + num(), y: base.y + num())
                path.addQuadCurve(to: p, control: c); cur = p
            case "C":
                let c1 = CGPoint(x: base.x + num(), y: base.y + num())
                let c2 = CGPoint(x: base.x + num(), y: base.y + num())
                let p = CGPoint(x: base.x + num(), y: base.y + num())
                path.addCurve(to: p, control1: c1, control2: c2); cur = p
            case "A":
                let rx = num(), ry = num(), rot = num(), large = num() != 0, sweep = num() != 0
                let p = CGPoint(x: base.x + num(), y: base.y + num())
                addArc(path, from: cur, to: p, rx: rx, ry: ry, rotation: rot, large: large, sweep: sweep)
                cur = p
            case "Z":
                path.closeSubpath(); cur = start
                continue
            default:
                i += 1
                continue
            }
        }
        tokens.removeAll()
        return path
    }

    private enum Token { case command(Character), number(Double) }

    private static func tokenize(_ d: String) -> [Token] {
        var out: [Token] = []
        var numBuf = ""
        func flush() {
            if !numBuf.isEmpty, let v = Double(numBuf) { out.append(.number(v)) }
            numBuf = ""
        }
        for ch in d {
            if ch.isLetter && ch != "e" && ch != "E" {
                flush(); out.append(.command(ch))
            } else if ch == "-" {
                if let last = numBuf.last, last == "e" || last == "E" { numBuf.append(ch) } else { flush(); numBuf.append(ch) }
            } else if ch == "," || ch == " " || ch == "\n" || ch == "\t" {
                flush()
            } else if ch == "." && numBuf.contains(".") && !numBuf.contains("e") {
                flush(); numBuf.append(ch)
            } else {
                numBuf.append(ch)
            }
        }
        flush()
        return out
    }

    /// SVG 端点式圆弧 → 用三次贝塞尔近似（W3C 附录 F.6）。
    private static func addArc(_ path: CGMutablePath, from p0: CGPoint, to p1: CGPoint, rx rx0: CGFloat, ry ry0: CGFloat,
                               rotation: CGFloat, large: Bool, sweep: Bool) {
        var rx = abs(rx0), ry = abs(ry0)
        if rx == 0 || ry == 0 { path.addLine(to: p1); return }
        let phi = rotation * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
        let x1 = cosP * dx + sinP * dy
        let y1 = -sinP * dx + cosP * dy
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        var coef = sqrt(max(0, num / den))
        if large == sweep { coef = -coef }
        let cxp = coef * rx * y1 / ry
        let cyp = -coef * ry * x1 / rx
        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let a = atan2(ux * vy - uy * vx, ux * vx + uy * vy)
            return a
        }
        let theta1 = angle(1, 0, (x1 - cxp) / rx, (y1 - cyp) / ry)
        var dTheta = angle((x1 - cxp) / rx, (y1 - cyp) / ry, (-x1 - cxp) / rx, (-y1 - cyp) / ry)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        if sweep && dTheta < 0 { dTheta += 2 * .pi }
        let segments = Int(ceil(abs(dTheta) / (.pi / 2)))
        let delta = dTheta / CGFloat(segments)
        let t = 4.0 / 3.0 * tan(delta / 4)
        var th = theta1
        for _ in 0..<segments {
            let c1 = CGPoint(x: cos(th) - t * sin(th), y: sin(th) + t * cos(th))
            let e = CGPoint(x: cos(th + delta), y: sin(th + delta))
            let c2 = CGPoint(x: e.x + t * sin(th + delta), y: e.y - t * cos(th + delta))
            func map(_ p: CGPoint) -> CGPoint {
                CGPoint(x: cx + rx * (cosP * p.x) - ry * (sinP * p.y), y: cy + rx * (sinP * p.x) + ry * (cosP * p.y))
            }
            path.addCurve(to: map(e), control1: map(c1), control2: map(c2))
            th += delta
        }
    }
}
