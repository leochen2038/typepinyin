import LearningCore
import SwiftUI

/// 旅程的根视图：按 JourneyController 的当前画面切换。
struct JourneyRoot: View {
    @State var j: JourneyController

    var body: some View {
        Group {
            switch j.screen {
            case .opening(let n):
                if n == 0 && !j.openingLineShown {
                    OpeningView(line: j.content.dream?.intro ?? "江湖路远，从这里出发。", button: "接招") {
                        j.openingLineShown = true
                    }
                } else {
                    DuelScreen(c: j.duel, prepare: { j.startOpening(n) })
                        .id("opening-\(n)-\(j.duelToken)")
                }
            case .region:
                switch j.regionStage {
                case .scroll:
                    RegionView(j: j)
                case .duel:
                    DuelScreen(c: j.duel, prepare: { j.startStationDuel() })
                        .id("station-\(j.stationIndex)-\(j.duelToken)")
                case .encounter:
                    if let e = j.encounter(j.currentStation?.encounterId) {
                        TextScreen(c: j.duel,
                                   encounter: .init(id: e.id, kind: "encounter", title: e.title, intro: e.intro, source: e.source,
                                                    reply: e.reply, text: e.text, syllables: e.syllables),
                                   onFinish: { t in j.encounterDone(t) },
                                   onEncounterDone: { j.leaveEncounter() })
                            .id("enc-\(j.stationIndex)-\(j.duelToken)")
                    }
                }
            case .harvest:
                HarvestView(j: j)
            case .wake:
                OpeningView(line: j.content.dream?.outro ?? "江湖路远，从这里出发。", button: "出发") { j.screen = .map }
            case .practice:
                switch j.practiceStage {
                case .card:
                    PracticeView(j: j)
                case .duel:
                    DuelScreen(c: j.duel, prepare: { j.startPracticeDuel() })
                        .id("practice-\(j.duelToken)")
                }
            case .map:
                WorldMapView(j: j)
            case .codex:
                CodexView(j: j)
            }
        }
        .sheet(isPresented: $j.showPanel) { TuningPanelView(c: j.duel) }
        .alert("进度没读到，从头开始", isPresented: $j.showRecoveredNotice) {
            Button("好", role: .cancel) {}
        }
    }
}
