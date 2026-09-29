/// Token spans for colouring config source, by the reader's rules (see `Reader`).
/// Unlike the reader it never fails: unterminated strings and comments run to the
/// end, so half-typed input still colours.
public enum Highlight {
    public enum Kind: Sendable, Equatable {
        /// `;;` line and `#| |#` block comments.
        case comment
        case string
        case paren
        /// First atom of a list: `defalias`, `tap-hold`, ...
        case head
        /// `@name` alias reference.
        case alias
        /// `$name` variable reference.
        case variable
    }

    public struct Span: Sendable, Equatable {
        /// UTF-16 offsets, as NSRange and UITextView count them.
        public var start: Int
        public var length: Int
        public var kind: Kind
    }

    public static func spans(_ text: String) -> [Span] {
        let chars = Array(text)
        var out: [Span] = []
        var i = 0
        var at = 0  // UTF-16 offset of chars[i]
        var head = false

        func peek(_ k: Int = 0) -> Character? { i + k < chars.count ? chars[i + k] : nil }
        func step() {
            at += chars[i].utf16.count
            i += 1
        }
        func run(_ kind: Kind, _ body: () -> Void) {
            let start = at
            body()
            out.append(Span(start: start, length: at - start, kind: kind))
        }
        func until(_ end: String) {
            let e = Array(end)
            while peek() != nil {
                if (0..<e.count).allSatisfy({ peek($0) == e[$0] }) {
                    for _ in e { step() }
                    return
                }
                step()
            }
        }

        while let c = peek() {
            if c.isWhitespace {
                step()
            } else if c == ";", peek(1) == ";" {
                run(.comment) { while let c = peek(), c != "\n" { step() } }
            } else if c == "#", peek(1) == "|" {
                run(.comment) {
                    step()
                    step()
                    until("|#")
                }
            } else if c == "(" || c == ")" {
                run(.paren) { step() }
                head = c == "("
            } else if c == "\"" {
                run(.string) {
                    step()
                    until("\"")
                }
                head = false
            } else if c == "r", peek(1) == "#", peek(2) == "\"" {
                run(.string) {
                    for _ in 0..<3 { step() }
                    until("\"#")
                }
                head = false
            } else {
                let start = at
                while let c = peek(), !c.isWhitespace, c != "(", c != ")" { step() }
                // A lone @ or $ is the key itself, not a reference.
                let ref = at - start > 1
                let kind: Kind? = head ? .head : ref && c == "@" ? .alias : ref && c == "$" ? .variable : nil
                if let kind { out.append(Span(start: start, length: at - start, kind: kind)) }
                head = false
            }
        }
        return out
    }
}
