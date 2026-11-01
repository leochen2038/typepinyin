import SwiftUI

/// 岛上的景（照 HTML 草图画的，墨线平涂）：每片地区一样小东西。坐标在草图的 120 宽格子里（y 从 −24 起），
/// 画的时候往下挪 12、按岛的大小缩放。有正式美术图以后这些就不用了。
enum IslandScenery {
    enum Mark {
        case path(String, fill: Color? = nil, stroke: Color? = ink, width: CGFloat = 1.5, round: Bool = false)
        case circle(CGFloat, CGFloat, CGFloat, fill: Color, width: CGFloat = 1.3)
        case ellipse(CGFloat, CGFloat, CGFloat, CGFloat, fill: Color, stroke: Color? = ink, width: CGFloat = 1.2)
        case rect(CGFloat, CGFloat, CGFloat, CGFloat, fill: Color, stroke: Color? = ink, width: CGFloat = 1.5)
    }

    static let ink = Palette.ink
    static let wall = Color(hex: 0xE9D9B8)
    static let roof = Color(hex: 0x3A3A3A)
    static let water = Color(hex: 0x7FB3D5)
    static let wood = Color(hex: 0x5B4636)

    static let marks: [String: [Mark]] = [
        "huluji": [
            .path("M42 42 V20 M78 42 V20 M38 20 H82", width: 2.2, round: true),
        ] + [48.0, 60, 72].enumerated().flatMap { i, x -> [Mark] in
            let d = CGFloat(i % 2) * 3
            return [.path("M\(x) 20 V\(24 + d)", width: 1.2),
                    .circle(x, 27 + d, 3, fill: Color(hex: 0xE8A54B)),
                    .circle(x, 33 + d, 4.2, fill: Color(hex: 0xE8A54B))]
        },
        "baimeitai": [
            .rect(44, 34, 32, 7, fill: Color(hex: 0xE6E1D6), width: 1.6),
            .path("M60 34 Q57 26 62 20 M60 28 Q66 25 70 18 M61 24 Q55 20 52 15", stroke: wood, width: 2.2, round: true),
        ] + [(62.0, 19.0), (70, 17), (52, 14), (66, 23), (56, 21)].map { .circle($0.0, $0.1, 3, fill: .white, width: 1) },
        "yueyawan": [
            .path("M38 40 Q36 26 54 24 Q42 30 46 40 Z M46 40 Q50 32 72 34 Q86 38 80 44 Q66 40 46 40 Z", fill: water, width: 1.4),
        ] + [(56.0, 37.0), (66, 38), (74, 40)].map { .ellipse($0.0, $0.1, 3.5, 2, fill: Color(hex: 0xCFCFC8), width: 1.1) },
        "chaotoudao": [
            .path("M14 44 Q24 38 34 44 Q44 50 54 44 Q64 38 74 44 Q84 50 94 44 Q104 38 108 44 Q100 50 60 51 Q20 50 14 44 Z", fill: water, width: 1.4),
            .rect(60, 28, 16, 10, fill: wall),
            .path("M57 28 L68 20 L79 28 Z", fill: Color(hex: 0x2F5D7C)),
            .path("M36 40 L48 40 L46 43 L38 43 Z", fill: Color(hex: 0xB07A4F), width: 1.2),
            .path("M42 40 V30 L48 38 Z", fill: .white, width: 1.1),
        ],
        "banshanzhen": [
            .rect(36, 28, 18, 12, fill: wall),
            .path("M32 29 L45 20 L58 29 Z", fill: roof),
            .rect(42, 33, 5, 7, fill: ink, stroke: nil),
        ] + [(66.0, 36.0), (76, 34), (86, 38), (72, 41), (82, 43)].map { .ellipse($0.0, $0.1, 6, 4, fill: Color(hex: 0x3E7D32)) },
        "chuiliucun": [
            .path("M48 40 Q46 30 50 22", stroke: wood, width: 2.4, round: true),
            .path("M50 22 Q40 22 38 36 M50 22 Q44 24 44 38 M50 22 Q56 24 56 38 M50 22 Q60 22 62 35", stroke: Color(hex: 0x7DBB4A), width: 2, round: true),
            .ellipse(74, 38, 8, 3.5, fill: Color(hex: 0xBCB7AC), width: 1.4),
            .ellipse(74, 37, 4.5, 1.6, fill: Color(hex: 0x2A4F6B), stroke: nil),
        ],
        "changfengcheng": [
            .path("M24 41 V30 H96 V41 Z", fill: Color(hex: 0xC9C3B4), width: 1.6),
        ] + [28.0, 38, 48, 72, 82, 92].map { .rect($0 - 3, 26, 6, 4, fill: Color(hex: 0xC9C3B4), width: 1.2) } + [
            .rect(52, 22, 16, 10, fill: wall, width: 1.4),
            .path("M48 23 L60 15 L72 23 Z", fill: Palette.red),
            .path("M55 41 V35 Q60 30 65 35 V41 Z", fill: ink, stroke: nil),
        ],
        "xiaoqiaoxiang": [
            .path("M16 42 Q40 36 60 40 Q80 44 104 40 L106 46 Q60 48 14 46 Z", fill: water, width: 1.3),
            .path("M42 42 Q60 22 78 42", width: 5),
            .path("M42 42 Q60 22 78 42", stroke: wall, width: 2.4),
            .rect(80, 26, 13, 9, fill: wall, width: 1.3),
            .path("M77 27 L86.5 20 L96 27 Z", fill: roof, width: 1.3),
        ],
        "lvquanju": [
            .ellipse(66, 40, 20, 6, fill: Color(hex: 0x5FC4A3), width: 1.4),
            .path("M66 38 Q64 30 66 26 Q68 30 66 38", fill: Color(hex: 0xBFF0DF), width: 1),
            .rect(32, 28, 14, 10, fill: wall, width: 1.4),
            .path("M29 29 L39 21 L49 29 Z", fill: Color(hex: 0x2A9D8F), width: 1.4),
            .ellipse(86, 36, 5, 3.5, fill: Color(hex: 0xA3A39A)),
        ],
        "huanghuaguan": [
            .path("M24 42 L34 24 L44 42 Z M76 42 L86 22 L96 42 Z", fill: Color(hex: 0xA3A39A)),
            .rect(44, 30, 32, 12, fill: Color(hex: 0xC9C3B4)),
            .path("M55 42 V36 Q60 32 65 36 V42 Z", fill: ink, stroke: nil),
            .rect(52, 22, 16, 8, fill: wall, width: 1.4),
            .path("M48 23 L60 16 L72 23 Z", fill: roof),
        ] + [(22.0, 46.0), (30, 47), (92, 46), (100, 45), (38, 46)].map { .circle($0.0, $0.1, 1.8, fill: Color(hex: 0xF5C542), width: 0.8) },
    ]

    /// 在 Canvas 上画一片地区的景；s 是岛的缩放（草图里岛宽 120）。
    static func draw(_ id: String, in ctx: GraphicsContext, scale s: CGFloat) {
        var g = ctx
        g.translateBy(x: 0, y: 12 * s)
        g.scaleBy(x: s, y: s)
        for m in marks[id] ?? [] {
            switch m {
            case .path(let d, let fill, let stroke, let w, let round):
                let p = Path(SVGPath.parse(d))
                if let fill { g.fill(p, with: .color(fill)) }
                if let stroke { g.stroke(p, with: .color(stroke), style: StrokeStyle(lineWidth: w, lineCap: round ? .round : .butt, lineJoin: .round)) }
            case .circle(let x, let y, let r, let fill, let w):
                let p = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                g.fill(p, with: .color(fill)); g.stroke(p, with: .color(ink), lineWidth: w)
            case .ellipse(let x, let y, let rx, let ry, let fill, let stroke, let w):
                let p = Path(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2))
                g.fill(p, with: .color(fill)); if let stroke { g.stroke(p, with: .color(stroke), lineWidth: w) }
            case .rect(let x, let y, let w0, let h0, let fill, let stroke, let w):
                let p = Path(CGRect(x: x, y: y, width: w0, height: h0))
                g.fill(p, with: .color(fill)); if let stroke { g.stroke(p, with: .color(stroke), lineWidth: w) }
            }
        }
    }
}
