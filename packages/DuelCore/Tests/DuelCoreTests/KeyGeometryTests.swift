import Testing
@testable import DuelCore

@Suite struct KeyGeometryTests {
    let m = KeyboardMetrics(screenWidth: 390, keyboardHeight: 216, keyWidth: 33, keyHeight: 42, gapX: 6, gapY: 12,
                            topInset: 8, row2Inset: 22, functionKeyWidth: 44)
    var g: KeyGeometry { KeyGeometry(metrics: m) }

    @Test func centerHitsKey() {
        let a = g.cap(for: "a")!
        #expect(g.key(at: KPoint(a.face.midX, a.face.midY))?.kind == .letter("a"))
    }

    @Test func gapBelongsToNearestHalf() {
        let q = g.cap(for: "q")!, w = g.cap(for: "w")!
        let mid = (q.face.maxX + w.face.x) / 2
        #expect(g.key(at: KPoint(mid - 0.5, q.face.midY))?.kind == .letter("q"))
        #expect(g.key(at: KPoint(mid + 0.5, q.face.midY))?.kind == .letter("w"))
    }

    @Test func rowEndsExtendToEdge() {
        let q = g.cap(for: "q")!, a = g.cap(for: "a")!
        #expect(g.key(at: KPoint(0.5, q.face.midY))?.kind == .letter("q"))
        #expect(g.key(at: KPoint(1, a.face.midY))?.kind == .letter("a"))
    }

    @Test func growOnlyForExpectedAndCapped() {
        let q = g.cap(for: "q")!, w = g.cap(for: "w")!
        let p = KPoint(w.hit.x + 1.5, q.face.midY)          // w 的判定区内 1.5 pt
        #expect(g.key(at: p)?.kind == .letter("w"))
        #expect(g.key(at: p, expected: ["q"], grow: 2)?.kind == .letter("q"))
        #expect(g.key(at: p, expected: ["e"], grow: 2)?.kind == .letter("w"))
        let far = KPoint(w.hit.x + 7, q.face.midY)
        #expect(g.key(at: far, expected: ["q"], grow: 20)?.kind == .letter("w"))   // 放宽上限 6 pt
    }

    @Test func adjacency() {
        #expect(g.areAdjacent("a", "s"))
        #expect(g.areAdjacent("a", "q"))
        #expect(g.areAdjacent("a", "w"))
        #expect(g.areAdjacent("a", "z"))
        #expect(!g.areAdjacent("a", "d"))
        #expect(!g.areAdjacent("q", "p"))
    }

    @Test func nearMissNeedsSingleExpectedAdjacentAndClose() {
        let s = g.cap(for: "s")!, a = g.cap(for: "a")!
        let edge = KPoint(a.face.maxX + 3.5, s.face.midY)   // 落在 s 的判定区，离 a 的键面 3.5 pt
        #expect(g.key(at: edge)?.kind == .letter("s"))
        #expect(g.nearMiss(hit: "s", at: edge, expected: ["a"], maxDistance: 8) == "a")
        #expect(g.nearMiss(hit: "s", at: edge, expected: ["a", "b"], maxDistance: 8) == nil)
        #expect(g.nearMiss(hit: "s", at: edge, expected: ["a"], maxDistance: 2) == nil)
        #expect(g.nearMiss(hit: "s", at: edge, expected: ["k"], maxDistance: 8) == nil)
    }

    @Test func scalesToUnknownWidth() {
        let table = KeyboardMetricsTable(source: "t", entries: [m])
        let s = table.metrics(forWidth: 428)
        #expect(abs(s.keyWidth - 33 * 428 / 390) < 0.001)
        #expect(s.keyHeight == 42)
    }
}
