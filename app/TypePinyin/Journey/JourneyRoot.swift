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
            case .gate:
                OpeningView(line: j.content.dream?.prologue ?? "江湖路远，从这里出发。", button: "出发", image: "peak-open", fontSize: 28) {
                    j.finishPrologue()
                }
            case .region:
                switch j.regionStage {
                case .scroll:
                    RegionView(j: j)
                case .stele:
                    if let r = j.currentRegion, let st = r.stele {
                        TextScreen(c: j.duel,
                                   encounter: .init(id: "stele-\(r.id)", kind: "encounter", title: "\(r.name)碑", intro: st.intro, source: nil,
                                                    reply: "碑上的字记下了。", text: st.text, syllables: st.syllables),
                                   onFinish: { t in j.steleDone(t) },
                                   onEncounterDone: { j.leaveStele() },
                                   onLeave: { j.steleBack() },
                                   doneLabel: j.previewingStele ? "回江湖" : "进\(r.name)",
                                   guided: j.steleGuide(r) == nil,
                                   guideSyllables: j.steleGuide(r) ?? [],
                                   resultNote: { "你已经能打出 \(j.typedCommonChars) 个常用字" },
                                   brief: j.steleBrief(r))
                            .id("stele-\(r.id)-\(j.duelToken)")
                            .accessibilityIdentifier("stele")
                    }
                case .duel:
                    DuelScreen(c: j.duel, prepare: { j.startStationDuel() })
                        .id("station-\(j.duelToken)")   // 不用站号：打赢时进度先存、站号就变了，结算还没看完比武画面不能重建
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
                case .text(let id):
                    if let e = j.encounter(id) {
                        TextScreen(c: j.duel,
                                   encounter: .init(id: e.id, kind: "encounter", title: e.title, intro: e.intro, source: e.source,
                                                    reply: e.reply, text: e.text, syllables: e.syllables),
                                   onFinish: { t in j.recordText(t) },
                                   onEncounterDone: { j.leavePracticeText() },
                                   onLeave: { j.leavePracticeText() },
                                   doneLabel: "回练习场",
                                   raceBest: true)
                            .id("ptext-\(id)-\(j.duelToken)")
                    }
                }
            case .map:
                WorldMapView(j: j)
            case .codex:
                CodexView(j: j)
            case .gathering:
                GatheringRoot(j: j)
            }
        }
        .overlay { InkCurtainHost(phase: j.inkPhase, since: j.inkSince).ignoresSafeArea() }
        .sheet(isPresented: $j.showPanel) { TuningPanelView(c: j.duel) }
        .alert("进度没读到，从头开始", isPresented: $j.showRecoveredNotice) {
            Button("好", role: .cancel) {}
        }
    }
}
