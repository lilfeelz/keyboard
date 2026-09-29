import Testing

@testable import TotemCore

/// A field whose every edit goes through a History, like the controller does.
struct Recorded {
  var field = Field(before: "", after: "")
  var history = History()

  var context: TextContext { TextContext(before: field.before, after: field.after) }

  mutating func run(_ edits: [Edit]) {
    for e in edits {
      switch e {
      case .undo: field.apply(history.undo(context: context))
      case .redo: field.apply(history.redo(context: context))
      default:
        history.record(e, context: context)
        field.apply([e])
      }
    }
  }

  mutating func type(_ s: String) { run(s.map { .insert(String($0)) }) }
}

@Suite struct HistoryTests {
  @Test func undoTypingByWord() {
    var r = Recorded()
    r.type("hello world")
    r.run([.undo])
    #expect(r.field.before == "hello ")
    r.run([.undo])
    #expect(r.field.before == "")
    r.run([.redo, .redo])
    #expect(r.field.before == "hello world")
  }

  @Test func undoBackspacesRestoresText() {
    var r = Recorded()
    r.type("abc")
    r.run([.deleteBackward(1), .deleteBackward(1)])
    #expect(r.field.before == "a")
    r.run([.undo])
    #expect(r.field.before == "abc")
  }

  @Test func undoWordDeleteAndMoves() {
    var r = Recorded()
    r.type("one two")
    r.run([.move(-3), .deleteForward("two"), .undo])
    #expect(r.field.before == "one ")
    #expect(r.field.after == "two")
    r.run([.undo])
    #expect(r.field.before == "one two")
  }

  @Test func newEditDropsRedo() {
    var r = Recorded()
    r.type("ab")
    r.run([.undo])
    r.type("c")
    r.run([.redo])
    #expect(r.field.before == "c")
  }

  @Test func foreignChangeDropsHistory() {
    var r = Recorded()
    r.type("teh")
    r.field.before = "the"  // autocorrect replaced it behind our back
    r.run([.undo])
    #expect(r.field.before == "the")
    #expect(!r.history.canUndo)
  }

  @Test func cmdZTranslates() {
    let ctx = TextContext()
    #expect(Translator.edits(.stroke(Key("z"), .meta), mode: .text, context: ctx) == [.undo])
    #expect(
      Translator.edits(.stroke(Key("z"), [.meta, .shift]), mode: .text, context: ctx) == [.redo])
    #expect(
      Translator.edits(.stroke(Key("z"), .meta), mode: .terminal, context: ctx) == [
        .insert("\u{1f}")
      ])
  }
}
