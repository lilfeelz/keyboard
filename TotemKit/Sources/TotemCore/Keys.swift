/// Key names follow kanata's (`bspc`, `rght`, `grv`, ...), US layout. A key is
/// either printable (canonical name is its unshifted character) or special.

public struct Key: Hashable, Sendable, CustomStringConvertible {
    public let name: String
    public init(_ name: String) { self.name = name }
    public var description: String { name }

    /// Unshifted character for printable keys.
    public var char: Character? {
        name.count == 1 ? name.first : nil
    }

    public var isLetter: Bool {
        guard let c = char else { return false }
        return c >= "a" && c <= "z"
    }
}

public struct Mods: OptionSet, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let shift = Mods(rawValue: 1 << 0)
    public static let ctrl = Mods(rawValue: 1 << 1)
    public static let alt = Mods(rawValue: 1 << 2)
    public static let meta = Mods(rawValue: 1 << 3)
    public static let fn = Mods(rawValue: 1 << 4)

    /// ⇧⌃⌥⌘ glyphs, in macOS order.
    public var glyphs: String {
        var s = ""
        if contains(.fn) { s += "fn" }
        if contains(.ctrl) { s += "⌃" }
        if contains(.alt) { s += "⌥" }
        if contains(.shift) { s += "⇧" }
        if contains(.meta) { s += "⌘" }
        return s
    }
}

public enum Keys {
    static let shiftPairs: [Character: Character] = {
        let lower = Array("1234567890-=[]\\;',./`")
        let upper = Array("!@#$%^&*()_+{}|:\"<>?~")
        var m: [Character: Character] = [:]
        for (a, b) in zip(lower, upper) { m[a] = b }
        for c in "abcdefghijklmnopqrstuvwxyz" { m[c] = Character(c.uppercased()) }
        return m
    }()

    /// Shifted characters typed as keys (`!` is `S-1`), for kanata-style `S-` expansion.
    static let unshiftPairs: [Character: Character] = {
        var m: [Character: Character] = [:]
        for (a, b) in shiftPairs where !a.isLetter { m[b] = a }
        return m
    }()

    public static func shifted(_ c: Character) -> Character {
        shiftPairs[c] ?? c
    }

    static let aliases: [String: String] = [
        "grv": "`", "min": "-", "minus": "-", "eql": "=", "equal": "=",
        "lbrc": "[", "rbrc": "]", "bksl": "\\", "scln": ";", "semicolon": ";",
        "apos": "'", "quote": "'", "comm": ",", "comma": ",", "dot": ".", "period": ".",
        "slsh": "/", "slash": "/",
        "space": "spc", "enter": "ret", "return": "ret", "backspace": "bspc",
        "delete": "del", "escape": "esc", "right": "rght", "lft": "left", "pageup": "pgup",
        "pagedown": "pgdn", "insert": "ins",
    ]

    static let special: Set<String> = {
        var s: Set<String> = [
            "spc", "ret", "tab", "bspc", "del", "esc", "left", "rght", "up", "down",
            "home", "end", "pgup", "pgdn", "ins", "menu",
            // kanata names that exist but cannot do anything from an iOS keyboard.
            "mute", "volu", "vold", "pp", "next", "prev", "brup", "brdn", "bru", "brdown",
            "mctl", "sls", "dtn", "dnd", "prnt", "slck", "pause", "nlck",
            "🔅", "🔆", "◀◀", "▶⏸", "▶▶", "🔇", "🔉", "🔊",
        ]
        for n in 1...24 { s.insert("f\(n)") }
        return s
    }()

    static let modifiers: [String: Mods] = [
        "lsft": .shift, "rsft": .shift, "lshift": .shift, "rshift": .shift, "sft": .shift,
        "lctl": .ctrl, "rctl": .ctrl, "lctrl": .ctrl, "rctrl": .ctrl,
        "lalt": .alt, "ralt": .alt,
        "lmet": .meta, "rmet": .meta, "lmeta": .meta, "rmeta": .meta, "lgui": .meta,
        "rgui": .meta, "lcmd": .meta, "rcmd": .meta, "lwin": .meta, "rwin": .meta,
        "fn": .fn,
    ]

    static let prefixes: [(String, Mods)] = [
        ("RS-", .shift), ("RC-", .ctrl), ("RA-", .alt), ("AG-", .alt), ("RM-", .meta),
        ("S-", .shift), ("C-", .ctrl), ("A-", .alt), ("M-", .meta),
    ]

    /// Modifier bits a key name stands for, when it is a modifier key.
    public static func modifier(_ name: String) -> Mods? { modifiers[name] }

    /// Canonical key for a bare kanata key name (no modifier prefixes).
    public static func key(_ token: String) -> Key? {
        let name = aliases[token] ?? token
        if special.contains(name) { return Key(name) }
        if name.count == 1, let c = name.first, shiftPairs[c] != nil { return Key(name) }
        return nil
    }

    /// `M-S-z` -> (z, meta+shift). Also accepts a typed shifted symbol: `!` -> (1, shift).
    public static func chord(_ token: String) -> (Key, Mods)? {
        var rest = Substring(token)
        var mods: Mods = []
        outer: while true {
            for (p, m) in prefixes where rest.hasPrefix(p) && rest.count > p.count {
                mods.insert(m)
                rest = rest.dropFirst(p.count)
                continue outer
            }
            break
        }
        if let k = key(String(rest)) { return (k, mods) }
        if rest.count == 1, let c = rest.first, let base = unshiftPairs[c] {
            return (Key(String(base)), mods.union(.shift))
        }
        return nil
    }
}
