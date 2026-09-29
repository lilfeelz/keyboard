/// Undo and redo for what this keyboard did to the text. A keyboard cannot
/// reach the host app's undo stack, so it keeps its own: every edit it makes
/// is recorded with the text it removed, and undo plays it back in reverse.
///
/// Typing is grouped by word. Before undoing an insert the text is checked
/// against what was typed; if something else changed it (autocorrect, a paste
/// from the host's menu), the history is dropped rather than guessed at.
public struct History: Sendable {
  enum Entry: Sendable, Equatable {
    case insert(String)
    /// Removed before the cursor.
    case deleted(String)
    /// Removed after the cursor.
    case deletedForward(String)
    case move(Int)
  }

  private var undos: [Entry] = []
  private var redos: [Entry] = []
  private static let limit = 200

  public init() {}

  public var canUndo: Bool { !undos.isEmpty }
  public var canRedo: Bool { !redos.isEmpty }

  public mutating func clear() {
    undos = []
    redos = []
  }

  /// Note an edit about to be applied; `context` is the text before it.
  public mutating func record(_ e: Edit, context: TextContext) {
    let entry: Entry
    switch e {
    case .insert(let s): entry = .insert(s)
    case .deleteBackward(let n): entry = .deleted(String(context.before.suffix(n)))
    case .deleteForward(let s): entry = .deletedForward(s)
    case .move(let n): entry = .move(n)
    default: return
    }
    redos = []
    if let last = undos.last, let merged = Self.merge(last, entry) {
      undos[undos.count - 1] = merged
    } else {
      undos.append(entry)
      if undos.count > Self.limit { undos.removeFirst() }
    }
  }

  static func merge(_ a: Entry, _ b: Entry) -> Entry? {
    switch (a, b) {
    case (.insert(let p), .insert(let s)):
      // A new group starts at a newline or where a word follows whitespace.
      if s.contains("\n") || p.hasSuffix("\n") { return nil }
      if p.last?.isWhitespace == true, s.first?.isWhitespace == false { return nil }
      return .insert(p + s)
    case (.deleted(let p), .deleted(let s)): return .deleted(s + p)
    case (.deletedForward(let p), .deletedForward(let s)): return .deletedForward(p + s)
    case (.move(let p), .move(let n)): return .move(p + n)
    default: return nil
    }
  }

  public mutating func undo(context: TextContext) -> [Edit] {
    guard let e = undos.popLast() else { return [] }
    let edits: [Edit]
    switch e {
    case .insert(let s):
      guard context.before.hasSuffix(s) else {
        clear()
        return []
      }
      edits = [.deleteBackward(s.count)]
    case .deleted(let s): edits = [.insert(s)]
    case .deletedForward(let s): edits = [.insert(s), .move(-s.utf16.count)]
    case .move(let n): edits = [.move(-n)]
    }
    redos.append(e)
    return edits
  }

  public mutating func redo(context: TextContext) -> [Edit] {
    guard let e = redos.popLast() else { return [] }
    let edits: [Edit]
    switch e {
    case .insert(let s): edits = [.insert(s)]
    case .deleted(let s):
      guard context.before.hasSuffix(s) else {
        clear()
        return []
      }
      edits = [.deleteBackward(s.count)]
    case .deletedForward(let s):
      guard context.after.hasPrefix(s) else {
        clear()
        return []
      }
      edits = [.deleteForward(s)]
    case .move(let n): edits = [.move(n)]
    }
    undos.append(e)
    return edits
  }
}
