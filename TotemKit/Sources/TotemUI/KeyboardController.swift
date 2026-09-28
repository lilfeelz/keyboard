import Foundation
import Observation
import os
import QuartzCore
import TotemCore

/// Glue between touches, the engine and whatever applies the edits: the
/// keyboard extension's text proxy, or a string in the app's preview.
@MainActor @Observable
public final class KeyboardController {
    public private(set) var config: Config
    public private(set) var state: EngineState
    public var mode: Mode {
        didSet { if mode != oldValue { onModeChange(mode) } }
    }

    @ObservationIgnored public var perform: (Edit) -> Void = { _ in }
    @ObservationIgnored public var context: () -> TextContext = { TextContext() }
    @ObservationIgnored public var onModeChange: (Mode) -> Void = { _ in }

    @ObservationIgnored private var engine: Engine
    @ObservationIgnored private var timer: DispatchWorkItem?
    @ObservationIgnored private var swipes: [Int: SwipeTracker] = [:]
    @ObservationIgnored private var history = History()

    public init(config: Config, mode: Mode? = nil) {
        self.config = config
        engine = Engine(config: config)
        state = engine.state
        self.mode = mode ?? (config.options.terminal ? .terminal : .text)
    }

    public func load(_ config: Config) {
        guard config != self.config else { return }
        self.config = config
        engine = Engine(config: config)
        state = engine.state
    }

    @ObservationIgnored private let log = Logger(subsystem: "dev.feelz.totem", category: "keys")

    public func press(_ key: Int) {
        log.debug("down \(self.config.keys[key].name, privacy: .public) \(CACurrentMediaTime())")
        handle(engine.press(key, at: CACurrentMediaTime()))
    }

    public func release(_ key: Int) {
        log.debug("up \(self.config.keys[key].name, privacy: .public) \(CACurrentMediaTime())")
        handle(engine.release(key, at: CACurrentMediaTime()))
    }

    // MARK: - swipes

    public func swipeKind(_ key: Int) -> SwipeKind? {
        engine.swipe(at: key)
    }

    public func isSwiping(_ key: Int) -> Bool {
        swipes[key] != nil
    }

    /// The finger on `key` moved past the threshold: the key stops being a key.
    public func beginSwipe(_ key: Int) {
        guard let kind = engine.swipe(at: key) else { return }
        handle(engine.cancel(key, at: CACurrentMediaTime()))
        swipes[key] = SwipeTracker(kind: kind, mode: mode, context: context())
    }

    public func moveSwipe(_ key: Int, dx: Double, dy: Double) {
        guard swipes[key] != nil else { return }
        for e in swipes[key]!.move(dx: dx, dy: dy) { apply(e) }
    }

    public func endSwipe(_ key: Int) {
        guard let s = swipes.removeValue(forKey: key) else { return }
        for e in s.end() { apply(e) }
        release(key)
    }

    private func handle(_ outputs: [Output]) {
        for o in outputs {
            for e in Translator.edits(o, mode: mode, context: context()) ?? [] { apply(e) }
        }
        state = engine.state
        schedule()
    }

    /// Run one edit, keeping the undo history in step.
    private func apply(_ e: Edit) {
        switch e {
        case .toggleTerminal:
            mode = mode == .text ? .terminal : .text
        case .undo:
            for x in history.undo(context: context()) { perform(x) }
        case .redo:
            for x in history.redo(context: context()) { perform(x) }
        default:
            if mode == .text { history.record(e, context: context()) }
            perform(e)
        }
    }

    /// Forget the history, e.g. when the keyboard moves to another text field.
    public func resetHistory() {
        history.clear()
    }

    private func schedule() {
        timer?.cancel()
        guard let deadline = engine.nextDeadline else { return }
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.handle(self.engine.tick(at: CACurrentMediaTime()))
        }
        timer = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(0, deadline - CACurrentMediaTime()), execute: item)
    }

    // MARK: - drawing state

    public func cap(at key: Int) -> KeyCap {
        let a = engine.action(at: key)
        var cap = KeyCap.of(a, shifted: state.mods.contains(.shift), mode: mode)
        if state.capsWord || state.capsLock, cap.style == .char, cap.main.count == 1 {
            cap.main = cap.main.uppercased()
        }
        return cap
    }

    public func isActive(_ key: Int) -> Bool {
        active(engine.action(at: key))
    }

    private func active(_ a: Action) -> Bool {
        switch a {
        case .layerHold(let n): config.layers[state.layer].name == n && state.layer != state.baseLayer
        case .layerSwitch(let n): config.layers[state.baseLayer].name == n && state.baseLayer != 0
        case .mod(let m): state.mods.contains(m)
        case .oneShot(_, let inner): active(inner)
        case .tapHold(let th): active(th.tap) || active(th.hold)
        case .capsWord: state.capsWord
        case .capsLock: state.capsLock
        case .switchCases(let cs): cs.contains { active($0.action) }
        case .system(.toggleTerminal): mode == .terminal
        case .swipe(_, let inner): active(inner)
        default: false
        }
    }

    public func isPressed(_ key: Int) -> Bool {
        state.pressed.contains(key)
    }
}
