/// Turns a drag on a `swipe-cursor` / `swipe-delete` key into edits.
///
/// The text around the cursor is read once, when the swipe starts, and then
/// tracked locally: the text proxy updates its context lazily, so reading it
/// back between steps would lag behind the moves already sent.
///
/// A keyboard cannot select text, so a delete swipe previews by moving the
/// cursor back over whole words (dragging right gives them back) and deletes
/// the covered span on lift (the cursor then sits before it, so it is a
/// forward delete). In terminal mode there is no preview: each step
/// left sends a word delete right away.
public struct SwipeTracker: Sendable {
    public let kind: SwipeKind
    public let mode: Mode

    /// Movement before a press turns into a swipe.
    public static let threshold = 14.0
    public var charStep = 12.0
    public var lineStep = 24.0
    public var wordStep = 18.0

    private var before: String
    private var after: String
    private var taken: [String] = []
    private var x = 0
    private var y = 0

    public init(kind: SwipeKind, mode: Mode, context: TextContext) {
        self.kind = kind
        self.mode = mode
        before = context.before
        after = context.after
    }

    /// Edits for the drag so far; `dx`/`dy` are points from where the swipe began.
    public mutating func move(dx: Double, dy: Double) -> [Edit] {
        var out: [Edit] = []
        switch kind {
        case .cursor:
            let tx = Int(dx / charStep)
            let ty = Int(dy / lineStep)
            while x != tx {
                out += stroke(x < tx ? "rght" : "left")
                x += x < tx ? 1 : -1
            }
            while y != ty {
                if mode == .terminal {
                    out += stroke(y < ty ? "down" : "up")
                } else {
                    out.append(.line(y < ty ? 1 : -1))
                    // The line move lands wherever the host's text says; stop guessing.
                    before = ""
                    after = ""
                }
                y += y < ty ? 1 : -1
            }
        case .delete:
            let tx = min(0, Int(dx / wordStep))
            while x > tx {
                x -= 1
                if mode == .terminal {
                    out += Translator.edits(.stroke(Key("bspc"), .alt), mode: mode, context: context) ?? []
                    continue
                }
                let w = String(Translator.wordBefore(before))
                taken.append(w)
                guard !w.isEmpty else { continue }
                before.removeLast(w.count)
                after = w + after
                out.append(.move(-w.utf16.count))
            }
            while x < tx {
                x += 1
                guard mode == .text, let w = taken.popLast(), !w.isEmpty else { continue }
                before += w
                after.removeFirst(w.count)
                out.append(.move(w.utf16.count))
            }
        }
        return out
    }

    /// Edits to finish the swipe when the finger lifts.
    public func end() -> [Edit] {
        guard kind == .delete, mode == .text else { return [] }
        let span = taken.reversed().joined()
        guard !span.isEmpty else { return [] }
        return [.deleteForward(span)]
    }

    private var context: TextContext { TextContext(before: before, after: after) }

    private mutating func stroke(_ name: String) -> [Edit] {
        let edits = Translator.edits(.stroke(Key(name), []), mode: mode, context: context) ?? []
        for case .move(let n) in edits { shift(n) }
        return edits
    }

    /// Mirror a cursor move in the local copy of the text.
    private mutating func shift(_ n: Int) {
        var n = n
        while n < 0, let c = before.popLast() {
            after.insert(c, at: after.startIndex)
            n += String(c).utf16.count
        }
        while n > 0, let c = after.first {
            after.removeFirst()
            before.append(c)
            n -= String(c).utf16.count
        }
    }
}
