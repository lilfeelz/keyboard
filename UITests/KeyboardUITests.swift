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

        // holding it resolves to the left layer instead, so nothing is deleted
        key("⌫").press(forDuration: 0.5)
        XCTAssertEqual(buffer, "hi▏")

        // terminal mode: esc goes out as ESC
        key(">_").tap()
        XCTAssertEqual(app.staticTexts["mode"].label, "terminal")
        key("esc").tap()
        XCTAssertEqual(buffer, "hi^[▏")
    }
}
