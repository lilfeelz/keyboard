#if canImport(UIKit)
  import SwiftUI
  import TotemCore
  import UIKit

  public enum KeyboardGeometry {
    /// Key frames for a size, from defsrc's units. Rows narrower than the widest are centred.
    public static func frames(_ config: Config, in size: CGSize, gap: CGFloat = 5) -> [CGRect] {
      let unit = (size.width - gap) / config.width
      let rowH = (size.height - gap) / CGFloat(config.rows)
      return config.keys.map { k in
        let inset = (config.width - config.rowWidths[k.row]) / 2
        return CGRect(
          x: gap + (k.x + inset) * unit, y: gap + CGFloat(k.row) * rowH,
          width: k.width * unit - gap, height: rowH - gap)
      }
    }
  }

  public struct KeyboardView: View {
    let controller: KeyboardController

    public init(controller: KeyboardController) {
      self.controller = controller
    }

    public var body: some View {
      GeometryReader { geo in
        let frames = KeyboardGeometry.frames(controller.config, in: geo.size)
        ZStack(alignment: .topLeading) {
          ForEach(frames.indices, id: \.self) { i in
            KeyCapView(
              cap: controller.cap(at: i), pressed: controller.isPressed(i),
              active: controller.isActive(i)
            )
            .frame(width: frames[i].width, height: frames[i].height)
            .offset(x: frames[i].minX, y: frames[i].minY)
          }
          TouchSurface(frames: frames, controller: controller)
        }
      }
      .background(Theme.bg)
    }
  }

  struct KeyCapView: View {
    let cap: KeyCap
    let pressed: Bool
    let active: Bool

    var fill: Color {
      if pressed { return Theme.pink }
      if active { return Theme.purple }
      switch cap.style {
      case .char: return Theme.panel
      case .blank: return .clear
      default: return Theme.card
      }
    }

    var ink: Color {
      if pressed || active { return Theme.bg }
      switch cap.style {
      case .char: return Theme.fg
      case .layer: return Theme.purple
      case .mod: return Theme.accent
      case .inert: return Theme.muted.opacity(0.5)
      default: return Theme.frame
      }
    }

    var body: some View {
      GeometryReader { geo in
        let h = geo.size.height
        let size = min(h * 0.4, cap.main.count > 2 ? h * 0.26 : 24)
        ZStack(alignment: .topTrailing) {
          RoundedRectangle(cornerRadius: Theme.radius)
            .fill(fill)
            .overlay(
              RoundedRectangle(cornerRadius: Theme.radius)
                .stroke(cap.style == .blank ? .clear : Theme.muted.opacity(0.2), lineWidth: 1))
          Group {
            if let symbol = cap.symbol {
              Image(systemName: symbol).font(.system(size: size * 0.8))
            } else {
              Text(cap.main)
                .font(.system(size: size, design: .monospaced))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 2)
            }
          }
          .foregroundStyle(ink)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          if let hint = cap.hint {
            Text(hint)
              .font(.system(size: max(9, h * 0.16), design: .monospaced))
              .foregroundStyle(pressed || active ? Theme.bg.opacity(0.7) : Theme.muted)
              .lineLimit(1)
              .padding(.top, 3)
              .padding(.trailing, 5)
          }
        }
      }
      .accessibilityElement()
      .accessibilityLabel(cap.symbol ?? cap.main)
    }
  }

  /// Raw multi-touch: every finger is its own key press, held until it lifts,
  /// which is what tap-hold and chords need. A touch in a gap goes to the
  /// nearest key. On a swipe key, a finger that travels far enough becomes a
  /// swipe and stops being a key press.
  struct TouchSurface: UIViewRepresentable {
    let frames: [CGRect]
    let controller: KeyboardController

    func makeUIView(context: Context) -> Surface {
      let v = Surface()
      v.isMultipleTouchEnabled = true
      v.backgroundColor = .clear
      return v
    }

    func updateUIView(_ v: Surface, context: Context) {
      v.frames = frames
      v.controller = controller
    }

    final class Surface: UIView {
      var frames: [CGRect] = []
      weak var controller: KeyboardController?

      struct Finger {
        var key: Int
        var origin: CGPoint
      }

      private var fingers: [ObjectIdentifier: Finger] = [:]

      func key(at p: CGPoint) -> Int? {
        if let i = frames.firstIndex(where: { $0.contains(p) }) { return i }
        return frames.indices.min {
          dist(frames[$0], p) < dist(frames[$1], p)
        }
      }

      private func dist(_ r: CGRect, _ p: CGPoint) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return dx * dx + dy * dy
      }

      override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
          let p = t.location(in: self)
          guard let k = key(at: p) else { continue }
          fingers[ObjectIdentifier(t)] = Finger(key: k, origin: p)
          controller?.press(k)
        }
      }

      override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let c = controller else { return }
        for t in touches {
          guard let f = fingers[ObjectIdentifier(t)] else { continue }
          let p = t.location(in: self)
          let dx = p.x - f.origin.x
          let dy = p.y - f.origin.y
          if c.isSwiping(f.key) {
            c.moveSwipe(f.key, dx: dx, dy: dy)
            continue
          }
          guard let kind = c.swipeKind(f.key) else { continue }
          let far =
            abs(dx) > SwipeTracker.threshold
            || (kind == .cursor && abs(dy) > SwipeTracker.threshold)
          guard far else { continue }
          c.beginSwipe(f.key)
          c.moveSwipe(f.key, dx: dx, dy: dy)
        }
      }

      override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        end(touches)
      }

      override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        end(touches)
      }

      private func end(_ touches: Set<UITouch>) {
        for t in touches.sorted(by: { $0.timestamp < $1.timestamp }) {
          guard let f = fingers.removeValue(forKey: ObjectIdentifier(t)) else { continue }
          if controller?.isSwiping(f.key) == true {
            controller?.endSwipe(f.key)
          } else {
            controller?.release(f.key)
          }
        }
      }
    }
  }
#endif
