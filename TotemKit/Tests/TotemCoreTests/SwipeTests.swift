import Testing

@testable import TotemCore

/// Applies edits to a string with a cursor, like a text field would.
struct Field {
    var before: String
    var after: String

    mutating func apply(_ edits: [Edit]) {
        for e in edits {
            switch e {
            case .move(var n):
                while n < 0, let c = before.popLast() {
                    after.insert(c, at: after.startIndex)
                    n += String(c).utf16.count
                }
                while n > 0, let c = after.first {
                    before.append(after.removeFirst())
                    n -= String(c).utf16.count
                }
            case .deleteBackward(let n):
                before.removeLast(min(n, before.count))
            case .deleteForward(let s):
                after.removeFirst(min(s.count, after.count))
            case .insert(let s):
                before += s
            default:
                break
            }
        }
    }
}

@Suite struct SwipeTests {
    @Test func deletePreviewsThenDeletesOnLift() {
        var f = Field(before: "one two three", after: "!")
        var s = SwipeTracker(kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
        f.apply(s.move(dx: -40, dy: 0))  // two words back
        #expect(f.before == "one ")
        f.apply(s.move(dx: -20, dy: 0))  // drag back right: "two " is given back
        #expect(f.before == "one two ")
        f.apply(s.end())
        #expect(f.before == "one two ")
        #expect(f.after == "!")
    }

    @Test func deleteTwoWordsKeepsOrder() {
        var f = Field(before: "one two three", after: "!")
        var s = SwipeTracker(kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
        f.apply(s.move(dx: -40, dy: 0))
        f.apply(s.end())
        #expect(f.before == "one ")
        #expect(f.after == "!")
    }

    @Test func deleteDraggedBackToStartDeletesNothing() {
        var f = Field(before: "abc def", after: "")
        var s = SwipeTracker(kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
        f.apply(s.move(dx: -60, dy: 0))
        f.apply(s.move(dx: 30, dy: 0))
        f.apply(s.end())
        #expect(f.before == "abc def")
    }

    @Test func deleteForwardOnRightDrag() {
        var f = Field(before: "one ", after: "two three!")
        var s = SwipeTracker(kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
        f.apply(s.move(dx: 40, dy: 0))
        #expect(f.before == "one two three")
        f.apply(s.move(dx: 20, dy: 0))
        f.apply(s.end())
        #expect(f.before == "one ")
        #expect(f.after == " three!")
    }

    @Test func dragAcrossStartSwitchesSide() {
        var f = Field(before: "one two", after: " three")
        var s = SwipeTracker(kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
        f.apply(s.move(dx: -20, dy: 0))
        f.apply(s.move(dx: 20, dy: 0))
        f.apply(s.end())
        #expect(f.before == "one two")
        #expect(f.after == "")
    }

    @Test func deleteInTerminalIsImmediate() {
        var s = SwipeTracker(kind: .delete, mode: .terminal, context: TextContext())
        #expect(s.move(dx: -37, dy: 0) == [.insert("\u{1b}\u{7f}"), .insert("\u{1b}\u{7f}")])
        #expect(s.end() == [])
    }

    @Test func cursorMovesByCharsAndLines() {
        var f = Field(before: "abcd\nefgh", after: "")
        var s = SwipeTracker(kind: .cursor, mode: .text, context: TextContext(before: f.before, after: f.after))
        f.apply(s.move(dx: -25, dy: 0))
        #expect(f.before == "abcd\nef")
        #expect(s.move(dx: -25, dy: -30) == [.line(-1)])
        #expect(s.move(dx: -25, dy: 0) == [.line(1)])
    }

    @Test func cursorInTerminalSendsArrows() {
        var s = SwipeTracker(kind: .cursor, mode: .terminal, context: TextContext())
        #expect(s.move(dx: 13, dy: 0) == [.insert("\u{1b}[C")])
    }

    @Test func cancelDropsPendingSwipeKey() {
        let h = Harness()
        let bspc = h.idx("bspc")
        h.down("bspc")
        #expect(h.engine.swipe(at: bspc) == .delete)
        h.record(h.engine.cancel(bspc, at: h.t))
        h.up("bspc", after: 50)
        h.tap("q")
        #expect(h.typed == "q")
    }

    @Test func cancelReleasesResolvedLayer() {
        let h = Harness()
        let lmet = h.idx("lmet")
        h.down("lmet")
        h.wait(200)
        h.record(h.engine.cancel(lmet, at: h.t))
        h.tap("q")
        h.up("lmet")
        #expect(h.typed == "q")
    }

    @Test func rowsCentreWithGaps() {
        let c = Config.default
        #expect(Set(c.rowWidths) == [12])
    }
}
