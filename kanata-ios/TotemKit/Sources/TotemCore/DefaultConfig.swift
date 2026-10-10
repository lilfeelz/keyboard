import Foundation

extension Config {
  /// The bundled config, `default.kbd`: ~/.config/kanata/kanata.kbd on the TOTEM grid
  /// (3x5 + outer column + thumbs), zmk's sym-row macros where kanata has
  /// Cmd+Ctrl+Alt app shortcuts.
  public static let defaultSource: String = {
    guard let url = Bundle.module.url(forResource: "default", withExtension: "kbd"),
      let s = try? String(contentsOf: url, encoding: .utf8)
    else { fatalError("default.kbd missing from the TotemCore bundle") }
    return s
  }()
}
