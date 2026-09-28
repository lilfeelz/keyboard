/// Turns engine output into edits an iOS keyboard can make. A keyboard
/// extension cannot send key events, only insert text, delete backward and move
/// the cursor, so everything else is either emulated from the text around the
/// cursor (word delete, up/down, home/end) or, in terminal mode, encoded as the
/// bytes a terminal expects (control codes, xterm escape sequences).

public enum Edit: Sendable, Equatable {
    case insert(String)
    /// Characters (grapheme clusters) to delete before the cursor.
    case deleteBackward(Int)
    /// Text after the cursor to delete.
    case deleteForward(String)
    /// Cursor offset in UTF-16 units, as `adjustTextPosition` expects.
    case move(Int)
    case copy
    case cut
    case paste
    /// Undo / redo this keyboard's own edits (the host's undo stack is out of reach).
    case undo
    case redo
    case nextKeyboard
    case dismiss
    case toggleTerminal
}

public enum Mode: Sendable, Equatable {
    case text
    case terminal
}

public struct TextContext: Sendable, Equatable {
    public var before: String
    public var after: String

    public init(before: String = "", after: String = "") {
        self.before = before
        self.after = after
    }
}

public enum Translator {
    /// Edits for one output, or nil when the keyboard cannot do it in this mode.
    public static func edits(_ o: Output, mode: Mode, context: TextContext) -> [Edit]? {
        switch o {
        case .text(let s):
            return [.insert(s)]
        case .system(let s):
            switch s {
            case .nextKeyboard: return [.nextKeyboard]
            case .dismiss: return [.dismiss]
            case .toggleTerminal: return [.toggleTerminal]
            case .copy: return [.copy]
            case .cut: return [.cut]
            case .paste: return [.paste]
            case .undo: return [.undo]
            case .redo: return [.redo]
            }
        case .stroke(let k, let m):
            return mode == .terminal ? terminal(k, m) : text(k, m, context)
        }
    }

    public static func supports(_ o: Output, mode: Mode) -> Bool {
        edits(o, mode: mode, context: TextContext()) != nil
    }

    // MARK: - text mode

    static func text(_ k: Key, _ m: Mods, _ ctx: TextContext) -> [Edit]? {
        let noShift = m.subtracting(.shift)
        if let c = k.char {
            if noShift.isEmpty { return [.insert(String(m.contains(.shift) ? Keys.shifted(c) : c))] }
            if noShift == .meta {
                switch c {
                case "c": return [.copy]
                case "x": return [.cut]
                case "v": return [.paste]
                case "z": return [m.contains(.shift) ? .redo : .undo]
                default: return nil
                }
            }
            return nil
        }
        // Selection cannot be extended from a keyboard extension, so shift+motion is out.
        let motion = ["left", "rght", "up", "down", "home", "end", "pgup", "pgdn"].contains(k.name)
        if motion, m.contains(.shift) { return nil }
        switch (k.name, noShift) {
        case ("spc", []): return [.insert(" ")]
        case ("ret", []): return [.insert("\n")]
        case ("tab", []) where !m.contains(.shift): return [.insert("\t")]
        case ("bspc", []): return [.deleteBackward(1)]
        case ("bspc", .alt): return [.deleteBackward(max(1, wordBefore(ctx.before).count))]
        case ("bspc", .meta): return [.deleteBackward(max(1, lineBefore(ctx.before).count))]
        case ("del", []): return ctx.after.isEmpty ? [] : [.deleteForward(String(ctx.after.prefix(1)))]
        case ("del", .alt): return nonEmpty(.deleteForward(wordAfter(ctx.after)))
        case ("del", .meta): return nonEmpty(.deleteForward(lineAfter(ctx.after)))
        case ("left", []): return [.move(-(ctx.before.last.map { String($0).utf16.count } ?? 1))]
        case ("rght", []): return [.move(ctx.after.first.map { String($0).utf16.count } ?? 1)]
        case ("left", .alt): return [.move(-wordBefore(ctx.before).utf16.count)]
        case ("rght", .alt): return [.move(wordAfter(ctx.after).utf16.count)]
        case ("left", .meta), ("home", []): return [.move(-lineBefore(ctx.before).utf16.count)]
        case ("rght", .meta), ("end", []): return [.move(lineAfter(ctx.after).utf16.count)]
        case ("up", []): return [.move(-up(ctx))]
        case ("down", []): return [.move(down(ctx))]
        case ("up", .meta), ("pgup", []): return [.move(-ctx.before.utf16.count)]
        case ("down", .meta), ("pgdn", []): return [.move(ctx.after.utf16.count)]
        default: return nil
        }
    }

    static func nonEmpty(_ e: Edit) -> [Edit] {
        if case .deleteForward(let s) = e, s.isEmpty { return [] }
        return [e]
    }

    static func isWord(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "_" }

    /// The run `⌥⌫` deletes: trailing spaces, then a word or a run of punctuation.
    public static func wordBefore(_ s: String) -> Substring {
        var i = s.endIndex
        while i > s.startIndex, s[s.index(before: i)].isWhitespace { i = s.index(before: i) }
        guard i > s.startIndex else { return s[i...] }
        let word = isWord(s[s.index(before: i)])
        while i > s.startIndex {
            let c = s[s.index(before: i)]
            if c.isWhitespace || isWord(c) != word { break }
            i = s.index(before: i)
        }
        return s[i...]
    }

    static func wordAfter(_ s: String) -> String {
        String(String(wordBefore(String(s.reversed()))).reversed())
    }

    /// Up to the start of the line; at a line start, the newline itself.
    static func lineBefore(_ s: String) -> Substring {
        if s.last == "\n" { return s.suffix(1) }
        guard let nl = s.lastIndex(of: "\n") else { return s[...] }
        return s[s.index(after: nl)...]
    }

    static func lineAfter(_ s: String) -> String {
        if s.first == "\n" { return "\n" }
        return String(s.prefix { $0 != "\n" })
    }

    /// UTF-16 distance back to the same column on the previous line.
    static func up(_ ctx: TextContext) -> Int {
        let lines = ctx.before.split(separator: "\n", omittingEmptySubsequences: false)
        let cur = lines.last ?? ""
        guard lines.count >= 2 else { return cur.utf16.count }
        let prev = lines[lines.count - 2]
        let col = min(cur.count, prev.count)
        return cur.utf16.count + 1 + prev.dropFirst(col).utf16.count
    }

    /// UTF-16 distance forward to the same column on the next line.
    static func down(_ ctx: TextContext) -> Int {
        let col = (ctx.before.split(separator: "\n", omittingEmptySubsequences: false).last ?? "").count
        let lines = ctx.after.split(separator: "\n", omittingEmptySubsequences: false)
        let rest = lines.first ?? ""
        guard lines.count >= 2 else { return rest.utf16.count }
        return rest.utf16.count + 1 + lines[1].prefix(col).utf16.count
    }

    // MARK: - terminal mode

    static let esc = "\u{1b}"

    static func terminal(_ k: Key, _ m: Mods) -> [Edit]? {
        if m.contains(.meta) {
            switch (k.name, m.subtracting([.meta, .shift])) {
            case ("c", []): return [.copy]
            case ("z", []) where !m.contains(.shift): return [.insert("\u{1f}")]  // readline undo (^_)
            case ("x", []): return [.cut]
            case ("v", []): return [.paste]
            case ("bspc", []): return [.insert("\u{15}")]  // kill line (^U)
            default: return nil
            }
        }
        if m.contains(.fn) { return nil }
        guard let bytes = terminalBytes(k, m) else { return nil }
        guard m.contains(.alt) else { return [bytes] }
        // Alt is an ESC prefix, except on CSI sequences, which carry it in their parameter.
        switch bytes {
        case .deleteBackward: return [.insert(esc + "\u{7f}")]
        case .insert(let s) where !s.hasPrefix(esc + "["): return [.insert(esc + s)]
        default: return [bytes]
        }
    }

    /// Bytes for a key; alt only shows up in CSI modifier parameters.
    static func terminalBytes(_ k: Key, _ m: Mods) -> Edit? {
        if let c = k.char {
            let ch = m.contains(.shift) ? Keys.shifted(c) : c
            guard m.contains(.ctrl) else { return .insert(String(ch)) }
            return control(ch).map { .insert(String($0)) }
        }
        let csi = esc + "["
        switch k.name {
        case "spc": return .insert(m.contains(.ctrl) ? "\u{0}" : " ")
        case "ret": return .insert("\r")
        case "tab": return .insert(m.contains(.shift) ? csi + "Z" : "\t")
        case "bspc": return m.contains(.ctrl) ? .insert("\u{17}") : .deleteBackward(1)
        case "esc": return .insert(esc)
        case "up", "down", "rght", "left", "home", "end":
            let final = ["up": "A", "down": "B", "rght": "C", "left": "D", "home": "H", "end": "F"][k.name]!
            let p = param(m)
            return .insert(p == 1 ? csi + final : csi + "1;\(p)" + final)
        case "ins", "del", "pgup", "pgdn":
            let n = ["ins": 2, "del": 3, "pgup": 5, "pgdn": 6][k.name]!
            let p = param(m)
            return .insert(p == 1 ? csi + "\(n)~" : csi + "\(n);\(p)~")
        default:
            guard k.name.hasPrefix("f"), let n = Int(k.name.dropFirst()), (1...12).contains(n) else {
                return nil
            }
            if n <= 4 { return .insert(esc + "O" + ["P", "Q", "R", "S"][n - 1]) }
            let code = [15, 17, 18, 19, 20, 21, 23, 24][n - 5]
            return .insert(csi + "\(code)~")
        }
    }

    /// xterm modifier parameter: 1 + shift + 2*alt + 4*ctrl.
    static func param(_ m: Mods) -> Int {
        1 + (m.contains(.shift) ? 1 : 0) + (m.contains(.alt) ? 2 : 0) + (m.contains(.ctrl) ? 4 : 0)
    }

    static func control(_ c: Character) -> Character? {
        let lower = Character(c.lowercased())
        if lower >= "a", lower <= "z", let v = lower.asciiValue {
            return Character(UnicodeScalar(v - 96))
        }
        switch c {
        case "@", "2", " ": return "\u{0}"
        case "[", "3": return "\u{1b}"
        case "\\", "4": return "\u{1c}"
        case "]", "5": return "\u{1d}"
        case "^", "6": return "\u{1e}"
        case "_", "-", "7", "/": return "\u{1f}"
        case "?", "8": return "\u{7f}"
        default: return nil
        }
    }
}
