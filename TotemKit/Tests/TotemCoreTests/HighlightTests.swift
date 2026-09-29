import Testing

@testable import TotemCore

@Suite struct HighlightTests {
    /// Each span as its source text and kind, for readable expectations.
    func tokens(_ s: String) -> [String] {
        let u = Array(s.utf16)
        return Highlight.spans(s).map {
            "\($0.kind):" + String(decoding: u[$0.start..<$0.start + $0.length], as: UTF16.self)
        }
    }

    @Test func forms() {
        #expect(
            tokens("(defalias tbf (tap-hold $tap-time 170 tab @nav))") == [
                "paren:(", "head:defalias", "paren:(", "head:tap-hold", "variable:$tap-time",
                "alias:@nav", "paren:)", "paren:)",
            ])
    }

    @Test func commentsAndStrings() {
        #expect(
            tokens(";; hi\n(text \"a b\") #| x\ny |# ;") == [
                "comment:;; hi", "paren:(", "head:text", "string:\"a b\"", "paren:)",
                "comment:#| x\ny |#",
            ])
        #expect(tokens("r#\"q\"\"#") == ["string:r#\"q\"\"#"])
    }

    @Test func loneSigilsAreKeys() {
        #expect(tokens("(defalias @ S-2 $ S-4)") == ["paren:(", "head:defalias", "paren:)"])
    }

    @Test func unterminatedRunsToEnd() {
        #expect(tokens("(a \"open") == ["paren:(", "head:a", "string:\"open"])
        #expect(tokens("#| open") == ["comment:#| open"])
    }

    @Test func offsetsAreUTF16() {
        let s = "(text \"€👍\") @x"
        let alias = Highlight.spans(s).last!
        #expect(alias.kind == .alias)
        #expect(alias.start == s.utf16.count - 2)
    }
}
