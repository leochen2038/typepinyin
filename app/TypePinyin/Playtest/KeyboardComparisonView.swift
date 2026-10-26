import DuelCore
import SwiftUI
import UIKit

/// 键盘对比页：看汉字打拼音（不选字），先用系统键盘、再用自带键盘，逐字母比对，结果并排显示。
struct KeyboardComparisonView: View {
    let c: DuelController
    @State private var participant = "A"
    @State private var passageIndex = 0
    @State private var stage: Stage = .ready
    @State private var system: Result?
    @State private var custom: Result?
    @State private var records = ComparisonStore.all()

    enum Stage { case ready, system, custom, done }
    struct Result { var seconds: Double; var cpm: Double; var mistakes: Int }

    private var passages: [WordBank.Passage] { AppResources.journeyBank.comparisonPassages }
    private var passage: WordBank.Passage { passages[passageIndex % max(1, passages.count)] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("试玩者代号", text: $participant).textFieldStyle(.roundedBorder).frame(width: 120)
                Picker("文字", selection: $passageIndex) {
                    ForEach(passages.indices, id: \.self) { Text("第 \($0 + 1) 段").tag($0) }
                }
            }
            Text(passage.text).font(.system(size: 20, weight: .medium)).lineSpacing(6)
            switch stage {
            case .ready:
                Button("开始：先用系统键盘") { stage = .system }.buttonStyle(.borderedProminent)
            case .system:
                Text("用系统键盘打出上面每个字的拼音，不用空格。").font(.footnote).foregroundStyle(.secondary)
                ComparisonTyping(expected: passage.syllables.joined(), useCustom: false, tuning: c.tuning) { r in
                    system = r; stage = .custom
                }
            case .custom:
                Text("再用自带键盘打一遍。").font(.footnote).foregroundStyle(.secondary)
                ComparisonTyping(expected: passage.syllables.joined(), useCustom: true, tuning: c.tuning) { r in
                    custom = r; stage = .done; save()
                }
            case .done:
                resultTable
                Button("下一位试玩者") {
                    system = nil; custom = nil; stage = .ready
                    participant = String(UnicodeScalar((participant.unicodeScalars.first?.value ?? 64) + 1).map(Character.init) ?? "A")
                }
                .buttonStyle(.borderedProminent)
            }
            if !records.isEmpty {
                Divider()
                Text("已记录 \(records.count) 条").font(.footnote).foregroundStyle(.secondary)
                ScrollView {
                    ForEach(records.reversed()) { r in
                        Text("\(r.participant) · 第\(r.passageId)段 · \(r.keyboard == .system ? "系统" : "自带") · \(Int(r.charactersPerMinute)) 字/分 · 错 \(r.mistakes)")
                            .font(.caption.monospacedDigit()).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxHeight: 140)
            }
            Spacer()
        }
        .padding()
        .navigationTitle("键盘对比")
    }

    private var resultTable: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
            GridRow { Text(""); Text("系统键盘").bold(); Text("自带键盘").bold() }
            GridRow { Text("用时"); Text(fmt(system?.seconds, "%.1f 秒")); Text(fmt(custom?.seconds, "%.1f 秒")) }
            GridRow { Text("字/分"); Text(fmt(system?.cpm, "%.0f")); Text(fmt(custom?.cpm, "%.0f")) }
            GridRow { Text("按错"); Text("\(system?.mistakes ?? 0)"); Text("\(custom?.mistakes ?? 0)") }
            if let s = system, let c = custom, s.cpm > 0 {
                GridRow {
                    Text("比值"); Text("")
                    Text(String(format: "速度 %.0f%%，按错 %.1f 倍", c.cpm / s.cpm * 100, Double(c.mistakes) / Double(max(1, s.mistakes))))
                }
            }
        }
        .monospacedDigit()
    }

    private func fmt(_ v: Double?, _ f: String) -> String { v.map { String(format: f, $0) } ?? "—" }

    private func save() {
        let pid = passage.id
        for (kb, r) in [(ComparisonRecord.Keyboard.system, system), (.custom, custom)] {
            guard let r else { continue }
            ComparisonStore.add(ComparisonRecord(participant: participant, passageId: String(pid.dropFirst()), keyboard: kb, seconds: r.seconds,
                                                 charactersPerMinute: r.cpm, mistakes: r.mistakes, date: Date()))
        }
        records = ComparisonStore.all()
    }
}

/// 一轮打字：逐字母比对，按错的字母不进入（和比武规则一致），记用时和按错次数。
struct ComparisonTyping: View {
    let expected: String
    let useCustom: Bool
    let tuning: Tuning
    let onDone: (KeyboardComparisonView.Result) -> Void
    @State private var model = TypingModel()
    @State private var systemText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(progressText).font(.system(size: 18, weight: .bold, design: .monospaced)).lineLimit(3)
            Text("按错 \(model.mistakes) 次").font(.footnote)
            if useCustom {
                CustomKeyboardHost(model: model, expected: expected, tuning: tuning, onDone: finish).frame(width: 1, height: 1)
            } else {
                TextField("在这里打", text: $systemText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: systemText) { old, new in
                        guard new.count > old.count, let ch = new.last else { return }
                        if model.type(ch, expected: expected) { finish() }
                        systemText = String(expected.prefix(model.position))
                    }
            }
        }
        .onAppear { model = TypingModel() }
    }

    private var progressText: String {
        let done = expected.prefix(model.position)
        let rest = expected.dropFirst(model.position)
        return "\(done)▌\(rest)"
    }

    private func finish() {
        let secs = max(0.01, model.elapsed)
        let chars = Double(AppResources.journeyBank.comparisonPassages.first { $0.syllables.joined() == expected }?.syllables.count ?? expected.count)
        onDone(.init(seconds: secs, cpm: chars / secs * 60, mistakes: model.mistakes))
    }
}

@MainActor
@Observable
final class TypingModel {
    var position = 0
    var mistakes = 0
    var startedAt: Double?
    var finishedAt: Double?

    var elapsed: Double { (finishedAt ?? CACurrentMediaTime()) - (startedAt ?? CACurrentMediaTime()) }

    /// 返回 true 表示打完了。
    func type(_ ch: Character, expected: String) -> Bool {
        let letters = Array(expected)
        guard position < letters.count else { return true }
        if startedAt == nil { startedAt = CACurrentMediaTime() }
        if Character(ch.lowercased()) == letters[position] { position += 1 } else { mistakes += 1 }
        if position >= letters.count { finishedAt = CACurrentMediaTime(); return true }
        return false
    }

    func expectedNext(_ expected: String) -> Set<Character> {
        let l = Array(expected)
        return position < l.count ? [l[position]] : []
    }
}

/// 自带键盘一侧：另一个隐藏焦点视图，挂同一个 KeyboardView。
struct CustomKeyboardHost: UIViewRepresentable {
    let model: TypingModel
    let expected: String
    let tuning: Tuning
    let onDone: () -> Void

    func makeUIView(context: Context) -> KeyInputHostView {
        let v = KeyInputHostView()
        v.keyboard.expectedLetters = { model.expectedNext(expected) }
        v.keyboard.tuning = { tuning }
        v.keyboard.onKey = { ev in
            guard case .letter(let ch) = ev.kind else { return }
            if ev.nearMissOf != nil { model.mistakes += 1; return }
            if model.type(ch, expected: expected) { onDone() }
        }
        return v
    }

    func updateUIView(_ uiView: KeyInputHostView, context: Context) {}
}
