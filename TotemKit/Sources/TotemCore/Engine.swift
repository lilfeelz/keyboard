/// The key-processing state machine. Touches come in as press/release of defsrc
/// indices with a timestamp (seconds); what comes out is keystrokes, text and
/// system actions for `Translator` to turn into text edits.
///
/// Two stages, like kanata: chords first (a set of keys pressed within the
/// chord window becomes one virtual key), then a buffer that holds events while
/// a tap-hold is undecided and replays them once it resolves. Anything with a
/// deadline (tap-hold, chord window, one-shot, caps-word, key repeat) is driven
/// by `tick(at:)`; the host schedules it for `nextDeadline`.

public enum Output: Sendable, Equatable {
    case stroke(Key, Mods)
    case text(String)
    case system(SystemAction)
}

public struct EngineState: Sendable, Equatable {
    public var layer: Int
    public var baseLayer: Int
    /// Held plus one-shot modifiers.
    public var mods: Mods
    public var oneShot: Mods
    public var capsWord: Bool
    public var capsLock: Bool
    public var pressed: Set<Int>
}

public final class Engine {
    public let config: Config

    struct Event {
        var key: Int
        var down: Bool
        var t: Double
    }

    struct Pending {
        var key: Int
        var tapHold: TapHold
        var t: Double
    }

    /// Undo steps for a held key.
    enum Undo {
        case mods(Int)
        case layer(Int)
    }

    struct Held {
        var undo: [Undo] = []
        var repeatOutputs: [Output] = []
        var nextRepeat: Double?
    }

    struct ActiveChord {
        var chord: Int
        var remaining: Set<Int>
        var released = false
    }

    // chord stage
    private var chordBuf: [Event] = []
    private var activeChords: [ActiveChord] = []
    private let chordsByKey: [Int: [Int]]

    // tap-hold stage
    private var buffer: [Event] = []
    private var pending: Pending?
    private var lastTap: [Int: Double] = [:]

    // state
    private var base = 0
    private var heldLayers: [(token: Int, layer: Int)] = []
    private var heldMods: [(token: Int, mods: Mods)] = []
    private var oneShot: (mods: Mods, layerToken: Int?, deadline: Double)?
    private var capsWord: (spec: CapsWord, deadline: Double)?
    private var capsLock = false
    private var held: [Int: Held] = [:]
    private var pressed: Set<Int> = []
    private var token = 0
    private var lastOutputs: [Output] = []

    // per-call output
    private var out: [Output] = []
    private var recording: [Output]?
    private var now = 0.0

    public init(config: Config) {
        self.config = config
        var byKey: [Int: [Int]] = [:]
        for (i, c) in config.chords.enumerated() {
            for k in c.keys { byKey[k, default: []].append(i) }
        }
        chordsByKey = byKey
    }

    // MARK: - public API

    public func press(_ key: Int, at t: Double) -> [Output] {
        run(t) {
            pressed.insert(key)
            feedRaw(Event(key: key, down: true, t: t))
        }
    }

    public func release(_ key: Int, at t: Double) -> [Output] {
        run(t) {
            pressed.remove(key)
            feedRaw(Event(key: key, down: false, t: t))
        }
    }

    public func tick(at t: Double) -> [Output] {
        run(t) {}
    }

    public var nextDeadline: Double? {
        var ds: [Double] = []
        if let first = chordBuf.first { ds.append(first.t + chordWindow()) }
        if let p = pending { ds.append(p.t + ms(p.tapHold.holdTime)) }
        if let o = oneShot { ds.append(o.deadline) }
        if let c = capsWord { ds.append(c.deadline) }
        ds += held.values.compactMap(\.nextRepeat)
        return ds.min()
    }

    public var state: EngineState {
        EngineState(
            layer: topLayer, baseLayer: base, mods: currentMods, oneShot: oneShot?.mods ?? [],
            capsWord: capsWord != nil, capsLock: capsLock, pressed: pressed)
    }

    /// The action a key would run right now, after layer fall-through.
    public func action(at key: Int) -> Action {
        if key >= config.keys.count { return config.chords[key - config.keys.count].action }
        for l in ([base] + heldLayers.map(\.layer)).reversed() {
            let a = config.layers[l].actions[key]
            if a != .trans { return a }
        }
        return config.defaults[key]
    }

    // MARK: - driver

    private func run(_ t: Double, _ body: () -> Void) -> [Output] {
        now = max(now, t)
        out = []
        body()
        resolveChords()
        drain()
        expire()
        return out
    }

    private func ms(_ n: Int) -> Double { Double(n) / 1000 }

    private var topLayer: Int { heldLayers.last?.layer ?? base }

    private var currentMods: Mods {
        heldMods.reduce(oneShot?.mods ?? []) { $0.union($1.mods) }
    }

    private func nextToken() -> Int {
        token += 1
        return token
    }

    // MARK: - chord stage

    private func chordsEnabled(_ i: Int) -> Bool {
        !config.chords[i].disabledLayers.contains(config.layers[topLayer].name)
    }

    private func chordWindow() -> Double {
        let keys = chordBuf.filter(\.down).map(\.key)
        let cands = candidates(Set(keys))
        return ms(cands.map { config.chords[$0].timeout }.max() ?? 0)
    }

    private func candidates(_ down: Set<Int>) -> [Int] {
        config.chords.indices.filter {
            chordsEnabled($0) && down.isSubset(of: config.chords[$0].keys)
        }
    }

    private func feedRaw(_ e: Event) {
        if !chordBuf.isEmpty {
            chordBuf.append(e)
            resolveChords()
            return
        }
        if e.down, let cs = chordsByKey[e.key], cs.contains(where: chordsEnabled) {
            chordBuf = [e]
            resolveChords()
            return
        }
        if !e.down, let i = activeChords.firstIndex(where: { $0.remaining.contains(e.key) }) {
            chordMemberUp(i, e)
            return
        }
        emit(e)
    }

    private func resolveChords() {
        guard let first = chordBuf.first else { return }
        var down: [Int] = []
        for (i, e) in chordBuf.enumerated() {
            let exact = candidates(Set(down)).first { config.chords[$0].keys == Set(down) }
            if e.down {
                if candidates(Set(down + [e.key])).isEmpty {
                    return exact.map { fireChord($0, consumed: i) } ?? failChord()
                }
                down.append(e.key)
            } else {
                return exact.map { fireChord($0, consumed: i) } ?? failChord()
            }
        }
        let cands = candidates(Set(down))
        let exact = cands.first { config.chords[$0].keys == Set(down) }
        if let exact, cands.count == 1 { return fireChord(exact, consumed: chordBuf.count) }
        if now - first.t >= chordWindow() {
            if let exact { fireChord(exact, consumed: chordBuf.count) } else { failChord() }
        }
    }

    private func fireChord(_ c: Int, consumed: Int) {
        let evs = chordBuf
        chordBuf = []
        let keys = Set(evs[..<consumed].map(\.key))
        activeChords.append(ActiveChord(chord: c, remaining: keys))
        emit(Event(key: config.keys.count + c, down: true, t: evs[consumed - 1].t))
        for e in evs[consumed...] { feedRaw(e) }
    }

    private func failChord() {
        let evs = chordBuf
        chordBuf = []
        emit(evs[0])
        for e in evs.dropFirst() { feedRaw(e) }
    }

    private func chordMemberUp(_ i: Int, _ e: Event) {
        activeChords[i].remaining.remove(e.key)
        let c = activeChords[i]
        let releaseNow =
            !c.released && (config.chords[c.chord].releaseOnFirst || c.remaining.isEmpty)
        if releaseNow {
            activeChords[i].released = true
            emit(Event(key: config.keys.count + c.chord, down: false, t: e.t))
        }
        if activeChords[i].remaining.isEmpty { activeChords.remove(at: i) }
    }

    // MARK: - tap-hold stage

    private func emit(_ e: Event) {
        buffer.append(e)
        drain()
    }

    private func drain() {
        while true {
            if let p = pending {
                guard resolve(p) else { return }
                continue
            }
            guard !buffer.isEmpty else { return }
            step(buffer.removeFirst())
        }
    }

    /// Settle the pending tap-hold if the buffer or the clock decides it.
    private func resolve(_ p: Pending) -> Bool {
        let th = p.tapHold
        let holdAt = p.t + ms(th.holdTime)
        var downAfter: Set<Int> = []
        for (i, e) in buffer.enumerated() {
            if e.key == p.key, !e.down {
                if e.t >= holdAt { return hold(p) }
                buffer.remove(at: i)
                pending = nil
                lastTap[p.key] = e.t
                pressAction(p.key, th.tap)
                releaseKey(p.key)
                return true
            }
            if e.down {
                if th.kind == .press { return hold(p) }
                downAfter.insert(e.key)
            } else if th.kind == .release, downAfter.contains(e.key) {
                return hold(p)
            }
        }
        if now >= holdAt { return hold(p) }
        return false
    }

    private func hold(_ p: Pending) -> Bool {
        pending = nil
        pressAction(p.key, p.tapHold.hold)
        return true
    }

    private func step(_ e: Event) {
        guard e.down else {
            releaseKey(e.key)
            return
        }
        let a = action(at: e.key)
        if case .tapHold(let th) = a {
            if let last = lastTap[e.key], e.t - last < ms(th.tapTime) {
                lastTap[e.key] = nil
                pressAction(e.key, th.tap)
            } else {
                pending = Pending(key: e.key, tapHold: th, t: e.t)
            }
            return
        }
        pressAction(e.key, a)
    }

    // MARK: - actions

    private func pressAction(_ key: Int, _ a: Action) {
        recording = []
        var h = Held()
        h.undo = press(a, unshift: false)
        if let rec = recording, !rec.isEmpty {
            if a != .repeatLast { lastOutputs = rec }
            if rec.allSatisfy(Self.repeats) {
                h.repeatOutputs = rec
                h.nextRepeat = now + ms(config.options.repeatDelay)
            }
        }
        recording = nil
        held[key] = h
    }

    private static func repeats(_ o: Output) -> Bool {
        guard case .stroke(let k, _) = o else { return false }
        return ["bspc", "del", "left", "rght", "up", "down", "spc"].contains(k.name)
    }

    private func releaseKey(_ key: Int) {
        guard let h = held.removeValue(forKey: key) else { return }
        undo(h.undo)
    }

    private func undo(_ steps: [Undo]) {
        for s in steps.reversed() {
            switch s {
            case .mods(let t): heldMods.removeAll { $0.token == t }
            case .layer(let t): heldLayers.removeAll { $0.token == t }
            }
        }
    }

    private func condition(_ c: Condition) -> Bool {
        switch c {
        case .always: true
        case .held(let n):
            if let m = Keys.modifier(n) {
                currentMods.contains(m)
            } else if let i = config.keys.firstIndex(where: { $0.name == n }) {
                pressed.contains(i)
            } else {
                false
            }
        case .layer(let n): config.layers[topLayer].name == n
        case .baseLayer(let n): config.layers[base].name == n
        case .and(let cs): cs.allSatisfy(condition)
        case .or(let cs): cs.contains(where: condition)
        case .not(let c): !condition(c)
        }
    }

    /// Run the press side of an action; returns what to undo on release.
    private func press(_ a: Action, unshift: Bool) -> [Undo] {
        switch a {
        case .none, .trans:
            return []
        case .key(let k, let m):
            stroke(k, explicit: m, unshift: unshift)
            return []
        case .mod(let m):
            let t = nextToken()
            heldMods.append((t, m))
            return [.mods(t)]
        case .text(let s):
            output(.text(s))
            consumeOneShot()
            return []
        case .tapHold(let th):
            // Nested inside another action there is no key to time; treat as a tap.
            return press(th.tap, unshift: unshift)
        case .oneShot(let timeout, let inner):
            startOneShot(inner, timeout: timeout)
            return []
        case .layerHold(let name):
            guard let l = config.layerIndex(named: name) else { return [] }
            let t = nextToken()
            heldLayers.append((t, l))
            return [.layer(t)]
        case .layerSwitch(let name):
            if let l = config.layerIndex(named: name) { base = l }
            return []
        case .fork(let l, let r, let c):
            return press(condition(c) ? r : l, unshift: unshift)
        case .unshift(let inner):
            return press(inner, unshift: true)
        case .multi(let as_):
            return as_.flatMap { press($0, unshift: unshift) }
        case .macro(let as_):
            for x in as_ { undo(press(x, unshift: unshift)) }
            return []
        case .capsWord(let spec):
            if capsWord != nil, spec.toggle {
                capsWord = nil
            } else {
                capsWord = (spec, now + ms(spec.timeout))
            }
            return []
        case .capsLock:
            capsLock.toggle()
            capsWord = nil
            return []
        case .switchCases(let cases):
            var steps: [Undo] = []
            var matched = false
            for c in cases {
                guard matched || condition(c.condition) else { continue }
                matched = true
                steps += press(c.action, unshift: unshift)
                if !c.continues { break }
            }
            return steps
        case .repeatLast:
            for o in lastOutputs { output(o) }
            return []
        case .system(let s):
            output(.system(s))
            return []
        }
    }

    private func startOneShot(_ inner: Action, timeout: Int) {
        let deadline = now + ms(timeout)
        switch inner {
        case .mod(let m):
            if let o = oneShot, o.mods.contains(m) {
                cancelOneShot()
            } else {
                oneShot = ((oneShot?.mods ?? []).union(m), oneShot?.layerToken, deadline)
            }
        case .layerHold(let name), .layerSwitch(let name):
            guard let l = config.layerIndex(named: name) else { return }
            let t = nextToken()
            heldLayers.append((t, l))
            oneShot = (oneShot?.mods ?? [], t, deadline)
        case .multi(let as_):
            for x in as_ { startOneShot(x, timeout: timeout) }
        default:
            // kanata allows any key; for a plain key, one-shot is just a press.
            _ = press(inner, unshift: false)
        }
    }

    private func cancelOneShot() {
        if let t = oneShot?.layerToken { heldLayers.removeAll { $0.token == t } }
        oneShot = nil
    }

    private func consumeOneShot() {
        if oneShot != nil { cancelOneShot() }
    }

    private func stroke(_ k: Key, explicit: Mods, unshift: Bool) {
        var mods = currentMods.union(explicit)
        if unshift {
            mods.remove(.shift)
            mods.formUnion(explicit)
        }
        if let cw = capsWord {
            if cw.spec.shifted.contains(k) {
                mods.insert(.shift)
                capsWord!.deadline = now + ms(cw.spec.timeout)
            } else if cw.spec.continuing.contains(k) || mods.contains(.shift) && k.name == "-" {
                capsWord!.deadline = now + ms(cw.spec.timeout)
            } else {
                capsWord = nil
            }
        }
        if capsLock, k.isLetter { mods.insert(.shift) }
        output(.stroke(k, mods))
        consumeOneShot()
    }

    private func output(_ o: Output) {
        out.append(o)
        recording?.append(o)
    }

    private func expire() {
        if let o = oneShot, now >= o.deadline { cancelOneShot() }
        if let c = capsWord, now >= c.deadline { capsWord = nil }
        for (k, h) in held {
            guard var next = h.nextRepeat, now >= next else { continue }
            while next <= now {
                for o in h.repeatOutputs { out.append(o) }
                next += ms(config.options.repeatInterval)
            }
            held[k]?.nextRepeat = next
        }
    }
}
