/// Turns a drag on a `swipe-cursor` / `swipe-delete` key into edits.
///
/// The text around the cursor is read once, when the swipe starts, and then
/// tracked locally: the text proxy updates its context lazily, so reading it
/// back between steps would lag behind the moves already sent.
///
/// A keyboard cannot select text, so a delete swipe previews by moving the
/// cursor over whole words and deletes the covered span on lift: dragging
/// left covers words before the cursor, dragging right words after it, and
/// dragging back toward the start gives words back. In terminal mode there is
/// no preview: each step sends a word delete (back or forward) right away.
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
    /// Words covered before the start (drag left), nearest first.
    private var taken: [String] = []
    /// Words covered after the start (drag right), nearest first.
    private var ahead: [String] = []
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
            let tx = Int(dx / wordStep)
            while x > tx {
                x -= 1
                if x >= 0 { out += giveBack(forward: true) } else { out += take(forward: false) }
            }
            while x < tx {
                x += 1
                if x <= 0 { out += giveBack(forward: false) } else { out += take(forward: true) }
            }
        }
        return out
    }

    /// Edits to finish the swipe when the finger lifts.
    public func end() -> [Edit] {
        guard kind == .delete, mode == .text else { return [] }
        // Covered words back: the cursor sits before them. Forward: after them.
        let back = taken.reversed().joined()
        if !back.isEmpty { return [.deleteForward(back)] }
        let fwd = ahead.joined()
        if !fwd.isEmpty { return [.deleteBackward(fwd.count)] }
        return []
    }

    /// Cover one more word before (drag left) or after (drag right) the cursor.
    private mutating func take(forward: Bool) -> [Edit] {
        if mode == .terminal {
            // alt-backspace / alt-d: readline's word deletes
            return [.insert(forward ? "\u{1b}d" : "\u{1b}\u{7f}")]
        }
        if forward {
            let w = Translator.wordAfter(after)
            ahead.append(w)
            guard !w.isEmpty else { return [] }
            after.removeFirst(w.count)
            before += w
            return [.move(w.utf16.count)]
        }
        let w = String(Translator.wordBefore(before))
        taken.append(w)
        guard !w.isEmpty else { return [] }
        before.removeLast(w.count)
        after = w + after
        return [.move(-w.utf16.count)]
    }

    /// Uncover the most recently covered word on that side.
    private mutating func giveBack(forward: Bool) -> [Edit] {
        guard mode == .text else { return [] }
        if forward {
            guard let w = ahead.popLast(), !w.isEmpty else { return [] }
            before.removeLast(w.count)
            after = w + after
            return [.move(-w.utf16.count)]
        }
        guard let w = taken.popLast(), !w.isEmpty else { return [] }
        before += w
        after.removeFirst(w.count)
        return [.move(w.utf16.count)]
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
