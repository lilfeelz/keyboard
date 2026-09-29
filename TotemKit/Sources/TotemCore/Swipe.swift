/// Turns a drag on a `swipe-cursor` / `swipe-delete` key into edits.
///
/// The text around the cursor is read once, when the swipe starts, and then
/// tracked locally: the text proxy updates its context lazily, so reading it
/// back between steps would lag behind the moves already sent.
///
/// A keyboard cannot select text, so a delete swipe previews by moving the
/// cursor over characters and deletes the covered span on lift: dragging
/// left covers characters before the cursor, dragging right characters after
/// it, and dragging back toward the start gives them back. In terminal mode
/// there is no preview: each step sends a backspace or delete right away.
public struct SwipeTracker: Sendable {
    public let kind: SwipeKind
    public let mode: Mode

    /// Movement before a press turns into a swipe.
    public static let threshold = 14.0
    public var charStep = 12.0
    public var lineStep = 24.0

    private var before: String
    private var after: String
    /// Characters covered before the start (drag left), nearest first; nil
    /// for a step past the end of the known text.
    private var taken: [Character?] = []
    /// Characters covered after the start (drag right), nearest first.
    private var ahead: [Character?] = []
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
            let tx = Int(dx / charStep)
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
        // Covered back: the cursor sits before them. Forward: after them.
        let back = String(taken.reversed().compactMap { $0 })
        if !back.isEmpty { return [.deleteForward(back)] }
        let fwd = String(ahead.compactMap { $0 })
        if !fwd.isEmpty { return [.deleteBackward(fwd.count)] }
        return []
    }

    /// Cover one more character before (drag left) or after (drag right) the
    /// cursor. Past the end of the known text a step still counts, with nothing
    /// covered, so dragging back lines up with the finger.
    private mutating func take(forward: Bool) -> [Edit] {
        if mode == .terminal { return stroke(forward ? "del" : "bspc") }
        if forward {
            let c = after.first
            ahead.append(c)
            guard let c else { return [] }
            after.removeFirst()
            before.append(c)
            return [.move(String(c).utf16.count)]
        }
        let c = before.popLast()
        taken.append(c)
        guard let c else { return [] }
        after.insert(c, at: after.startIndex)
        return [.move(-String(c).utf16.count)]
    }

    /// Uncover the most recently covered character on that side.
    private mutating func giveBack(forward: Bool) -> [Edit] {
        guard mode == .text else { return [] }
        if forward {
            guard let c = ahead.popLast() ?? nil else { return [] }
            before.removeLast()
            after.insert(c, at: after.startIndex)
            return [.move(-String(c).utf16.count)]
        }
        guard let c = taken.popLast() ?? nil else { return [] }
        before.append(c)
        after.removeFirst()
        return [.move(String(c).utf16.count)]
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
