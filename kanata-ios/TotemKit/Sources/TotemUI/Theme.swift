import SwiftUI

/// JakobMelchard v1 tokens (JakobMelchard/.config tokens/tokens.json): Dracula on near-black. The
/// values live in the vendored `GeneratedTokens.swift` (`config-sync tokens`); this type names the
/// ones used here.
public enum Theme {
  public static let bg = GeneratedTokens.bg
  public static let card = GeneratedTokens.card
  public static let fg = GeneratedTokens.fg
  public static let muted = GeneratedTokens.muted
  public static let accent = GeneratedTokens.accent
  public static let pink = GeneratedTokens.pink
  public static let purple = GeneratedTokens.purple
  public static let green = GeneratedTokens.green
  public static let red = GeneratedTokens.red
  public static let radius = GeneratedTokens.radiusMd
}

extension Color {
  public init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}
