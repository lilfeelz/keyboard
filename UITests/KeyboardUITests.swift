import XCTest

/// Drives the in-app keyboard preview through real touches.
final class KeyboardUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--try"]
        app.launch()
    }

    func key(_ label: String) -> XCUIElement {
        app.otherElements.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// A key's centre, resolved now, so later taps skip the (slow) element query.
    func point(_ label: String) -> XCUICoordinate {
        let f = key(label).frame
        return app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: f.midX, dy: f.midY))
    }

    var buffer: String { app.staticTexts["buffer"].label }

    func testTypingTapHoldAndOneShot() {
        for k in ["h", "i"] { key(k).tap() }
        XCTAssertEqual(buffer, "hi▏")

        // one-shot shift, then a letter
        let shift = point("⇧")
        let a = point("a")
        shift.tap()
        a.tap()
        XCTAssertEqual(buffer, "hiA▏")

        // tap the backspace thumb
        key("⌫").tap()
        XCTAssertEqual(buffer, "hi▏")

        // holding it deletes (and would repeat)
        key("⌫").press(forDuration: 0.5)
        XCTAssertEqual(buffer, "h▏")

        // the nav key beside it: tap for one key on the layer (q is 1)
        let nav = point("left"), q = point("q")
        nav.tap()
        q.tap()
        XCTAssertEqual(buffer, "h1▏")

        // terminal mode: esc goes out as ESC
        key(">_").tap()
        XCTAssertEqual(app.staticTexts["mode"].label, "terminal")
        key("esc").tap()
        XCTAssertEqual(buffer, "h1^[▏")
    }

    func drag(_ label: String, dx: CGFloat, dy: CGFloat = 0) {
        let from = point(label)
        from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: dx, dy: dy)))
    }

    func testSwipeDeleteAndCursor() {
        for k in ["o", "n", "e", "spc", "t", "w", "o"] {
            k == "spc" ? app.coordinate(withNormalizedOffset: .zero).withOffset(spaceCentre).tap() : key(k).tap()
        }
        XCTAssertEqual(buffer, "one two▏")

        // backspace thumb dragged one word left, lifted: "two" goes
        drag("⌫", dx: -24)
        XCTAssertEqual(buffer, "one ▏")

        // esc thumb (hide-keyboard in text mode) dragged two characters left
        drag(escText, dx: -30)
        XCTAssertEqual(buffer, "on▏e ")
    }

    func testVerticalSwipeMovesByLine() {
        for k in ["a", "b", "c", "⏎", "d", "e"] { key(k).tap() }
        XCTAssertEqual(buffer, "abc\nde▏")
        drag(escText, dx: 0, dy: -30)
        XCTAssertEqual(buffer, "ab▏c\nde")
        drag(escText, dx: 0, dy: 30)
        XCTAssertEqual(buffer, "abc\nde▏")
    }

    /// The esc thumb hides the keyboard in text mode and is labelled with its symbol.
    let escText = "keyboard.chevron.compact.down"

    /// The space bar has no label; it sits between the two thumb keys.
    var spaceCentre: CGVector {
        let l = key("⌫").frame, r = key(escText).frame
        return CGVector(dx: (l.maxX + r.minX) / 2, dy: l.midY)
    }
}
