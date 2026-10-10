import Testing
import TotemCore

@testable import TotemUI

/// A text field: applies the controller's edits to the text around the cursor. Moves count
/// UTF-16 units, as `adjustTextPosition` does.
@MainActor final class Host {
  var before = ""
  var after = ""

  func apply(_ e: Edit) {
    switch e {
    case .insert(let s): before += s
    case .deleteBackward(let n): before.removeLast(min(n, before.count))
    case .move(let n) where n < 0:
      let b = Array(before.utf16)
      let k = min(-n, b.count)
      after = String(decoding: b.suffix(k), as: UTF16.self) + after
      before = String(decoding: b.dropLast(k), as: UTF16.self)
    case .move(let n):
      let a = Array(after.utf16)
      let k = min(n, a.count)
      before += String(decoding: a.prefix(k), as: UTF16.self)
      after = String(decoding: a.dropFirst(k), as: UTF16.self)
    default: break
    }
  }
}

@MainActor @Suite struct KeyboardControllerTests {
  let host = Host()
  let c: KeyboardController

  init() throws {
    let config = try Config.parse("(defsrc a b u d z) (deflayer x a b up down M-z)")
    c = KeyboardController(config: config, mode: .text)
    c.perform = { [host] in host.apply($0) }
    c.context = { [host] in TextContext(before: host.before, after: host.after) }
  }

  func tap(_ keys: Int...) {
    for k in keys {
      c.press(k)
      c.release(k)
    }
  }

  @Test func typesIntoTheHost() {
    tap(0, 1, 0)
    #expect(host.before == "aba")
  }

  @Test func undoTakesBackTheTyping() {
    tap(0, 1)
    tap(4)
    #expect(host.before == "")
  }

  @Test func lineDownResumesWhenTheContextChanges() async throws {
    host.before = "ab"
    host.after = "\nc😀d"
    tap(3)
    #expect(host.before == "ab\n")
    c.contextChanged()
    try await Task.sleep(for: .milliseconds(20))
    #expect(host.before == "ab\nc😀")
    #expect(host.after == "d")
  }

  @Test func queuedLineMovesKeepTheColumn() async throws {
    host.before = "ab"
    host.after = "\nc\nefg"
    tap(3, 3)
    // No context change reported: each hop waits for the fallback.
    try await Task.sleep(for: .milliseconds(500))
    #expect(host.before == "ab\nc\nef")
    #expect(host.after == "g")
  }

  /// A controller on `(tap-hold 20 40 a b)` over the same host.
  func tapHoldController() throws -> KeyboardController {
    let k = KeyboardController(
      config: try Config.parse("(defsrc a c) (deflayer x (tap-hold 20 40 a b) c)"), mode: .text)
    k.perform = { [host] in host.apply($0) }
    k.context = { [host] in TextContext(before: host.before, after: host.after) }
    return k
  }

  @Test func holdResolvesOnTheTimer() async throws {
    let k = try tapHoldController()
    k.press(0)
    #expect(host.before == "")
    try await Task.sleep(for: .milliseconds(150))
    #expect(host.before == "b")
    k.release(0)
  }

  @Test func releaseCancelsThePendingTimer() async throws {
    let k = try tapHoldController()
    k.press(0)
    k.release(0)
    #expect(host.before == "a")
    try await Task.sleep(for: .milliseconds(150))
    #expect(host.before == "a")
  }

  @Test func modeChangeIsReported() {
    var seen: [Mode] = []
    c.onModeChange = { seen.append($0) }
    c.mode = .terminal
    c.mode = .terminal
    #expect(seen == [.terminal])
  }
}
