import Testing
@testable import LearningCore

/// 每一卷的地区里出牌够不够：十卷各模拟 20 场，看本卷字的占比、一场里的重复、掌门的长牌、必杀牌。
@Suite struct VolumeDealTests {
    let c = TestContent.shared
    static let regionVolumes = ["liangzi-shang", "liangzi-xia", "biyin-shang", "biyin-xia", "yw", "shengzi", "lv", "sanpin-shang", "sanpin-xia"]
    static let road: [Int: Double] = [2: 0.85, 3: 0.15]
    static let boss: [Int: Double] = [3: 0.4, 4: 0.35, 5: 0.25]

    /// 会《基本功》，再加这一卷的一部分音节（按常用字多少排，前 share 那么多）；dueBase：《基本功》都到了该复习的时候。
    func learner(knowing v: String, share: Double, dueBase: Bool = false) -> Learner {
        var l = Learner()
        let inVol = c.syllables(in: v).sorted { c.commonChars(of: $0.spelling).count > c.commonChars(of: $1.spelling).count }
        let known = c.syllables(in: "base") + inVol.prefix(Int(Double(inVol.count) * share))
        for s in known {
            var r = SyllableRecord(spelling: s.spelling)
            r.proficiency = .fluent
            r.correct = 3
            if dueBase && s.volume == "base" { r.nextReview = 1 }
            l.records[s.spelling] = r
        }
        return l
    }

    struct Stats { var inVol = 0; var byVolumeReason = 0; var total = 0; var maxRepeat = 0; var long = 0 }

    /// 模拟 duels 场，每场 cards 张。
    func run(_ v: String, _ l: Learner, lengths: [Int: Double], duels: Int = 20, cards: Int = 20) -> Stats {
        let inVol = Set(c.syllables(in: v).map(\.spelling))
        var st = Stats()
        for seed in 1...UInt64(duels) {
            let d = Dealer(content: c, learner: l, context: DealContext(volume: v, today: 5, lengths: lengths), seed: seed)
            var seen: [String: Int] = [:]
            for _ in 0..<cards {
                let w = d.next()
                st.total += 1
                if w.word.syllables.contains(where: inVol.contains) { st.inVol += 1 }
                if w.reason == .knownInVolume || w.reason == .newInVolume { st.byVolumeReason += 1 }
                if w.word.text.count >= 3 { st.long += 1 }
                seen[w.word.text, default: 0] += 1
                d.note(w.word, clean: true)
            }
            st.maxRepeat = max(st.maxRepeat, seen.values.max() ?? 0)
        }
        return st
    }

    /// 这一卷会了一半、有要复习的：按出牌理由算，本卷（已会 + 没会）占五到七成，一场里同一个词不超过两次。
    /// 没有要复习的时候，复习那一份分给其他几类，本卷会到八成多（出牌规则如此，见 Dealer.dealInRegion）。
    @Test(arguments: regionVolumes) func roadShareAndRepeats(_ v: String) {
        let st = run(v, learner(knowing: v, share: 0.5, dueBase: true), lengths: Self.road)
        let share = Double(st.byVolumeReason) / Double(st.total)
        #expect(share >= 0.5 && share <= 0.7, "\(v) 本卷占比 \(share)")
        #expect(st.maxRepeat <= 2, "\(v) 一场里同一个词出了 \(st.maxRepeat) 次")
    }

    /// 刚进这一卷（一个都还没会）：照样出得来牌，不卡住，也不重复。
    @Test(arguments: regionVolumes) func freshVolumeStillDeals(_ v: String) {
        let st = run(v, learner(knowing: v, share: 0), lengths: Self.road)
        #expect(st.total == 400)
        #expect(st.inVol > 0, "\(v) 刚进来一个本卷的字都没出")
        #expect(st.maxRepeat <= 2, "\(v) 一场里同一个词出了 \(st.maxRepeat) 次")
    }

    /// 掌门站：三字以上的牌至少三成半，本卷字至少两成半。
    /// 2026-11-01 实测：yw、两字诀下、鼻音掌上、省字诀过半；两字诀上、鼻音掌下、ü 步、三拼在 37%–49%
    /// （长词要每个音节都会才出，会一半时凑得出的少）。规则先不改，这里先守住下限，要不要调交给产品负责人。
    @Test(arguments: regionVolumes) func bossDealsLongOnes(_ v: String) {
        let st = run(v, learner(knowing: v, share: 0.5), lengths: Self.boss, cards: 12)
        let long = Double(st.long) / Double(st.total)
        #expect(long >= 0.35, "\(v) 掌门长牌只占 \(long)")
        #expect(Double(st.inVol) / Double(st.total) >= 0.25, "\(v) 掌门站本卷字太少")
    }

    /// 气满时总有必杀牌（成语，或最长的词）。
    @Test(arguments: regionVolumes) func finisherAlwaysThere(_ v: String) {
        let d = Dealer(content: c, learner: learner(knowing: v, share: 0.5), context: DealContext(volume: v, today: 5), seed: 3)
        for _ in 0..<10 { #expect(d.nextIdiom().text.count >= 4) }
    }
}
