import UIKit

/// 正式美术的画法规则：线宽、网点、暗面。人物和场景共用。
enum ArtStyle {
    static let ink = UIColor(hex: 0x111111)

    // 人物（人物坐标系：脚在原点，头顶约 -165）
    static let figureLine: CGFloat = 3
    static let figureDetail: CGFloat = 2
    static let figureDotSpacing: CGFloat = 4.2
    static let figureDotRadius: CGFloat = 0.85

    // 场景（点）
    static let sceneNear: CGFloat = 3
    static let sceneMid: CGFloat = 2
    static let sceneDotSpacing: CGFloat = 6
    static let sceneDotRadius: CGFloat = 1.2

    static let dotAlpha: CGFloat = 0.3
    /// 暗面：主色乘这个比例。
    static let shadeRatio: CGFloat = 0.84

    static func shade(_ c: UIColor, _ k: CGFloat = shadeRatio) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * k, green: g * k, blue: b * k, alpha: a)
    }

    /// 两个颜色按比例混合（k = 0 全是 a）。
    static func mix(_ a: UIColor, _ b: UIColor, _ k: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * k, green: g1 + (g2 - g1) * k, blue: b1 + (b2 - b1) * k, alpha: 1)
    }

    /// 在路径里铺一层 45° 的黑色网点（暗面、远山的雾）。先画一小块网点图再平铺，比一颗颗画快得多。
    static func fillDots(_ g: CGContext, path: CGPath, spacing: CGFloat, radius: CGFloat, alpha: CGFloat = dotAlpha) {
        let box = path.boundingBoxOfPath
        guard !box.isEmpty, let tile = dotTile(spacing: spacing, radius: radius, alpha: alpha) else { return }
        g.saveGState()
        g.addPath(path)
        g.clip()
        // 平铺按画布的设备像素对齐；tile 是一个 spacing × 2·step 的单元（两行，第二行错开半格）
        let step = spacing * 0.7071
        let cell = CGRect(x: floor(box.minX / spacing) * spacing, y: floor(box.minY / (2 * step)) * (2 * step),
                          width: spacing, height: 2 * step)
        g.translateBy(x: cell.minX, y: cell.minY)
        g.draw(tile, in: CGRect(origin: .zero, size: cell.size), byTiling: true)
        g.restoreGState()
    }

    nonisolated(unsafe) private static var tiles: [String: CGImage] = [:]   // 只在加锁时读写
    private static let tileLock = NSLock()

    private static func dotTile(spacing: CGFloat, radius: CGFloat, alpha: CGFloat) -> CGImage? {
        let key = "\(spacing)|\(radius)|\(alpha)"
        tileLock.lock(); defer { tileLock.unlock() }
        if let t = tiles[key] { return t }
        let step = spacing * 0.7071
        let size = CGSize(width: spacing, height: 2 * step)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(ink.withAlphaComponent(alpha).cgColor)
            // 第一行在格子左上角（四个角各四分之一），第二行在中间
            for p in [CGPoint(x: 0, y: 0), CGPoint(x: spacing, y: 0), CGPoint(x: 0, y: 2 * step), CGPoint(x: spacing, y: 2 * step),
                      CGPoint(x: spacing / 2, y: step)] {
                c.fillEllipse(in: CGRect(x: p.x - radius, y: p.y - radius, width: 2 * radius, height: 2 * radius))
            }
        }
        tiles[key] = img.cgImage
        return img.cgImage
    }
}
