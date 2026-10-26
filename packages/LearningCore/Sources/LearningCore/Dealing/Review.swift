import Foundation

extension Learner {
    /// 排下次复习：到期（或还没排过）时打对，往后排一档；没到期打对不变；打错提前到第二天。熟练度不因此下降。
    mutating func scheduleReview(_ a: Attempt) {
        guard var r = records[a.spelling], r.proficiency >= .met else { return }
        let days = tuning.reviewDays
        if a.counts {
            if r.nextReview == nil || a.day >= (r.nextReview ?? 0) {
                r.reviewStep = min(r.reviewStep + 1, days.count)
                r.nextReview = a.day + days[max(0, r.reviewStep - 1)]
            }
        } else {
            r.nextReview = a.day + 1
        }
        records[a.spelling] = r
    }

    /// 这一天到期该复习的音节。
    public func due(on day: DayIndex) -> [String] {
        records.values.filter { $0.proficiency >= .met && ($0.nextReview ?? .max) <= day }.map(\.spelling).sorted()
    }
}
