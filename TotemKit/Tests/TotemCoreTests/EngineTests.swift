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
        #expect(c.layers.map(\.name) == ["base", "left", "right", "fun"])
        #expect(c.keys.count == 41)
        #expect(c.rows == 4)
        #expect(c.chords.count == 2)
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
        h.type("a", "bspc")
        #expect(h.typed == "a⌫")
    }

    @Test func holdLocksLayerAndTapUnlocks() {
        let h = Harness()
        h.down("lmet")
        h.wait(200)
        h.tap("q")
        h.up("lmet")
        h.tap("q")
        h.tap("lmet")
        h.tap("q")
        #expect(h.typed == "11q")
    }

    @Test func stickyLayerThenUnlockKeyCancels() {
        let h = Harness()
        h.type("rmet", "rmet", "q")
        #expect(h.typed == "q")
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
        // tapped: a one-shot nav layer, so w is 2
        #expect(h.typed == "2")
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

    @Test func shiftHoldTogglesCapsLock() {
        let h = Harness()
        h.down("lsft")
        h.wait(200)
        h.up("lsft")
        h.type("a", "b", ",")
        h.down("lsft")
        h.wait(200)
        h.up("lsft")
        h.tap("c")
        #expect(h.typed == "AB,c")
    }

    /// Caps-word is not in the default layout any more; test it on its own config.
    func capsWordHarness() throws -> Harness {
        try Harness(
            Config.parse(
                """
                (defsrc cw a b spc 1 - /)
                (deflayer x (caps-word 2000) a b spc 1 - /)
                """))
    }

    @Test func capsWord() throws {
        let h = try capsWordHarness()
        h.type("cw", "a", "1", "b", "-", "/", "a")
        #expect(h.typed == "A1B-/a")
    }

    @Test func capsWordEndsOnSpace() throws {
        let h = try capsWordHarness()
        h.type("cw", "a", "spc", "b")
        #expect(h.typed == "A b")
    }

    @Test func umlautsOnHold() {
        let h = Harness()
        for k in ["a", "o", "u", "s"] {
            h.down(k)
            h.wait(320)
            h.up(k)
        }
        h.tap("a")
        #expect(h.typed == "äöüßa")
    }

    @Test func umlautsFollowShift() {
        let h = Harness()
        h.tap("lsft")
        h.down("u")
        h.wait(320)
        h.up("u")
        h.down("s")
        h.wait(320)
        h.up("s")
        #expect(h.typed == "Üß")
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
        h.engine.mode = .terminal
        h.tap("fn")
        h.type("lsft", "fn")
        #expect(h.typed == "\u{1b}\u{1b}\u{1b}")
    }

    @Test func heldBackspaceRepeats() {
        let h = Harness()
        // pressed after the 200ms swipe wait, repeats 400ms later every 50ms
        h.down("bspc")
        h.wait(200 + 400 + 50 * 3 + 1)
        h.up("bspc")
        #expect(h.typed == String(repeating: "⌫", count: 5))
    }

    @Test func shiftedBackspaceIsDelete() {
        let h = Harness()
        h.tap("lsft")
        h.tap("bspc")
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
        // `_` on a switched-to layer falls through to the first layer: rpt repeats x.
        #expect(h.typed == "axxa")
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

@Suite struct RemapTests {
    func textEdits(_ h: Harness, before: String = "one two", after: String = " three") -> [Edit] {
        h.outputs.flatMap {
            Translator.edits($0, mode: .text, context: TextContext(before: before, after: after)) ?? []
        }
    }

    @Test func globeSwitchesKeyboard() {
        let h = Harness()
        h.tap("fn")
        #expect(h.outputs == [.system(.nextKeyboard)])
    }

    @Test func escIsEscInTerminalMode() {
        let h = Harness()
        h.engine.mode = .terminal
        h.tap("fn")
        #expect(h.typed == "\u{1b}")
    }

    @Test func stickyModsOnNav() {
        // nav thumb held: tap s (sticky ⌥), then h (◀) = word left; tap f (sticky ⌘), then l (▶) = line end
        let h = Harness()
        h.down("lmet")
        h.wait(200)
        h.type("s", "h", "f", "l", "h")
        h.up("lmet")
        #expect(textEdits(h) == [.move(-3), .move(6), .move(-1)])
    }

    @Test func stickyModTappedTwiceCancels() {
        let h = Harness()
        h.down("lmet")
        h.wait(200)
        h.type("s", "s", "h")
        h.up("lmet")
        #expect(textEdits(h) == [.move(-1)])
    }

    @Test func escCapFollowsMode() {
        let c = Config.default
        let globe = c.keys.firstIndex { $0.name == "fn" }!
        let a = c.layers[0].actions[globe]
        #expect(KeyCap.of(a, shifted: false, mode: .text).symbol == "globe")
        #expect(KeyCap.of(a, shifted: false, mode: .terminal).main == "esc")
    }
}

@Suite struct FunLayerTests {
    @Test func tabHoldIsStickyFun() {
        let h = Harness()
        h.down("tab")
        h.wait(200)
        h.up("tab")
        h.tap("q")
        h.tap("q")
        #expect(h.outputs == [.stroke(Key("f1"), []), .stroke(Key("q"), [])])
    }

    @Test func enterTapIsEnterAndFunHidesKeyboard() {
        let h = Harness()
        h.tap("ret")
        h.down("ret", after: 400)
        h.wait(200)
        h.tap("s")
        h.up("ret")
        #expect(h.outputs == [.stroke(Key("ret"), []), .system(.dismiss)])
    }

    @Test func navInnerThumbIsStickyShift() {
        let h = Harness()
        h.down("lmet")
        h.wait(200)
        h.tap("rmet")
        h.up("lmet")
        h.tap("lmet")  // unlock nav; the sticky shift survives
        h.tap("a")
        #expect(h.typed == "A")
    }

    @Test func symInnerThumbIsStickyShift() {
        let h = Harness()
        h.down("rmet")
        h.wait(200)
        h.tap("lmet")
        h.up("rmet")
        h.tap("rmet")  // unlock sym
        h.tap("a")
        #expect(h.typed == "A")
    }
}

@Suite struct LayerKeyTests {
    @Test func navTapIsOneShotLayer() {
        let h = Harness()
        h.type("lmet", "q", "q")
        #expect(h.typed == "1q")
    }

    @Test func navTappedTwiceCancels() {
        let h = Harness()
        h.type("lmet", "lmet", "q")
        #expect(h.typed == "q")
    }

    @Test func symTapIsOneShotLayer() {
        let h = Harness()
        h.type("rmet", "q", "q")
        #expect(h.typed == "!q")
    }

    @Test func backspaceTypedFastKeepsOrder() {
        let h = Harness()
        h.down("bspc")
        h.down("a", after: 30)
        h.up("bspc", after: 10)
        h.up("a", after: 10)
        #expect(h.typed == "⌫a")
    }
}

@Suite struct AlternateHoldTests {
    @Test func slashAndMinusHolds() {
        let h = Harness()
        h.type(";", "/")
        for k in [";", "/"] {
            h.down(k, after: 400)  // outside the quick-tap window, which would repeat the tap
            h.wait(320)
            h.up(k)
        }
        #expect(h.typed == "/-?!")
    }
}
