/// What a key shows: derived from its action, the shift state and the mode, so
/// the config never needs separate labels.

public struct KeyCap: Sendable, Equatable {
    public enum Style: Sendable, Equatable {
        case char
        case special
        case mod
        case layer
        /// The action cannot do anything here (Cmd chords in text mode, F-keys, media).
        case inert
        case blank
    }

    public var main: String
    public var hint: String?
    /// SF Symbol name, drawn instead of `main` when set.
    public var symbol: String?
    public var style: Style

    public init(_ main: String, hint: String? = nil, symbol: String? = nil, style: Style) {
        self.main = main
        self.hint = hint
        self.symbol = symbol
        self.style = style
    }

    public static let blank = KeyCap("", style: .blank)

    public static func of(
        _ a: Action, shifted: Bool, mode: Mode
    ) -> KeyCap {
        switch a {
        case .none, .trans:
            return .blank
        case .key(let k, let m):
            return key(k, m, shifted: shifted, mode: mode)
        case .mod(let m):
            return KeyCap(m.glyphs, style: .mod)
        case .text(let s):
            return KeyCap(s, style: .char)
        case .tapHold(let th):
            var cap = of(th.tap, shifted: shifted, mode: mode)
            let hold = of(th.hold, shifted: false, mode: mode)
            if hold.style != .blank, hold.style != .inert { cap.hint = hold.symbol == nil ? hold.main : nil }
            return cap
        case .oneShot(_, let inner):
            var cap = of(inner, shifted: shifted, mode: mode)
            if cap.style == .char || cap.style == .special { cap.style = .mod }
            return cap
        case .layerHold(let n), .layerSwitch(let n):
            return KeyCap(n, style: .layer)
        case .fork(let l, let r, let c):
            guard c.involvesShift else { return of(l, shifted: shifted, mode: mode) }
            var cap = of(shifted ? r : l, shifted: shifted, mode: mode)
            let other = of(shifted ? l : r, shifted: false, mode: mode)
            if cap.hint == nil, other.main != cap.main, other.style != .inert { cap.hint = other.main }
            return cap
        case .unshift(let inner):
            return of(inner, shifted: false, mode: mode)
        case .multi(let as_):
            let mods = as_.reduce(Mods()) { acc, x in
                if case .mod(let m) = x { acc.union(m) } else { acc }
            }
            let rest = as_.filter {
                if case .mod = $0 { return false }
                if case .layerSwitch = $0 { return false }
                return true
            }
            guard let first = rest.first else { return KeyCap(mods.glyphs, style: .mod) }
            if case .unshift(.key(let k, let m)) = first {
                return key(k, m.union(mods), shifted: false, mode: mode)
            }
            if case .key(let k, let m) = first { return key(k, m.union(mods), shifted: false, mode: mode) }
            return of(first, shifted: shifted, mode: mode)
        case .macro(let as_):
            let parts = as_.map { of($0, shifted: false, mode: mode) }
            if parts.allSatisfy({ $0.style == .char }) {
                return KeyCap(parts.map(\.main).joined(), style: .char)
            }
            return KeyCap(parts.first?.main ?? "", style: parts.first?.style ?? .blank)
        case .capsWord:
            return KeyCap("caps", style: .mod)
        case .capsLock:
            return KeyCap("⇪", style: .mod)
        case .switchCases(let cases):
            let c = cases.first { holds($0.condition, mode: mode) } ?? cases.first
            return c.map { of($0.action, shifted: shifted, mode: mode) } ?? .blank
        case .repeatLast:
            return KeyCap("rpt", style: .special)
        case .swipe(_, let inner):
            return of(inner, shifted: shifted, mode: mode)
        case .system(let s):
            switch s {
            case .nextKeyboard: return KeyCap("", symbol: "globe", style: .special)
            case .dismiss: return KeyCap("", symbol: "keyboard.chevron.compact.down", style: .special)
            case .toggleTerminal: return KeyCap(">_", style: .special)
            case .copy: return KeyCap("copy", style: .special)
            case .cut: return KeyCap("cut", style: .special)
            case .paste: return KeyCap("paste", style: .special)
            case .undo: return KeyCap("undo", style: .special)
            case .redo: return KeyCap("redo", style: .special)
            }
        }
    }

    /// Whether a condition holds for drawing: only the mode is known, not what is held.
    static func holds(_ c: Condition, mode: Mode) -> Bool {
        switch c {
        case .always: true
        case .mode(let m): m == mode
        case .or(let cs): cs.contains { holds($0, mode: mode) }
        case .and(let cs): cs.allSatisfy { holds($0, mode: mode) }
        case .not(let c): !holds(c, mode: mode)
        default: false
        }
    }

    static let glyphs: [String: String] = [
        "spc": "", "ret": "⏎", "tab": "⇥", "bspc": "⌫", "del": "⌦", "esc": "esc",
        "left": "◀", "rght": "▶", "up": "▲", "down": "▼",
        "home": "home", "end": "end", "pgup": "pgup", "pgdn": "pgdn", "ins": "ins",
        "vold": "vol-", "volu": "vol+", "brdn": "bri-", "brup": "bri+",
    ]

    static func key(_ k: Key, _ m: Mods, shifted: Bool, mode: Mode) -> KeyCap {
        let ok = Translator.supports(.stroke(k, m.union(shifted && k.char != nil ? .shift : [])), mode: mode)
        if let c = k.char {
            let bare = m.subtracting(.shift)
            let shift = m.contains(.shift) || (shifted && bare.isEmpty)
            let ch = String(shift ? Keys.shifted(c) : c)
            if bare.isEmpty { return KeyCap(ch, style: ok ? .char : .inert) }
            let label = m.contains(.shift) && Keys.shifted(c) != Character(c.uppercased())
                ? bare.glyphs + ch : m.glyphs + c.uppercased()
            return KeyCap(label, style: ok ? .special : .inert)
        }
        let name = glyphs[k.name] ?? k.name
        return KeyCap(m.glyphs + name, style: ok ? .special : .inert)
    }
}
