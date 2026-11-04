import LearningCore
import ProgressStore
import SwiftUI

/// 点开地区：底部弹出的简介卡。状态写未挑战 / 挑战中 / 已挑战；词卡写这里一共几张、已集几张。
struct RegionSheet: View {
    let region: Region
    let phase: RegionPhase
    let stationLine: String?
    /// 这一卷收了几张词卡、含这一卷音节的词一共几张。
    var cards = 0
    var total = 0
    let onGo: () -> Void
    let onClose: () -> Void
    /// 这一趟走到一半时的「从头开始」：丢掉这一趟的进度，从第一站重新走（秘籍、词卡、重数不受影响）。
    var onRestart: (() -> Void)? = nil
    @State private var confirmRestart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(region.name).font(Fonts.display(30))
                Text(Volumes.name(region.volume)).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.slate)
                Spacer()
                Text(stateText).font(.system(size: 13, weight: .black)).foregroundStyle(stateColor)
                Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink) }
                    .buttonStyle(.plain).accessibilityLabel("关上")
            }
            if let stationLine { Text(stationLine).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.green) }
            Text(region.scene).font(.system(size: 15)).foregroundStyle(Palette.ink)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(region.hint).font(Fonts.display(24)).foregroundStyle(Palette.red)
                Text(phase == .untouched ? "这里有 \(total) 张词卡" : "已集 \(cards) / \(total) 张词卡")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.slate)
            }
            HStack(spacing: 8) {
                ForEach(region.examples, id: \.char) { e in
                    VStack(spacing: 0) {
                        Text(e.pinyin).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.slate)
                        Text(e.char).font(Fonts.hanzi(24))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Button(action: onGo) {
                Text(buttonText).font(Fonts.display(24)).frame(maxWidth: .infinity).frame(height: 50)
                    .background(region.playable ? Palette.gold : Palette.mist2).foregroundStyle(Palette.ink)
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            }
            .buttonStyle(.plain)
            .disabled(!region.playable)
            .accessibilityIdentifier("regionGo")
            if stationLine != nil, let onRestart {
                Button { confirmRestart = true } label: {
                    Text("从头开始").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.slate)
                        .frame(maxWidth: .infinity).frame(height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("regionRestart")
                .confirmationDialog("这一趟从第一站重新走？", isPresented: $confirmRestart, titleVisibility: .visible) {
                    Button("从头开始", action: onRestart)
                    Button("接着走", role: .cancel) {}
                } message: {
                    Text("秘籍和收过的词卡都留着。")
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        .compositingGroup()
        .shadow(color: Palette.ink, radius: 0, x: 5, y: 5)
        .padding(.horizontal, 12).padding(.bottom, 16)
    }

    var stateText: String { ["未挑战", "挑战中", "已挑战"][phase == .untouched ? 0 : phase == .inProgress ? 1 : 2] }

    var stateColor: Color { phase == .inProgress ? Palette.green : phase == .cleared ? Palette.red : Palette.slate }

    var buttonText: String {
        guard region.playable else { return "还在修路" }
        if stationLine != nil { return "接着走" }              // 这一趟没走完（通关后再去一趟也一样）
        switch phase {
        case .inProgress: return "接着走"
        case .cleared: return "再去一趟"
        case .untouched: return "出发"
        }
    }
}
