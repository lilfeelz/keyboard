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

    @Test func upDownAreLineMoves() {
        #expect(text("up") == [.line(-1)])
        #expect(text("down") == [.line(1)])
        #expect(text("up", .shift) == nil)
    }

    /// Runs both hops against a full text, the way the controller does.
    func lineMove(_ dir: Int, _ before: String, _ after: String, column: Int? = nil) -> String {
        var f = Field(before: before, after: after)
        let hop = LineNav.leave(dir, TextContext(before: f.before, after: f.after))
        f.apply([.move(hop.move)])
        if hop.crossed {
            // The host shows only the current line after the hop, like a real text proxy.
            let visible = String(LineNav.currentLineBefore(f.before))
            let m = LineNav.arrive(dir, column: column ?? hop.column, TextContext(before: visible, after: f.after))
            f.apply([.move(m)])
        }
        return f.before + "|" + f.after
    }

    @Test func lineMovesKeepColumn() {
        #expect(lineMove(-1, "abcdef\nab", "cd") == "ab|cdef\nabcd")
        #expect(lineMove(-1, "a\nabc", "") == "a|\nabc")
        #expect(lineMove(-1, "abc", "") == "|abc")
        #expect(lineMove(1, "x\nab", "cd\nwxyz") == "x\nabcd\nwx|yz")
        #expect(lineMove(1, "", "abc") == "abc|")
        #expect(lineMove(1, "ab", "\n\nxyz") == "ab\n|\nxyz")
        // a remembered goal column survives a short line in between
        #expect(lineMove(-1, "abcdef\n", "", column: 4) == "abcd|ef\n")
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
        // S-tab has nothing to do in a text field; in terminal mode it is CSI Z.
        let stb = c.keys.firstIndex { $0.name == "/" }!
        #expect(KeyCap.of(left[stb], shifted: false, mode: .text).style == .inert)
        #expect(KeyCap.of(left[stb], shifted: false, mode: .terminal).style == .special)
    }
}
