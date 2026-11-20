import LearningCore
import ProgressStore
import SwiftUI

/// 点开地区：底部弹出的简介卡。和碑文页的「这一关」用同一套说法：练什么（hint + 一句白话）、几个新音节、几张词卡；
/// 秘籍按岛名叫（「葫芦集秘籍 · 2 级」，没拿到写怎么拿）。状态写未挑战 / 挑战中 / 已打通。
struct RegionSheet: View {
    let region: Region
    let phase: RegionPhase
    let stationLine: String?
    /// 秘籍那一行（「葫芦集秘籍 · 2 级」/「进岛打完碑文，就拿到葫芦集秘籍」）。
    var bookLine = ""
    /// 这一关的新音节有几个（第一座岛不写「新」）。
    var syllables = 0
    var firstRegion = false
    /// 这一卷收了几张词卡、含这一卷音节的词一共几张。
    var cards = 0
    var total = 0
    let onGo: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(region.name).font(Fonts.display(30))
                Spacer()
                Text(stateText).font(.system(size: 13, weight: .black)).foregroundStyle(stateColor)
                Button(action: onClose) { Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.ink) }
                    .buttonStyle(.plain).accessibilityLabel("关上")
            }
            // 秘籍和数字放在岛名下面一起看：先知道这座岛有多少东西，再往下看练什么
            VStack(alignment: .leading, spacing: 2) {
                if !bookLine.isEmpty {
                    Text(bookLine).font(.system(size: 14, weight: .black)).foregroundStyle(Palette.slate)
                }
                Text(factsLine).font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.slate)
            }
            if let stationLine { Text(stationLine).font(.system(size: 14, weight: .bold)).foregroundStyle(Palette.green) }
            Text(region.scene).font(.system(size: 15)).foregroundStyle(Palette.ink)
            practice
            Button(action: onGo) {
                Text(buttonText).font(Fonts.display(24)).frame(maxWidth: .infinity).frame(height: 50)
                    .background(region.playable ? Palette.gold : Palette.mist2).foregroundStyle(Palette.ink)
                    .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
            }
            .buttonStyle(.pop)
            .disabled(!region.playable)
            .accessibilityIdentifier("regionGo")
        }
        .padding(18)
        .background(Color.white)
        .overlay(Rectangle().stroke(Palette.ink, lineWidth: 3))
        .compositingGroup()
        .shadow(color: Palette.ink, radius: 0, x: 5, y: 5)
        .padding(.horizontal, 12).padding(.bottom, 16)
    }

    /// 练什么：大字写这一关的韵母（红色），下面一句说明（内容包里的 summary）；书面语，不说「容易混」，不放格子、不出汉字。
    private var practice: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("这一关练").font(.system(size: 13, weight: .black)).foregroundStyle(Palette.slate)   // 和碑文页同一个标签
            Text(region.hint).font(Fonts.display(26)).foregroundStyle(Palette.red)
            Text(region.summary ?? region.difficulty).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.slate)
                .fixedSize(horizontal: false, vertical: true)
        }
    }


    /// 「75 个音节 · 1187 张词卡」；去过以后词卡写已集几张。
    var factsLine: String {
        let syl = "\(syllables) 个\(firstRegion ? "" : "新")音节"
        let card = phase == .untouched ? "\(total) 张词卡" : "词卡已集 \(cards) / \(total)"
        return syllables > 0 ? "\(syl) · \(card)" : card
    }

    var stateText: String { ["未挑战", "挑战中", "已打通"][phase == .untouched ? 0 : phase == .inProgress ? 1 : 2] }

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
