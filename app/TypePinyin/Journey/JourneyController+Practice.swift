import DuelCore
import Foundation
import LearningCore

/// 练功房：只出玩家打过的词（梦里、地区里打完的牌都算），不分音节、不出新的。
/// 每次进来随机一场：单挑、3 或 5 人群战、掌门（三条命）。打得不顺、常打错的词多出，练熟的少出但还会出。
extension JourneyController {
    /// 练功房里的词（打过的）。
    var practiceWords: [PracticeWord] { progress.practice.values.filter { !$0.syllables.isEmpty }.sorted { $0.lastSeen < $1.lastSeen } }

    /// 进练功房：随机排一场，先问挑战还是返回。
    func enterPractice() {
        let entered = content.regions.filter { ($0.id == "huluji" || progress.regions[$0.id] != nil) && $0.playable }
        let region = entered.randomElement() ?? content.regions[0]
        practiceRegion = region.id
        let foe = region.foes.randomElement() ?? region.boss
        let forceGroup = ProcessInfo.processInfo.arguments.contains("-practiceGroup")   // 开发用：固定 5 人群战
        switch forceGroup ? 1 : Int.random(in: 0..<3) {
        case 0:
            practiceStation = Station(kind: .duel, foe: foe, encounterId: nil, line: "\(foe.name)来练功房，抱拳道：「请指教。」")
        case 1:
            let size = forceGroup || Bool.random() ? 5 : 3
            practiceStation = Station(kind: .group, foe: region.foes.first ?? foe, encounterId: nil,
                                      line: "\(["", "", "", "三", "", "五"][size])个人一起进了练功房，领头的是\((region.foes.first ?? foe).name)。",
                                      groupSize: size)
        default:
            practiceStation = Station(kind: .boss, foe: region.boss, encounterId: nil, line: "\(region.boss.name)也来练功房，说要跟你过几招。")
        }
        practiceStage = .card
        screen = .practice
    }

    func startPracticeChallenge() {
        duelToken += 1
        practiceStage = .duel
    }

    /// 比武画面出现时：用打过的词排这一场，比重按熟练程度。
    func startPracticeDuel() {
        guard let st = practiceStation, let foe = st.foe else { return }
        let words = practiceWords
        let typical = progress.speed?.secondsPerLetter ?? 0.45
        let boss = st.kind == .boss
        planDuel(volume: nil, foe: foe, lives: boss ? 3 : 1, boss: boss, backdrop: (practiceRegion, Int.random(in: 0..<5)),
                 probeLimit: 0, group: st.kind == .group, groupTotal: st.groupSize,
                 pool: words.map(\.asContentWord), weights: PracticeWeights.weights(words, typical: typical)) { [weak self] summary, change in
            guard let self else { return }
            self.checkRankUps()
            self.duel.summaryGains = self.gains(change)
            let again: @MainActor () -> Void = { [weak self] in self?.enterPractice() }
            let back: @MainActor () -> Void = { [weak self] in self?.screen = .map }
            self.duel.summaryActions = [.init(label: "再来一场", primary: true, action: again),
                                        .init(label: "回江湖", primary: false, action: back)]
            self.autoAdvance { _ in back() }
        }
    }
}
