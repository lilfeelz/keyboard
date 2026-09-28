import Testing

@testable import TotemCore

@Suite struct TranslatorTests {
    func text(_ k: String, _ m: Mods = [], before: String = "", after: String = "") -> [Edit]? {
        Translator.edits(
            .stroke(Key(k), m), mode: .text, context: TextContext(before: before, after: after))
    }

    func term(_ k: String, _ m: Mods = []) -> [Edit]? {
        Translator.edits(.stroke(Key(k), m), mode: .terminal, context: TextContext())
    }

    @Test func printable() {
        #expect(text("a") == [.insert("a")])
        #expect(text("a", .shift) == [.insert("A")])
        #expect(text("1", .shift) == [.insert("!")])
        #expect(text("a", .ctrl) == nil)
    }

    @Test func wordDelete() {
        #expect(text("bspc", .alt, before: "hello world  ") == [.deleteBackward(7)])
        #expect(text("bspc", .alt, before: "foo(bar") == [.deleteBackward(3)])
        #expect(text("bspc", .alt, before: "foo((") == [.deleteBackward(2)])
        #expect(text("del", .alt, after: "  next word") == [.deleteForward("  next")])
    }

    @Test func lineDelete() {
        #expect(text("bspc", .meta, before: "one\ntwo three") == [.deleteBackward(9)])
        #expect(text("bspc", .meta, before: "one\n") == [.deleteBackward(1)])
    }

    @Test func cursorMotion() {
        #expect(text("left", before: "ab") == [.move(-1)])
        #expect(text("left", before: "a👍🏽") == [.move(-4)])
        #expect(text("home", before: "x\nabc") == [.move(-3)])
        #expect(text("end", after: "abc\nx") == [.move(3)])
        #expect(text("left", .shift, before: "ab") == nil)
    }

    @Test func upDownKeepColumn() {
        // cursor after "ab" on line 2; up lands after "ab" on line 1.
        #expect(text("up", before: "abcdef\nab") == [.move(-7)])
        // previous line shorter than the column: lands at its end.
        #expect(text("up", before: "a\nabc") == [.move(-4)])
        // no line above: go to line start.
        #expect(text("up", before: "abc") == [.move(-3)])
        #expect(text("down", before: "x\nab", after: "cd\nwxyz") == [.move(5)])
        #expect(text("down", before: "", after: "abc") == [.move(3)])
    }

    @Test func terminalControlAndAlt() {
        #expect(term("c", .ctrl) == [.insert("\u{3}")])
        #expect(term("[", .ctrl) == [.insert("\u{1b}")])
        #expect(term("b", .alt) == [.insert("\u{1b}b")])
        #expect(term("bspc", .alt) == [.insert("\u{1b}\u{7f}")])
        #expect(term("bspc") == [.deleteBackward(1)])
        #expect(term("ret") == [.insert("\r")])
        #expect(term("tab", .shift) == [.insert("\u{1b}[Z")])
    }

    @Test func terminalSequences() {
        #expect(term("up") == [.insert("\u{1b}[A")])
        #expect(term("left", .alt) == [.insert("\u{1b}[1;3D")])
        #expect(term("rght", [.ctrl, .shift]) == [.insert("\u{1b}[1;6C")])
        #expect(term("del") == [.insert("\u{1b}[3~")])
        #expect(term("f1") == [.insert("\u{1b}OP")])
        #expect(term("f5") == [.insert("\u{1b}[15~")])
        #expect(term("f13") == nil)
    }

    @Test func keyCaps() {
        let c = Config.default
        let base = c.layers[0].actions
        let comma = c.keys.firstIndex { $0.name == "," }!
        #expect(KeyCap.of(base[comma], shifted: false, mode: .text).main == ",")
        #expect(KeyCap.of(base[comma], shifted: false, mode: .text).hint == ";")
        #expect(KeyCap.of(base[comma], shifted: true, mode: .text).main == ";")
        let lmet = c.keys.firstIndex { $0.name == "lmet" }!
        let cap = KeyCap.of(base[lmet], shifted: false, mode: .text)
        #expect(cap.main == "⌫")
        #expect(cap.hint == "left")
        let left = c.layers[1].actions
        let x = c.keys.firstIndex { $0.name == "x" }!
        #expect(KeyCap.of(left[x], shifted: false, mode: .text).main == "⌘X")
        let a = c.keys.firstIndex { $0.name == "a" }!
        #expect(KeyCap.of(left[a], shifted: false, mode: .text).style == .inert)
    }
}
