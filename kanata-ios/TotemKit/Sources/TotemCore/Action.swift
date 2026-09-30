/// What a key does, parsed from kanata syntax.

public indirect enum Action: Sendable, Equatable {
  /// `XX`: swallow the key.
  case none
  /// `_`: fall through to the layer below.
  case trans
  /// A keystroke with explicit modifiers (`M-S-z`).
  case key(Key, Mods)
  /// A modifier key (`lsft`, `rmet`), active while held.
  case mod(Mods)
  /// `(unicode "x")` / `(text "...")` / a bare string: inserted verbatim.
  case text(String)
  case tapHold(TapHold)
  case oneShot(timeout: Int, action: Action)
  case layerHold(String)
  case layerSwitch(String)
  /// `(fork left right (keys))`: right when any of keys is held.
  case fork(Action, Action, Condition)
  case unshift(Action)
  case multi([Action])
  case macro([Action])
  case capsWord(CapsWord)
  case capsLock
  case switchCases([SwitchCase])
  /// `rpt` / `rpt-any`: redo the last key's output.
  case repeatLast
  case system(SystemAction)
  /// `(swipe-cursor a)` / `(swipe-delete a)`: `a` on tap and hold; dragging the
  /// key moves the cursor or deletes instead.
  case swipe(SwipeKind, Action)
}

public enum SwipeKind: Sendable, Equatable {
  /// Horizontal drag moves by characters, vertical by lines.
  case cursor
  /// Drag left pulls the cursor back character by character, drag right
  /// gives them back; lifting deletes what was covered.
  case delete
}

public struct TapHold: Sendable, Equatable {
  public enum Kind: Sendable, Equatable {
    /// Resolves on timeout or release only.
    case plain
    /// Any other key press resolves to hold.
    case press
    /// Another key pressed and released resolves to hold.
    case release
  }

  public var kind: Kind
  /// Re-press within this window after a tap repeats the tap (kanata quick-tap).
  public var tapTime: Int
  public var holdTime: Int
  public var tap: Action
  public var hold: Action
}

public struct CapsWord: Sendable, Equatable {
  public var timeout: Int
  public var shifted: Set<Key>
  public var continuing: Set<Key>
  public var toggle: Bool

  public static func standard(timeout: Int, toggle: Bool) -> CapsWord {
    let letters = Set("abcdefghijklmnopqrstuvwxyz".map { Key(String($0)) })
    let cont = Set(
      ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "bspc", "del"].map(Key.init))
    return CapsWord(timeout: timeout, shifted: letters, continuing: cont, toggle: toggle)
  }
}

public indirect enum Condition: Sendable, Equatable {
  case always
  /// A modifier (`lsft`) or defsrc key name currently held.
  case held(String)
  case layer(String)
  case baseLayer(String)
  /// `(mode text)` / `(mode terminal)`: which mode the keyboard is in.
  case mode(Mode)
  case and([Condition])
  case or([Condition])
  case not(Condition)

  /// Whether this condition looks at shift, i.e. whether a fork flips on shift.
  var involvesShift: Bool {
    switch self {
    case .held(let n): Keys.modifier(n) == .shift
    case .and(let cs), .or(let cs): cs.contains { $0.involvesShift }
    case .not(let c): c.involvesShift
    default: false
    }
  }
}

public struct SwitchCase: Sendable, Equatable {
  public var condition: Condition
  public var action: Action
  public var continues: Bool
}

/// Things only an iOS keyboard does.
public enum SystemAction: String, Sendable, Equatable, CaseIterable {
  /// The globe key; Apple requires one when the device has no other way to switch.
  case nextKeyboard = "nextkbd"
  case dismiss
  /// Toggle terminal mode: control codes and escape sequences instead of text editing.
  case toggleTerminal = "term"
  case copy
  case cut
  case paste
  case undo
  case redo
}
