import Foundation
import TotemCore

/// The user's config lives in the app group so the app can edit it and the
/// keyboard can read it. The keyboard only sees the group with Full Access;
/// without it, it runs the bundled default.
public enum ConfigStore {
  public static let appGroup = group(for: Bundle.main.bundleIdentifier ?? "dev.feelz.totem")

  /// The group is "group." plus the app's bundle id. SideStore appends ".<team id>" to both
  /// (dev.feelz.totem.TEAM, group.dev.feelz.totem.TEAM); the keyboard is the app's id + ".keyboard".
  static func group(for bundleID: String) -> String {
    let app =
      bundleID.hasSuffix(".keyboard") ? String(bundleID.dropLast(".keyboard".count)) : bundleID
    return "group." + app
  }

  public static var url: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appending(path: "config.kbd")
  }

  /// The saved source, or nil when nothing was saved (or the group is out of reach).
  public static func source() -> String? {
    guard let url else { return nil }
    return try? String(contentsOf: url, encoding: .utf8)
  }

  public static func save(_ text: String) throws {
    guard let url else { throw ConfigError("app group \(appGroup) is not available") }
    try text.write(to: url, atomically: true, encoding: .utf8)
  }

  public static func reset() {
    if let url { try? FileManager.default.removeItem(at: url) }
  }

  /// The saved config, falling back to the default when it is missing or broken.
  public static func load() -> (config: Config, error: String?) {
    guard let text = source() else { return (.default, nil) }
    do {
      return (try Config.parse(text), nil)
    } catch {
      return (.default, "\(error)")
    }
  }
}
