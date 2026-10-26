import DuelCore
import SwiftUI

/// 隐藏的调参面板：所有比武数值都能改，下一场生效（键盘相关的立即生效），重启后保留。
struct TuningPanelView: View {
    let c: DuelController
    @State private var confirmReset = false
    @State private var dayTick = 0
    @State private var t: Tuning
    @Environment(\.dismiss) private var dismiss

    init(c: DuelController) {
        self.c = c
        _t = State(initialValue: c.tuning)
    }

    private struct D { let label: String; let kp: WritableKeyPath<Tuning, Double>; let step: Double; let range: ClosedRange<Double> }
    private struct I { let label: String; let kp: WritableKeyPath<Tuning, Int>; let range: ClosedRange<Int> }
    private struct B { let label: String; let kp: WritableKeyPath<Tuning, Bool> }

    private let keyboard: [D] = [
        D(label: "预期字母放宽（pt）", kp: \.expectedKeyGrowPt, step: 0.5, range: 0...6),
        D(label: "按偏判定距离（pt）", kp: \.nearMissMaxPt, step: 1, range: 0...16),
    ]
    private let combo: [D] = [
        D(label: "连招窗口初始（秒）", kp: \.comboWindowInitial, step: 0.1, range: 0.5...6),
        D(label: "连招窗口下限（秒）", kp: \.comboWindowMin, step: 0.1, range: 0.3...3),
        D(label: "每连一招加成", kp: \.comboBonusPerHit, step: 0.01, range: 0...0.3),
    ]
    private let incoming: [D] = [
        D(label: "出招间隔（秒）", kp: \.attackInterval, step: 0.5, range: 1...15),
        D(label: "间隔浮动比例", kp: \.attackIntervalJitter, step: 0.05, range: 0...0.8),
        D(label: "蓄力：每字母系数", kp: \.chargePerLetterFactor, step: 0.1, range: 0.5...5),
        D(label: "蓄力：基础（秒）", kp: \.chargeBaseSeconds, step: 0.1, range: 0...3),
        D(label: "蓄力：最短（秒）", kp: \.chargeMinSeconds, step: 0.1, range: 1...6),
        D(label: "弹反时间比例", kp: \.parryFraction, step: 0.05, range: 0.1...0.9),
        D(label: "晕眩（秒）", kp: \.stunSeconds, step: 0.1, range: 0...5),
        D(label: "晕眩伤害倍数", kp: \.stunDamageMultiplier, step: 0.1, range: 1...3),
    ]
    private let damage: [D] = [
        D(label: "一场目标时长（秒）", kp: \.duelTargetSeconds, step: 5, range: 20...200),
        D(label: "每重伤害加成", kp: \.rankBonusPerLevel, step: 0.05, range: 0...0.5),
        D(label: "蓄势每秒", kp: \.storeGainPerSecond, step: 0.01, range: 0...0.3),
        D(label: "蓄势上限", kp: \.storeMax, step: 0.1, range: 1...4),
        D(label: "破绽倍数", kp: \.flawMultiplier, step: 0.1, range: 1...3),
        D(label: "必杀基础伤害（打掉比例为 0 时用）", kp: \.finisherBase, step: 5, range: 10...150),
        D(label: "必杀打掉对手血量的比例（0 = 旧算法）", kp: \.finisherShare, step: 0.05, range: 0...0.6),
        D(label: "卡壳提示：卡住几秒（0 = 关）", kp: \.hintSeconds, step: 0.5, range: 0...10),
        D(label: "金色：每字母不超过（秒）", kp: \.goldSecondsPerLetter, step: 0.05, range: 0.2...2),
        D(label: "对手蓄力：每字母倍数", kp: \.pressureFactor, step: 0.1, range: 1...6),
        D(label: "对手蓄力：基础秒数", kp: \.pressureBaseSeconds, step: 0.5, range: 0...6),
        D(label: "对手蓄力：最短秒数", kp: \.pressureMinSeconds, step: 0.5, range: 1...10),
    ]
    private let learnD: [D] = [
        D(label: "第一次就熟练：上手不到（秒）", kp: \.learning.firstFluentStart, step: 0.1, range: 0.3...3),
        D(label: "熟练：上手不到（秒）", kp: \.learning.fluentStart, step: 0.1, range: 0.5...5),
        D(label: "精通：上手不到（秒）", kp: \.learning.masterStart, step: 0.05, range: 0.3...2),
        D(label: "出字：本卷已会", kp: \.learning.mixKnown, step: 0.05, range: 0...1),
        D(label: "出字：本卷没会", kp: \.learning.mixNew, step: 0.05, range: 0...1),
        D(label: "出字：复习", kp: \.learning.mixReview, step: 0.05, range: 0...1),
        D(label: "出字：垫底", kp: \.learning.mixFiller, step: 0.05, range: 0...1),
        D(label: "打对率目标", kp: \.learning.successTarget, step: 0.05, range: 0.5...1),
        D(label: "手速滑动权重", kp: \.learning.speedWeight, step: 0.05, range: 0.05...1),
        D(label: "初入江湖每场目标（秒）", kp: \.learning.openingTargetSeconds, step: 5, range: 15...120),
    ]
    private let learnI: [I] = [
        I(label: "熟练要几个不同的日子", kp: \.learning.fluentDays, range: 1...5),
        I(label: "熟练看最近几次", kp: \.learning.fluentRecent, range: 1...10),
        I(label: "精通看最近几次", kp: \.learning.masterRecent, range: 1...10),
        I(label: "每场最多几个新音节", kp: \.learning.newPerDuel, range: 0...8),
        I(label: "新音节后至少隔几张", kp: \.learning.newGap, range: 0...5),
        I(label: "每天最多新学几个", kp: \.learning.newPerDay, range: 0...30),
        I(label: "刚错过后几张出会的", kp: \.learning.afterMissKnown, range: 0...5),
        I(label: "最近几个词不重复", kp: \.learning.recentWords, range: 0...40),
        I(label: "摸底探几族", kp: \.learning.probeFamilies, range: 0...6),
        I(label: "摸底每族探几个", kp: \.learning.probePerFamily, range: 1...8),
        I(label: "初入江湖几场", kp: \.learning.openingBattles, range: 1...5),
    ]
    private let ints: [I] = [
        I(label: "被来招打中掉血", kp: \.incomingDamage, range: 0...50),
        I(label: "已学会的打错掉血", kp: \.mistakeDamage, range: 0...20),
        I(label: "玩家血量", kp: \.playerMaxHP, range: 20...300),
        I(label: "破绽多攒气", kp: \.flawQiBonus, range: 0...50),
        I(label: "完美多攒气", kp: \.perfectQi, range: 0...30),
        I(label: "弹反攒气", kp: \.qiParry, range: 0...60),
        I(label: "格挡攒气", kp: \.qiBlock, range: 0...60),
        I(label: "重招字母数", kp: \.heavyLetters, range: 6...20),
        I(label: "中招字母数", kp: \.mediumLetters, range: 4...12),
        I(label: "连招变金色", kp: \.comboGoldAt, range: 2...50),
        I(label: "连招变红色", kp: \.comboRedAt, range: 3...80),
        I(label: "一场几招（0 = 按血量）", kp: \.movesPerDuel, range: 0...30),
        I(label: "场上词牌数（1 = 一张牌加对手蓄力）", kp: \.cardsOnTable, range: 1...3),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("数据") {
                    LabeledContent("按键延迟 平均", value: String(format: "%.0f 毫秒", c.latency.averageMs))
                    LabeledContent("按键延迟 最慢", value: String(format: "%.0f 毫秒", c.latency.worstMs))
                    LabeledContent("样本数", value: "\(c.latency.samples.count)（最近 50 次）")
                    LabeledContent("帧率", value: String(format: "%.0f", c.latency.fps))
                    Button("清空延迟样本") { c.latency.reset() }
                }
                Section {
                    Picker("模式", selection: $t.textMode) {
                        Text("旅程").tag(3)
                        Text("比武").tag(0)
                        Text("短句（奇遇 · 题壁诗）").tag(1)
                        Text("文章（下一篇）").tag(2)
                    }
                    .pickerStyle(.menu)
                    Picker("文字的动效", selection: $t.textStyle) {
                        Text("战斗动效（无回顾）").tag(2)
                        Text("战斗动效 + 回顾").tag(1)
                        Text("简版（半秒快爆）").tag(0)
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("打什么（试玩）")
                } footer: {
                    Text("短句和文章都是一句一张牌，只是上面不一样：短句是故事，文章是和之前的你赛跑。")
                }
                Section("键盘（立即生效）") {
                    Picker("出字时机", selection: $t.commitOnRelease) {
                        Text("抬起出字").tag(true)
                        Text("按下出字").tag(false)
                    }
                    .pickerStyle(.menu)
                    Toggle("按键震动", isOn: $t.hapticsOnKey)
                    Toggle("左右手提示（分界虚线、卡壳时亮一侧）", isOn: $t.handZones)
                    Picker("取字演出", selection: $t.grabStyle) {
                        Text("剑气").tag(0)
                        Text("绳镖").tag(1)
                    }
                    .pickerStyle(.menu)
                    Picker("取字节奏", selection: $t.grabMode) {
                        Text("每个字母一次").tag(0)
                        Text("一个音节一次").tag(1)
                    }
                    .pickerStyle(.menu)
                    Picker("长词每刀最短间隔", selection: $t.slashMinGap) {
                        Text("0.06 秒（更密）").tag(0.06)
                        Text("0.075 秒").tag(0.075)
                    }
                    .pickerStyle(.menu)
                    ForEach(keyboard, id: \.label) { row($0) }
                    NavigationLink("键盘对比") { KeyboardComparisonView(c: c) }
                }
                Section("画面") {
                    Toggle("每招的小圆点（状态栏下面，最近 10 招）", isOn: $t.moveDots)
                }
                Section {
                    Picker("试看重数", selection: $t.rankFx) {
                        Text("关（默认彩纸）").tag(-1)
                        ForEach(0...5, id: \.self) { Text(["零重", "一重", "二重", "三重", "四重", "五重"][$0]).tag($0) }
                    }
                    .pickerStyle(.menu)
                    Picker("主题", selection: $t.rankFxTheme) {
                        Text("按字所属的卷").tag("")
                        ForEach(RankFx.order, id: \.self) { Text(RankFx.theme($0).name).tag($0) }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("秘籍重数的爆字母（试看）")
                } footer: {
                    Text("一重换成这一卷的主题粒子，迸得少；二重多一些；三重最多；四重再往上冲；五重冲得更猛、散得更开。打字时打完一个字也迸主题粒子。")
                }
                Section("声音") {
                    Toggle("音乐", isOn: Binding(get: { c.music.on }, set: { c.music.on = $0 }))
                    Toggle("音效", isOn: Binding(get: { c.sounds.soundOn }, set: { c.sounds.soundOn = $0 }))
                }
                Section {
                    Toggle("群战", isOn: $t.groupFight)
                    Stepper("场上最多几个人：\(t.groupSize)", value: $t.groupSize, in: 1...3)
                    Stepper("一共几个人：\(t.groupTotal)", value: $t.groupTotal, in: 2...9)
                } header: {
                    Text("群战（试玩，下一场生效）")
                } footer: {
                    Text("打完一张牌自动打蓄力最多的那个并打断它的蓄力，必杀打全场；倒下一个补一个，最后一个是头目。")
                }
                Section {
                    Picker("对手有几条命", selection: $t.foeLives) {
                        Text("1 条").tag(1)
                        Text("3 条（掌门）").tag(3)
                        Text("5 条（最终 Boss）").tag(5)
                    }
                    .pickerStyle(.menu)
                    Toggle("必杀命中直接扣一条命", isOn: $t.finisherTakesLife)
                    Stepper(String(format: "每丢一条命蓄力快：%.0f%%", t.lifeSpeedup * 100), value: $t.lifeSpeedup, in: 0...0.3, step: 0.05)
                    Toggle("掌门蓄力打不断（3 条命以上）", isOn: $t.bossPressure)
                    Stepper(String(format: "打完一张牌推回：%.0f%%", t.bossPushBack * 100), value: $t.bossPushBack, in: 0...0.5, step: 0.05)
                    Stepper(String(format: "掌门一轮蓄力：%.1f 张牌的时间", t.bossCycleCards), value: $t.bossCycleCards, in: 1.5...6, step: 0.5)
                    Stepper("掌门打一下掉血：\(t.bossHit)", value: $t.bossHit, in: 2...20)
                } header: {
                    Text("命数（试玩，下一场生效）")
                } footer: {
                    Text("打空一条血，对手跪地一下再站起来，血条换个颜色满上；血条下面一块一块的是还剩的命。整场的血平分到每条命上。群战里不用命数。掌门蓄力打不断：打完一张牌不重来，只往回推一截（0 = 完全推不动），必杀才打断；演回顾、跪地时停住。")
                }
                Section("旧玩法") {
                    Toggle("玩家气条（攒满出成语必杀牌）", isOn: $t.qiBar)
                }
                Section {
                    Button("日子 +1（现在偏移 \(DayClock.offset) 天）") { DayClock.advanceOneDay(); dayTick += 1 }
                    Toggle("跳过旅程动画", isOn: Binding(get: { JourneyFlags.fast }, set: { JourneyFlags.fast = $0 }))
                    Button("清空进度", role: .destructive) { confirmReset = true }
                } header: {
                    Text("旅程（试玩）")
                } footer: {
                    Text("清空进度会删掉这台手机上的全部旅程进度（学会的音节、秘籍、走到哪），下次打开从初入江湖开始，用来换人试玩。日子 +1 用来试熟练、复习和每天新学的上限。")
                }
                .id(dayTick)
                .confirmationDialog("清空这台手机上的全部旅程进度？", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("清空", role: .destructive) { c.journey?.resetProgress(); dismiss() }
                }
                Section("连招") { ForEach(combo, id: \.label) { row($0) } }
                Section("来招") { ForEach(incoming, id: \.label) { row($0) } }
                Section("伤害、蓄势") { ForEach(damage, id: \.label) { row($0) } }
                Section {
                    ForEach(learnD, id: \.label) { row($0) }
                    ForEach(learnI, id: \.label) { f in
                        Stepper("\(f.label)：\(t[keyPath: f.kp])", value: Binding(get: { t[keyPath: f.kp] }, set: { t[keyPath: f.kp] = $0 }), in: f.range)
                    }
                } header: {
                    Text("学习（旅程里生效）")
                } footer: {
                    Text("熟练度门槛、出字配比和护栏、摸底、手速、初入江湖。复习间隔 1/3/7/16/35 天先写在默认配置里。")
                }
                Section("整数") {
                    ForEach(ints, id: \.label) { f in
                        Stepper("\(f.label)：\(t[keyPath: f.kp])", value: Binding(get: { t[keyPath: f.kp] }, set: { t[keyPath: f.kp] = $0 }), in: f.range)
                    }
                }
                Section {
                    Button("恢复默认", role: .destructive) { t = TuningStore.reset(); apply() }
                } footer: {
                    Text("比武数值下一场生效；键盘相关的立即生效。修改保存在本机，重启后保留。")
                }
            }
            .navigationTitle("调参")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { apply(); dismiss() } }
                ToolbarItem(placement: .cancellationAction) { Button("应用并重开") { apply(); dismiss(); c.restart() } }
            }
            .onChange(of: t) { _, _ in apply() }
        }
    }

    private func row(_ f: D) -> some View {
        Stepper(value: Binding(get: { t[keyPath: f.kp] }, set: { t[keyPath: f.kp] = $0 }), in: f.range, step: f.step) {
            HStack {
                Text(f.label)
                Spacer()
                Text(String(format: f.step < 0.1 ? "%.2f" : "%.1f", t[keyPath: f.kp])).monospacedDigit().foregroundStyle(.secondary)
            }
        }
    }

    private func apply() {
        c.tuning = t
        TuningStore.save(t)
    }
}
