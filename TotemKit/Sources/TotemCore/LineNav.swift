/// Up and down by logical lines (between `\n`s), the only kind a keyboard can
/// see: it gets no layout, so soft-wrapped lines are one long line to it.
///
/// A move takes two hops. The host usually cuts `documentContextBeforeInput`
/// off at a line break, so the line above is not visible until the cursor is
/// on it: first hop over the line break, let the host refresh its context,
/// then read the new line and step to the column.
public enum LineNav {
  public struct Hop: Sendable, Equatable {
    public var move: Int
    /// The column the cursor was on, in characters.
    public var column: Int
    /// Whether a line break was crossed, i.e. there is a second hop.
    public var crossed: Bool
  }

  /// First hop: to the end of the previous line (up) or the start of the next one (down).
  public static func leave(_ direction: Int, _ ctx: TextContext) -> Hop {
    let cur = currentLineBefore(ctx.before)
    if direction < 0 {
      // With no line break in view the context may just be cut short; step
      // over the break anyway, the host clamps at the start of the text.
      return Hop(move: -(cur.utf16.count + 1), column: cur.count, crossed: true)
    }
    let rest = ctx.after.prefix { $0 != "\n" }
    guard ctx.after.contains("\n") else {
      return Hop(move: rest.utf16.count, column: cur.count, crossed: false)
    }
    return Hop(move: rest.utf16.count + 1, column: cur.count, crossed: true)
  }

  /// Second hop, once the context shows the new line: to `column` or its end.
  public static func arrive(_ direction: Int, column: Int, _ ctx: TextContext) -> Int {
    if direction < 0 {
      let line = currentLineBefore(ctx.before)
      return -line.dropFirst(column).utf16.count
    }
    return ctx.after.prefix { $0 != "\n" }.prefix(column).utf16.count
  }

  static func currentLineBefore(_ s: String) -> Substring {
    guard let nl = s.lastIndex(of: "\n") else { return s[...] }
    return s[s.index(after: nl)...]
  }
}
