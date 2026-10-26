import Foundation

/// 秘籍页上一个音节的「下一步」：做到什么就升一级（往前一步的说法）。
public struct NextStep: Equatable, Sendable {
    public var text: String
}

extension Learner {
    public func nextStep(for s: String) -> NextStep? {
        let r = record(of: s)
        switch r.proficiency {
        case .locked: return NextStep(text: "打对一次就解锁")
        case .met:
            if r.correctDays.count < tuning.fluentDays { return NextStep(text: "隔一天再打对一次，就熟练了") }
            return NextStep(text: "再连着打对几次、上手快一点，就熟练了")
        case .fluent: return NextStep(text: "再连着打对几次、打得更快，就精通了")
        case .master: return nil
        }
    }
}
