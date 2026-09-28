/// Reader for kanata's s-expression syntax: `;;` line comments, `#| |#` block
/// comments, `"strings"`, `r#"raw strings"#`, and atoms that run to the next
/// whitespace or paren. A lone `;` is an atom (the semicolon key), not a comment.

public struct SourcePos: Sendable, Equatable, CustomStringConvertible {
    public var line: Int
    public var col: Int
    public var description: String { "\(line):\(col)" }
}

public struct ConfigError: Error, Equatable, CustomStringConvertible {
    public var message: String
    public var pos: SourcePos?

    public init(_ message: String, at pos: SourcePos? = nil) {
        self.message = message
        self.pos = pos
    }

    public var description: String {
        pos.map { "\($0): \(message)" } ?? message
    }
}

public indirect enum SExpr: Sendable, Equatable {
    case atom(String, SourcePos)
    case string(String, SourcePos)
    case list([SExpr], SourcePos)

    public var pos: SourcePos {
        switch self {
        case .atom(_, let p), .string(_, let p), .list(_, let p): p
        }
    }

    public var atom: String? {
        if case .atom(let s, _) = self { s } else { nil }
    }

    public var list: [SExpr]? {
        if case .list(let l, _) = self { l } else { nil }
    }

    /// Head atom of a list form, e.g. `tap-hold` in `(tap-hold ...)`.
    public var head: String? { list?.first?.atom }
}

public enum Reader {
    public static func read(_ text: String) throws -> [SExpr] {
        var r = Scanner(Array(text))
        var out: [SExpr] = []
        while let e = try r.next() {
            out.append(e)
        }
        return out
    }
}

private struct Scanner {
    let chars: [Character]
    var i = 0
    var line = 1
    var col = 1

    init(_ chars: [Character]) { self.chars = chars }

    var pos: SourcePos { SourcePos(line: line, col: col) }

    func peek(_ k: Int = 0) -> Character? {
        i + k < chars.count ? chars[i + k] : nil
    }

    mutating func advance() {
        if chars[i] == "\n" {
            line += 1
            col = 1
        } else {
            col += 1
        }
        i += 1
    }

    mutating func skipTrivia() throws {
        while let c = peek() {
            if c.isWhitespace {
                advance()
            } else if c == ";", peek(1) == ";" {
                while let c = peek(), c != "\n" { advance() }
            } else if c == "#", peek(1) == "|" {
                let start = pos
                advance()
                advance()
                while true {
                    guard let c = peek() else { throw ConfigError("unterminated #| comment", at: start) }
                    if c == "|", peek(1) == "#" {
                        advance()
                        advance()
                        break
                    }
                    advance()
                }
            } else {
                return
            }
        }
    }

    /// Next top-level form, or nil at end of input.
    mutating func next() throws -> SExpr? {
        try skipTrivia()
        guard let c = peek() else { return nil }
        if c == ")" { throw ConfigError("unexpected )", at: pos) }
        return try expr()
    }

    mutating func expr() throws -> SExpr {
        try skipTrivia()
        let start = pos
        guard let c = peek() else { throw ConfigError("unexpected end of input", at: start) }
        switch c {
        case "(":
            advance()
            var items: [SExpr] = []
            while true {
                try skipTrivia()
                guard let c = peek() else { throw ConfigError("unclosed (", at: start) }
                if c == ")" {
                    advance()
                    return .list(items, start)
                }
                items.append(try expr())
            }
        case "\"":
            advance()
            return .string(try until("\"", from: start), start)
        case "r" where peek(1) == "#" && peek(2) == "\"":
            advance()
            advance()
            advance()
            return .string(try until("\"#", from: start), start)
        default:
            var s = ""
            while let c = peek(), !c.isWhitespace, c != "(", c != ")" {
                s.append(c)
                advance()
            }
            return .atom(s, start)
        }
    }

    mutating func until(_ end: String, from start: SourcePos) throws -> String {
        let e = Array(end)
        var s = ""
        while true {
            guard peek() != nil else { throw ConfigError("unterminated string", at: start) }
            if (0..<e.count).allSatisfy({ peek($0) == e[$0] }) {
                for _ in e { advance() }
                return s
            }
            s.append(chars[i])
            advance()
        }
    }
}
