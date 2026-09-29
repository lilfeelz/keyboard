import SwiftUI

/// House dark palette (Dracula, as in ~/.config and the Keyman theme it replaces).
public enum Theme {
  public static let bg = Color(hex: 0x0B0D10)
  public static let card = Color(hex: 0x15171F)
  public static let panel = Color(hex: 0x282A36)
  public static let fg = Color(hex: 0xF8F8F2)
  public static let muted = Color(hex: 0x6272A4)
  public static let frame = Color(hex: 0x7F8490)
  public static let accent = Color(hex: 0x8BE9FD)
  public static let pink = Color(hex: 0xFF79C6)
  public static let purple = Color(hex: 0xBD93F9)
  public static let green = Color(hex: 0x50FA7B)
  public static let red = Color(hex: 0xFF5555)
  public static let radius: CGFloat = 6
}

extension Color {
  public init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}
