import Foundation

/// A parsed keyboard config: kanata's `defcfg defvar defalias defsrc deflayer
/// defchordsv2`, with `defsrc` describing touch geometry instead of a physical
/// board. Each line of `defsrc` is a row; `gap` (or `gap:0.5`) leaves space and
/// `name:1.5` makes a key wider. Layers list their keys in the same order,
/// without the gaps.

public struct SrcKey: Sendable, Equatable {
  public var name: String
  public var row: Int
  /// Left edge, in key units from the row start.
  public var x: Double
  public var width: Double
}

public struct Layer: Sendable, Equatable {
  public var name: String
  public var actions: [Action]
}

public struct Chord: Sendable, Equatable {
  public var keys: Set<Int>
  public var action: Action
  public var timeout: Int
  public var releaseOnFirst: Bool
  public var disabledLayers: Set<String>
}

public struct Options: Sendable, Equatable {
  public var repeatDelay = 400
  public var repeatInterval = 50
  /// Start in terminal mode (control codes, escape sequences).
  public var terminal = false
  public var heightPhone = 240.0
  public var heightTablet = 320.0
}

public struct Config: Sendable, Equatable {
  public var keys: [SrcKey]
  /// Width of each row in key units, gaps included.
  public var rowWidths: [Double]
  public var rows: Int { rowWidths.count }
  /// Widest row, in key units.
  public var width: Double { rowWidths.max() ?? 0 }
  public var layers: [Layer]
  public var chords: [Chord]
  /// The defsrc key itself, used when `_` falls through every layer.
  public var defaults: [Action]
  public var options: Options
  public var warnings: [String]

  public func layerIndex(named name: String) -> Int? {
    layers.firstIndex { $0.name == name }
  }

  public static func parse(_ text: String) throws -> Config {
    var p = ConfigParser()
    return try p.parse(Reader.read(text))
  }

  public static let `default`: Config = {
    do {
      return try parse(defaultSource)
    } catch {
      fatalError("bundled default config does not parse: \(error)")
    }
  }()
}

private struct ConfigParser {
  var vars: [String: SExpr] = [:]
  var aliasExprs: [String: SExpr] = [:]
  var aliasCache: [String: Action] = [:]
  var resolving: [String] = []
  var srcNames: [String: Int] = [:]
  var layerRefs: [(String, SourcePos)] = []
  var warnings: [String] = []

  mutating func parse(_ forms: [SExpr]) throws -> Config {
    var options = Options()
    var srcForm: SExpr?
    var layerForms: [SExpr] = []
    var chordForms: [SExpr] = []

    for f in forms {
      guard let items = f.list, let head = f.head else {
        throw ConfigError("expected a (form) at top level", at: f.pos)
      }
      let args = Array(items.dropFirst())
      switch head {
      case "defcfg":
        try parseCfg(args, into: &options, at: f.pos)
      case "defvar":
        try pairs(args, at: f.pos) { k, v in vars[k] = try subst(v) }
      case "defalias":
        try pairs(args, at: f.pos) { k, v in aliasExprs[k] = v }
      case "defsrc":
        if srcForm != nil { throw ConfigError("defsrc defined twice", at: f.pos) }
        srcForm = f
      case "deflayer":
        layerForms.append(f)
      case "defchordsv2", "defchordsv2-experimental":
        chordForms.append(f)
      default:
        warnings.append("\(f.pos): \(head) is not supported here and was skipped")
      }
    }

    guard let srcForm else { throw ConfigError("missing defsrc") }
    let (keys, rowWidths) = try parseSrc(srcForm)
    for (i, k) in keys.enumerated() {
      if srcNames[k.name] != nil {
        throw ConfigError("defsrc key \(k.name) appears twice", at: srcForm.pos)
      }
      srcNames[k.name] = i
    }
    aliasExprs = try aliasExprs.mapValues { try subst($0) }

    var layers: [Layer] = []
    for f in layerForms {
      let items = f.list!.dropFirst()
      guard let name = items.first?.atom else {
        throw ConfigError("deflayer needs a name", at: f.pos)
      }
      if layers.contains(where: { $0.name == name }) {
        throw ConfigError("layer \(name) defined twice", at: f.pos)
      }
      let body = Array(items.dropFirst())
      guard body.count == keys.count else {
        throw ConfigError(
          "layer \(name) has \(body.count) keys, defsrc has \(keys.count)", at: f.pos)
      }
      layers.append(Layer(name: name, actions: try body.map { try action(subst($0)) }))
    }
    guard !layers.isEmpty else { throw ConfigError("no deflayer") }

    var chords: [Chord] = []
    for f in chordForms {
      chords += try parseChords(Array(f.list!.dropFirst()), at: f.pos)
    }

    let names = Set(layers.map(\.name))
    for (name, pos) in layerRefs where !names.contains(name) {
      throw ConfigError("unknown layer \(name)", at: pos)
    }
    for c in chords {
      for l in c.disabledLayers where !names.contains(l) {
        warnings.append("chord disables unknown layer \(l)")
      }
    }

    var defaults: [Action] = []
    for k in keys {
      defaults.append((try? atomAction(k.name, at: srcForm.pos)) ?? .none)
    }
    return Config(
      keys: keys, rowWidths: rowWidths, layers: layers, chords: chords,
      defaults: defaults, options: options, warnings: warnings)
  }

  // MARK: - top-level forms

  func pairs(_ args: [SExpr], at pos: SourcePos, _ body: (String, SExpr) throws -> Void) throws {
    guard args.count % 2 == 0 else { throw ConfigError("expected name/value pairs", at: pos) }
    for i in stride(from: 0, to: args.count, by: 2) {
      guard let k = args[i].atom else { throw ConfigError("expected a name", at: args[i].pos) }
      try body(k, args[i + 1])
    }
  }

  mutating func parseCfg(_ args: [SExpr], into o: inout Options, at pos: SourcePos) throws {
    try pairs(args, at: pos) { k, v in
      let v = try subst(v)
      switch k {
      case "repeat-delay": o.repeatDelay = try int(v)
      case "repeat-interval": o.repeatInterval = try int(v)
      case "terminal-mode": o.terminal = v.atom == "yes"
      case "height-phone": o.heightPhone = Double(try int(v))
      case "height-tablet": o.heightTablet = Double(try int(v))
      default: break  // kanata's own options mean nothing on a touch screen
      }
    }
  }

  func parseSrc(_ f: SExpr) throws -> ([SrcKey], [Double]) {
    let atoms = f.list!.dropFirst()
    var keys: [SrcKey] = []
    var rowWidths: [Double] = []
    var line = -1
    for a in atoms {
      guard let tok = a.atom else { throw ConfigError("defsrc takes key names", at: a.pos) }
      if a.pos.line != line {
        line = a.pos.line
        rowWidths.append(0)
      }
      var name = tok
      var width = 1.0
      if let colon = tok.lastIndex(of: ":"), colon != tok.startIndex,
        let w = Double(tok[tok.index(after: colon)...])
      {
        name = String(tok[..<colon])
        width = w
      }
      let row = rowWidths.count - 1
      if name != "gap" {
        keys.append(SrcKey(name: name, row: row, x: rowWidths[row], width: width))
      }
      rowWidths[row] += width
    }
    guard !keys.isEmpty else { throw ConfigError("defsrc is empty", at: f.pos) }
    return (keys, rowWidths)
  }

  mutating func parseChords(_ args: [SExpr], at pos: SourcePos) throws -> [Chord] {
    guard args.count % 5 == 0 else {
      throw ConfigError(
        "defchordsv2 entries are (keys) action timeout release-behaviour (disabled-layers)",
        at: pos)
    }
    var out: [Chord] = []
    for i in stride(from: 0, to: args.count, by: 5) {
      let e = try (0..<5).map { try subst(args[i + $0]) }
      guard let ks = e[0].list, ks.count >= 2 else {
        throw ConfigError("a chord needs two or more keys", at: e[0].pos)
      }
      let idx = try ks.map { k -> Int in
        guard let n = k.atom, let i = srcNames[n] else {
          throw ConfigError("chord key is not in defsrc", at: k.pos)
        }
        return i
      }
      let release: Bool
      switch e[3].atom {
      case "all-released": release = false
      case "first-release": release = true
      default: throw ConfigError("expected all-released or first-release", at: e[3].pos)
      }
      guard let dis = e[4].list else { throw ConfigError("expected (layers)", at: e[4].pos) }
      out.append(
        Chord(
          keys: Set(idx), action: try action(e[1]), timeout: try int(e[2]),
          releaseOnFirst: release, disabledLayers: Set(dis.compactMap(\.atom))))
    }
    return out
  }

  // MARK: - vars and numbers

  func subst(_ e: SExpr) throws -> SExpr {
    switch e {
    case .atom(let s, let p) where s.hasPrefix("$") && s.count > 1:
      guard let v = vars[String(s.dropFirst())] else {
        throw ConfigError("unknown variable \(s)", at: p)
      }
      return v
    case .list(let items, let p):
      return .list(try items.map(subst), p)
    default:
      return e
    }
  }

  func int(_ e: SExpr) throws -> Int {
    guard let s = e.atom, let n = Int(s) else { throw ConfigError("expected a number", at: e.pos) }
    return n
  }

  // MARK: - actions

  mutating func action(_ e: SExpr) throws -> Action {
    switch e {
    case .string(let s, _):
      return .text(s)
    case .atom(let s, let p):
      return try atomAction(s, at: p)
    case .list(let items, let p):
      return try listAction(items, at: p)
    }
  }

  mutating func atomAction(_ s: String, at p: SourcePos) throws -> Action {
    switch s {
    case "_": return .trans
    case "XX", "✗", "∅", "•": return .none
    case "rpt", "rpt-any", "repeat": return .repeatLast
    case "caps": return .capsLock
    case "lrld", "lrld-next", "lrld-prev", "lrpv", "lrnx":
      warnings.append("\(p): \(s) does nothing here; edit the config in the app")
      return .none
    default: break
    }
    if s.hasPrefix("@"), s.count > 1 { return try alias(String(s.dropFirst()), at: p) }
    if let sys = SystemAction(rawValue: s) { return .system(sys) }
    if let m = Keys.modifier(s) { return .mod(m) }
    if let (k, m) = Keys.chord(s) { return .key(k, m) }
    throw ConfigError("unknown key or action \(s)", at: p)
  }

  mutating func alias(_ name: String, at p: SourcePos) throws -> Action {
    if let a = aliasCache[name] { return a }
    guard let e = aliasExprs[name] else { throw ConfigError("unknown alias @\(name)", at: p) }
    if resolving.contains(name) {
      throw ConfigError("alias cycle: \((resolving + [name]).joined(separator: " -> "))", at: p)
    }
    resolving.append(name)
    defer { resolving.removeLast() }
    let a = try action(e)
    aliasCache[name] = a
    return a
  }

  mutating func listAction(_ items: [SExpr], at p: SourcePos) throws -> Action {
    guard let head = items.first?.atom else { throw ConfigError("expected an action", at: p) }
    let args = Array(items.dropFirst())
    func need(_ n: Int) throws {
      guard args.count >= n else { throw ConfigError("\(head) needs \(n) arguments", at: p) }
    }
    switch head {
    case "tap-hold", "tap-hold-press", "tap-hold-release",
      "tap-hold-press-timeout", "tap-hold-release-timeout", "tap-hold-release-keys":
      try need(4)
      let kind: TapHold.Kind =
        head.hasPrefix("tap-hold-press")
        ? .press
        : head.hasPrefix("tap-hold-release") ? .release : .plain
      return .tapHold(
        TapHold(
          kind: kind, tapTime: try int(args[0]), holdTime: try int(args[1]),
          tap: try action(args[2]), hold: try action(args[3])))
    case "one-shot", "one-shot-press", "one-shot-release",
      "one-shot-press-pcancel", "one-shot-release-pcancel":
      try need(2)
      return .oneShot(timeout: try int(args[0]), action: try action(args[1]))
    case "layer-while-held", "layer-toggle", "layer-switch":
      try need(1)
      guard let name = args[0].atom else { throw ConfigError("expected a layer name", at: p) }
      layerRefs.append((name, args[0].pos))
      return head == "layer-switch" ? .layerSwitch(name) : .layerHold(name)
    case "fork":
      try need(3)
      return .fork(try action(args[0]), try action(args[1]), try heldAny(args[2]))
    case "unshift", "unmod":
      try need(1)
      let inner = args.count == 1 ? try action(args[0]) : .multi(try args.map { try action($0) })
      return .unshift(inner)
    case "multi":
      return .multi(try args.map { try action($0) })
    case "macro", "macro-release-cancel", "macro-cancel-on-press":
      // Bare numbers in a macro are delays; text insertion is instant, so drop them.
      return .macro(try args.filter { Int($0.atom ?? "") == nil }.map { try action($0) })
    case "unicode", "text":
      try need(1)
      guard let s = args[0].atom ?? stringValue(args[0]) else {
        throw ConfigError("expected text", at: p)
      }
      return .text(s)
    case "caps-word", "caps-word-toggle":
      try need(1)
      return .capsWord(.standard(timeout: try int(args[0]), toggle: head.hasSuffix("toggle")))
    case "caps-word-custom", "caps-word-custom-toggle":
      try need(3)
      return .capsWord(
        CapsWord(
          timeout: try int(args[0]), shifted: try keySet(args[1]),
          continuing: try keySet(args[2]), toggle: head.hasSuffix("toggle")))
    case "swipe-cursor", "swipe-delete":
      try need(1)
      return .swipe(head == "swipe-cursor" ? .cursor : .delete, try action(args[0]))
    case "switch":
      guard args.count % 3 == 0 else {
        throw ConfigError("switch takes (condition) action break|fallthrough triples", at: p)
      }
      var cases: [SwitchCase] = []
      for i in stride(from: 0, to: args.count, by: 3) {
        let ft: Bool
        switch args[i + 2].atom {
        case "break": ft = false
        case "fallthrough": ft = true
        default: throw ConfigError("expected break or fallthrough", at: args[i + 2].pos)
        }
        cases.append(
          SwitchCase(
            condition: try condition(args[i]), action: try action(args[i + 1]),
            continues: ft))
      }
      return .switchCases(cases)
    default:
      throw ConfigError("unsupported action \(head)", at: p)
    }
  }

  func stringValue(_ e: SExpr) -> String? {
    if case .string(let s, _) = e { s } else { nil }
  }

  func keySet(_ e: SExpr) throws -> Set<Key> {
    guard let items = e.list else { throw ConfigError("expected (keys)", at: e.pos) }
    return Set(
      try items.map { i in
        guard let n = i.atom else { throw ConfigError("expected a key", at: i.pos) }
        if Keys.modifier(n) != nil { return Key(n) }
        guard let (k, _) = Keys.chord(n) else { throw ConfigError("unknown key \(n)", at: i.pos) }
        return k
      })
  }

  func heldName(_ e: SExpr) throws -> String {
    guard let n = e.atom else { throw ConfigError("expected a key name", at: e.pos) }
    guard Keys.modifier(n) != nil || srcNames[n] != nil else {
      throw ConfigError("\(n) is neither a modifier nor a defsrc key", at: e.pos)
    }
    return n
  }

  func heldAny(_ e: SExpr) throws -> Condition {
    guard let items = e.list else { throw ConfigError("expected (keys)", at: e.pos) }
    return .or(try items.map { .held(try heldName($0)) })
  }

  mutating func condition(_ e: SExpr) throws -> Condition {
    guard let items = e.list else { throw ConfigError("expected (condition)", at: e.pos) }
    if items.isEmpty { return .always }
    return .or(try items.map { try conditionItem($0) })
  }

  mutating func conditionItem(_ e: SExpr) throws -> Condition {
    if e.atom != nil { return .held(try heldName(e)) }
    guard let items = e.list, let head = e.head else {
      throw ConfigError("expected a condition", at: e.pos)
    }
    let args = Array(items.dropFirst())
    switch head {
    case "and": return .and(try args.map { try conditionItem($0) })
    case "or": return .or(try args.map { try conditionItem($0) })
    case "not":
      return .not(.or(try args.map { try conditionItem($0) }))
    case "mode":
      switch args.first?.atom {
      case "text": return .mode(.text)
      case "terminal": return .mode(.terminal)
      default: throw ConfigError("expected (mode text) or (mode terminal)", at: e.pos)
      }
    case "layer", "base-layer":
      guard let n = args.first?.atom else { throw ConfigError("expected a layer", at: e.pos) }
      layerRefs.append((n, e.pos))
      return head == "layer" ? .layer(n) : .baseLayer(n)
    default:
      throw ConfigError("unsupported switch condition \(head)", at: e.pos)
    }
  }
}
