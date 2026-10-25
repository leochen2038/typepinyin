import UIKit

/// 按下时在键上方弹出放大的字母。
final class KeyPopup: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .white
        layer.borderColor = UIColor(hex: 0x111111).cgColor
        layer.borderWidth = 2.5
        layer.cornerRadius = 6
        layer.shadowColor = UIColor(hex: 0x111111).cgColor
        layer.shadowOpacity = 1
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 3, height: 3)
        label.font = .monospacedSystemFont(ofSize: 30, weight: .bold)
        label.textAlignment = .center
        label.textColor = UIColor(hex: 0x111111)
        addSubview(label)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(_ text: String, above key: CGRect) {
        let w = key.width * 1.5, h = key.height * 1.25
        frame = CGRect(x: key.midX - w / 2, y: key.minY - h - 4, width: w, height: h)
        label.frame = bounds
        label.text = text
        isHidden = false
    }

    func hide() { isHidden = true }
}
