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
    var f = Field(before: "one two", after: "!")
    var s = SwipeTracker(
      kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
    f.apply(s.move(dx: -40, dy: 0))  // three characters back
    #expect(f.before == "one ")
    f.apply(s.move(dx: -20, dy: 0))  // drag back right: two are given back
    #expect(f.before == "one tw")
    f.apply(s.end())
    #expect(f.before == "one tw")
    #expect(f.after == "!")
  }

  @Test func deletePartOfWord() {
    var f = Field(before: "one three", after: "!")
    var s = SwipeTracker(
      kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
    f.apply(s.move(dx: -40, dy: 0))
    f.apply(s.end())
    #expect(f.before == "one th")
    #expect(f.after == "!")
  }

  @Test func deleteCountsGraphemes() {
    var f = Field(before: "aü👍🏽", after: "")
    var s = SwipeTracker(
      kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
    f.apply(s.move(dx: -25, dy: 0))
    f.apply(s.end())
    #expect(f.before == "a")
  }

  @Test func deletePastStartKeepsFingerInStep() {
    var f = Field(before: "ab", after: "")
    var s = SwipeTracker(
      kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
    f.apply(s.move(dx: -50, dy: 0))  // four steps, two characters
    f.apply(s.move(dx: -25, dy: 0))  // two steps back: still past the start
    #expect(f.before == "")
    f.apply(s.end())
    #expect(f.before == "")
  }

  @Test func deleteDraggedBackToStartDeletesNothing() {
    var f = Field(before: "abc def", after: "")
    var s = SwipeTracker(
      kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
    f.apply(s.move(dx: -60, dy: 0))
    f.apply(s.move(dx: 5, dy: 0))
    f.apply(s.end())
    #expect(f.before == "abc def")
  }

  @Test func deleteForwardOnRightDrag() {
    var f = Field(before: "one ", after: "two!")
    var s = SwipeTracker(
      kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
    f.apply(s.move(dx: 40, dy: 0))
    #expect(f.before == "one two")
    f.apply(s.move(dx: 25, dy: 0))
    f.apply(s.end())
    #expect(f.before == "one ")
    #expect(f.after == "o!")
  }

  @Test func dragAcrossStartSwitchesSide() {
    var f = Field(before: "one two", after: " three")
    var s = SwipeTracker(
      kind: .delete, mode: .text, context: TextContext(before: f.before, after: f.after))
    f.apply(s.move(dx: -25, dy: 0))
    f.apply(s.move(dx: 25, dy: 0))
    f.apply(s.end())
    #expect(f.before == "one two")
    #expect(f.after == "hree")
  }

  @Test func deleteInTerminalIsImmediate() {
    var s = SwipeTracker(kind: .delete, mode: .terminal, context: TextContext())
    #expect(s.move(dx: -25, dy: 0) == [.deleteBackward(1), .deleteBackward(1)])
    #expect(s.move(dx: 13, dy: 0) == [.insert("\u{1b}[3~")])
    #expect(s.end() == [])
  }

  @Test func cursorMovesByCharsAndLines() {
    var f = Field(before: "abcd\nefgh", after: "")
    var s = SwipeTracker(
      kind: .cursor, mode: .text, context: TextContext(before: f.before, after: f.after))
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

  @Test func cancelAfterHoldStopsRepeat() {
    let h = Harness()
    let bspc = h.idx("bspc")
    h.down("bspc")
    h.wait(250)
    h.record(h.engine.cancel(bspc, at: h.t))
    h.wait(800)
    h.up("bspc")
    h.tap("q")
    #expect(h.typed == "⌫q")
  }

  @Test func rowsCentreWithGaps() {
    let c = Config.default
    #expect(Set(c.rowWidths) == [12])
  }
}
