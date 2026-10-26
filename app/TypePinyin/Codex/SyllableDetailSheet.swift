import LearningCore
import SwiftUI

/// 点开一格：会一个音节，就会了一群字。列出常用字、现在是哪一级、下一步、最快一次的上手时间。
struct SyllableDetailSheet: View {
    @State var j: JourneyController
    let spelling: String

    var body: some View {
        let p = j.learner.proficiency(spelling)
        let r = j.learner.record(of: spelling)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(p == .locked ? "未解锁的招式" : spelling).font(Fonts.display(34))
                Text(CodexView.name(p)).font(.system(size: 14, weight: .black)).foregroundStyle(p == .master ? .white : Palette.ink)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(CodexView.fill(p))
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 1))
                Spacer()
                Text(Volumes.name(j.content.volume(of: spelling))).font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.slate)
            }
            if p == .locked {
                Text("拼法是 \(spelling)。在江湖里碰到它，打对一次就解锁。").font(.system(size: 16, weight: .semibold))
            }
            Text("会了 \(spelling)，就能打出这些常用字：").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.slate)
            Text(String(j.content.commonChars(of: spelling).prefix(30)))
                .font(Fonts.hanzi(26)).lineSpacing(4)
            if let step = j.learner.nextStep(for: spelling) {
                Text("下一步：\(step.text)").font(.system(size: 16, weight: .bold)).foregroundStyle(Palette.green)
            }
            if let f = r.fastestStart {
                Text(String(format: "最快一次上手 %.1f 秒", f)).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.slate)
            }
            Spacer()
        }
        .padding(20)
    }
}
