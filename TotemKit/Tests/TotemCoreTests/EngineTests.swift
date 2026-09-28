import Testing

@testable import TotemCore

/// Drives an engine by defsrc name and collects what it would type.
final class Harness {
    let engine: Engine
    var t = 0.0
    var typed = ""
    var outputs: [Output] = []

    init(_ config: Config = .default) {
        engine = Engine(config: config)
    }

    func idx(_ name: String) -> Int {
        engine.config.keys.firstIndex { $0.name == name }!
    }

    func record(_ os: [Output]) {
        outputs += os
        for o in os {
            for e in Translator.edits(o, mode: .terminal, context: TextContext()) ?? [] {
                switch e {
                case .insert(let s): typed += s
                case .deleteBackward(let n): typed += String(repeating: "⌫", count: n)
                default: break
                }
            }
        }
    }

    func wait(_ ms: Double) {
        let end = t + ms / 1000
        while let d = engine.nextDeadline, d <= end {
            t = max(t, d)
            record(engine.tick(at: t))
        }
        t = end
        record(engine.tick(at: t))
    }

    func down(_ k: String, after ms: Double = 0) {
        wait(ms)
        record(engine.press(idx(k), at: t))
    }

    func up(_ k: String, after ms: Double = 0) {
        wait(ms)
        record(engine.release(idx(k), at: t))
    }

    func tap(_ k: String, hold ms: Double = 20) {
        down(k)
        up(k, after: ms)
        wait(30)
    }

    func type(_ keys: String...) { for k in keys { tap(k) } }
}

@Suite struct ParseTests {
    @Test func defaultConfigParses() throws {
        let c = Config.default
        #expect(c.layers.map(\.name) == ["base", "left", "right", "middle", "del"])
        #expect(c.keys.count == 41)
        #expect(c.rows == 4)
        #expect(c.chords.count == 3)
        #expect(c.warnings.isEmpty)
    }

    @Test func geometryFromLines() throws {
        let c = try Config.parse(
            """
            (defsrc
              a gap:0.5 b:2
              c d
            )
            (deflayer x a b c d)
            """)
        #expect(c.keys.map(\.x) == [0, 1.5, 0, 1])
        #expect(c.keys.map(\.row) == [0, 0, 1, 1])
        #expect(c.width == 3.5)
    }

    @Test func errorsCarryPositions() {
        #expect(throws: ConfigError("layer x has 1 keys, defsrc has 2", at: SourcePos(line: 2, col: 1))) {
            try Config.parse("(defsrc a b)\n(deflayer x a)")
        }
        #expect(throws: ConfigError("unknown alias @nope", at: SourcePos(line: 1, col: 24))) {
            try Config.parse("(defsrc a)\n(deflayer x @nope)".replacingOccurrences(of: "\n", with: " "))
        }
        #expect(throws: ConfigError("unknown layer ghost", at: SourcePos(line: 1, col: 38))) {
            try Config.parse("(defsrc a) (deflayer x (layer-switch ghost))")
        }
    }

    @Test func aliasCycle() {
        #expect(throws: ConfigError.self) {
            try Config.parse("(defsrc a) (defalias x @y y @x) (deflayer l @x)")
        }
    }

    @Test func commentsAndStrings() throws {
        let c = try Config.parse(
            """
            ;; comment
            #| block
               comment |#
            (defsrc a ;)
            (deflayer x "hi" r#"a"b"#)
            """)
        #expect(c.layers[0].actions == [.text("hi"), .text(#"a"b"#)])
        #expect(c.keys.map(\.name) == ["a", ";"])
    }
}

@Suite struct EngineTests {
    @Test func lettersAndRollover() {
        let h = Harness()
        h.down("h")
        h.down("e", after: 10)
        h.up("h", after: 10)
        h.up("e", after: 10)
        h.type("y")
        #expect(h.typed == "hey")
    }

    @Test func tapHoldTapIsBackspace() {
        let h = Harness()
        h.type("a", "lmet")
        #expect(h.typed == "a⌫")
    }

    @Test func tapHoldHoldIsLayer() {
        let h = Harness()
        h.down("lmet")
        h.wait(200)
        h.tap("q")
        h.up("lmet")
        h.tap("q")
        #expect(h.typed == "1q")
    }

    @Test func tapHoldReleaseResolvesOnRoll() {
        // tap-hold-release: another key pressed and released inside the window = hold.
        let h = Harness()
        h.down("lmet")
        h.down("w", after: 20)
        h.up("w", after: 20)
        h.up("lmet", after: 20)
        #expect(h.typed == "2")
    }

    @Test func tapHoldReleasePressOnlyIsTap() {
        let h = Harness()
        h.down("lmet")
        h.down("w", after: 20)
        h.up("lmet", after: 20)
        h.up("w", after: 20)
        #expect(h.typed == "⌫w")
    }

    @Test func oneShotShift() {
        let h = Harness()
        h.type("lsft", "a", "a")
        #expect(h.typed == "Aa")
    }

    @Test func oneShotShiftExpires() {
        let h = Harness()
        h.tap("lsft")
        h.wait(2100)
        h.tap("a")
        #expect(h.typed == "a")
    }

    @Test func oneShotShiftTwiceCancels() {
        let h = Harness()
        h.type("lsft", "lsft", "a")
        #expect(h.typed == "a")
    }

    @Test func forkOnShift() {
        let h = Harness()
        h.type(",", "lsft", ",", ".", "lsft", ".")
        #expect(h.typed == ",;.:")
    }

    @Test func heldShiftUppercases() {
        let h = Harness()
        h.down("lsft")
        h.wait(200)
        h.type("a", "b")
        h.up("lsft")
        h.tap("c")
        #expect(h.typed == "ABc")
    }

    @Test func capsWord() {
        let h = Harness()
        h.type("lalt", "a", "b", ";", "/", "c", "spc", "d")
        // `/` is not in the continue list, so it ends caps-word.
        #expect(h.typed == "AB/-c d")
    }

    @Test func capsWordContinuesThroughDigitsAndEndsOnSpace() {
        let h = Harness()
        h.type("lalt", "a", "spc", "b")
        #expect(h.typed == "A b")
    }

    @Test func chordEnter() {
        let h = Harness()
        h.down("j")
        h.down("k", after: 20)
        h.up("j", after: 40)
        h.up("k", after: 10)
        #expect(h.typed == "\r")
    }

    @Test func chordTimesOutIntoKeys() {
        let h = Harness()
        h.down("j")
        h.down("k", after: 150)
        h.up("j", after: 10)
        h.up("k", after: 10)
        #expect(h.typed == "jk")
    }

    @Test func chordBrokenByRelease() {
        let h = Harness()
        h.down("j")
        h.up("j", after: 30)
        h.tap("k")
        #expect(h.typed == "jk")
    }

    @Test func chordDisabledOnLayer() {
        let h = Harness()
        h.down("lmet")
        h.wait(200)
        h.down("j")
        h.down("k", after: 10)
        h.up("j", after: 10)
        h.up("k", after: 10)
        h.up("lmet")
        // left layer: j/k are down/up arrows
        #expect(h.typed == "\u{1b}[B\u{1b}[A")
    }

    @Test func chordLayerWhileHeld() {
        // h+l holds the del layer; its left thumb is bspc.
        let h = Harness()
        h.down("h")
        h.down("l", after: 10)
        h.wait(150)
        h.tap("lmet")
        h.up("h")
        h.up("l")
        h.tap("f")
        #expect(h.typed == "⌫f")
    }

    @Test func wordDeleteChord() {
        let h = Harness()
        h.down("d")
        h.down("f", after: 10)
        h.up("d", after: 30)
        h.up("f")
        #expect(h.outputs == [.stroke(Key("bspc"), .alt)])
    }

    @Test func symLayerMacros() {
        let h = Harness()
        h.down("rmet")
        h.wait(200)
        h.type("n", "/")
        h.up("rmet")
        #expect(h.typed == "<-:=")
    }

    @Test func escTapAndShiftedDoubleEsc() {
        let h = Harness()
        h.tap("rmet")
        h.type("lsft", "rmet")
        #expect(h.typed == "\u{1b}\u{1b}\u{1b}")
    }

    @Test func quickTapRepeatsBackspace() {
        let h = Harness()
        h.tap("lmet")
        h.down("lmet", after: 50)
        h.wait(400 + 50 * 3 + 1)
        h.up("lmet")
        #expect(h.typed == String(repeating: "⌫", count: 6))
    }

    @Test func tapHoldShiftMakesBackspaceDelete() {
        let h = Harness()
        h.down("lsft")
        h.wait(200)
        h.tap("lmet")
        h.up("lsft")
        #expect(h.outputs == [.stroke(Key("del"), [])])
    }

    @Test func layerSwitchAndRepeat() throws {
        let c = try Config.parse(
            """
            (defsrc a b c)
            (deflayer one a (layer-switch two) rpt)
            (deflayer two x (layer-switch one) _)
            """)
        let h = Harness(c)
        h.type("a", "b", "a", "c", "b", "a")
        // `_` on two falls through to defsrc's `c` key.
        #expect(h.typed == "axca")
    }

    @Test func switchOnHeldMeta() {
        let h = Harness()
        h.down("lmet")
        h.wait(200)
        h.tap("l")
        h.up("lmet")
        #expect(h.typed == "\u{1b}[C")
    }

    @Test func textModeCmdChordsAreUnsupported() {
        #expect(Translator.edits(.stroke(Key("a"), .meta), mode: .text, context: TextContext()) == nil)
        #expect(Translator.edits(.stroke(Key("c"), .meta), mode: .text, context: TextContext()) == [.copy])
    }
}
