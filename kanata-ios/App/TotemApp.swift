import SwiftUI
import TotemCore
import TotemUI

@main
struct TotemApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .preferredColorScheme(.dark)
        .tint(Theme.accent)
        .fontDesign(.monospaced)
    }
  }
}

struct ContentView: View {
  @State private var tab = ProcessInfo.processInfo.arguments.contains("--try") ? 1 : 0

  var body: some View {
    TabView(selection: $tab) {
      Tab("Config", systemImage: "curlybraces", value: 0) { ConfigEditor() }
      Tab("Try", systemImage: "keyboard", value: 1) { TryView() }
      Tab("Setup", systemImage: "gearshape", value: 2) { SetupView() }
    }
  }
}

/// Edit the kanata-style config; it is checked as you type and saved to the
/// app group, where the keyboard picks it up next time it appears.
struct ConfigEditor: View {
  @State private var source = ConfigEditor.colored(ConfigStore.source() ?? Config.defaultSource)
  @State private var saved = ConfigStore.Saved(ConfigStore.source() ?? Config.defaultSource)
  @State private var confirmReset = false

  private var text: String { String(source.characters) }

  private var result: Result<Config, Error> {
    Result { try Config.parse(text) }
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        TextEditor(text: $source)
          .font(.system(size: 13, design: .monospaced))
          .autocorrectionDisabled()
          .textInputAutocapitalization(.never)
          .scrollContentBackground(.hidden)
          .background(Theme.bg)
          .attributedTextFormattingDefinition(Colors.self)
          .textInputFormattingControlVisibility(.hidden, for: .all)
          .onChange(of: text) { recolor() }
        status
      }
      .background(Theme.bg)
      .navigationTitle("config.kbd")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button("Default") { confirmReset = true }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") { saved.save(text) }
            .disabled(text == saved.text || (try? result.get()) == nil)
        }
      }
      .confirmationDialog(
        "Replace the config with the bundled default?", isPresented: $confirmReset
      ) {
        Button("Replace", role: .destructive) { source = Self.colored(Config.defaultSource) }
      }
    }
  }

  /// The only attribute the editor keeps, so pasted or shortcut formatting
  /// cannot stick; the formatting controls themselves are hidden.
  struct Colors: AttributeScope {
    let foregroundColor: AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute
  }

  /// Recolour in place: only attributes change, so the cursor stays put.
  private func recolor() { Self.paint(&source) }

  static func colored(_ s: String) -> AttributedString {
    var a = AttributedString(s)
    paint(&a)
    return a
  }

  static func paint(_ a: inout AttributedString) {
    let plain = String(a.characters)
    let u = plain.utf16
    a.foregroundColor = Theme.fg
    for span in Highlight.spans(plain) {
      let lo = u.index(u.startIndex, offsetBy: span.start)
      let hi = u.index(lo, offsetBy: span.length)
      guard let x = AttributedString.Index(lo, within: a),
        let y = AttributedString.Index(hi, within: a)
      else { continue }
      a[x..<y].foregroundColor = color(span.kind)
    }
  }

  static func color(_ kind: Highlight.Kind) -> Color {
    switch kind {
    case .comment: Theme.muted
    case .string: Theme.green
    case .paren: Theme.muted
    case .head: Theme.pink
    case .alias: Theme.accent
    case .variable: Theme.purple
    }
  }

  @ViewBuilder private var status: some View {
    HStack {
      switch result {
      case .success(let c):
        Image(systemName: "checkmark.circle").foregroundStyle(Theme.green)
        Text("\(c.layers.count) layers, \(c.keys.count) keys, \(c.chords.count) chords")
        if !c.warnings.isEmpty {
          Text(c.warnings.joined(separator: "; ")).foregroundStyle(Theme.muted).lineLimit(2)
        }
      case .failure(let e):
        Image(systemName: "xmark.circle").foregroundStyle(Theme.red)
        Text(String(describing: e)).foregroundStyle(Theme.red).lineLimit(3)
      }
      Spacer()
      if let e = saved.error {
        Text("not saved: \(e)").foregroundStyle(Theme.red).lineLimit(2)
      }
      if text != saved.text { Text("unsaved").foregroundStyle(Theme.muted) }
    }
    .font(.system(size: 12, design: .monospaced))
    .padding(10)
    .background(Theme.card)
  }
}

/// The keyboard running inside the app against a plain string, so the config
/// can be tried without switching keyboards (and in the simulator).
struct TryView: View {
  @State private var buffer = Buffer()
  @State private var controller = KeyboardController(config: Self.config())

  /// `--var <name> <value>` overrides a defvar here, for UI tests: on a slow CI runner two
  /// synthesized taps can land further apart than the default one-shot-time.
  static func config() -> Config {
    let a = ProcessInfo.processInfo.arguments
    guard let i = a.firstIndex(of: "--var"), i + 2 < a.count,
      let c = try? Config.parse(
        ConfigStore.source() ?? Config.defaultSource, vars: [a[i + 1]: a[i + 2]])
    else { return ConfigStore.load().config }
    return c
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(controller.config.layers[controller.state.layer].name)
          .foregroundStyle(Theme.purple)
          .accessibilityIdentifier("layer")
        Text(controller.mode == .terminal ? "terminal" : "text")
          .foregroundStyle(Theme.muted)
          .accessibilityIdentifier("mode")
        Spacer()
        Button("Clear") { buffer = Buffer() }
      }
      .font(.system(size: 13, design: .monospaced))
      .padding(10)
      ScrollView {
        Text(buffer.display)
          .font(.system(size: 16, design: .monospaced))
          .foregroundStyle(Theme.fg)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .padding(10)
          .accessibilityIdentifier("buffer")
      }
      .background(Theme.card)
      KeyboardView(controller: controller)
        .frame(height: controller.config.options.heightTablet)
    }
    .background(Theme.bg)
    .onAppear {
      controller.load(ConfigStore.load().config)
      controller.perform = { buffer.apply($0) }
      controller.context = { buffer.context }
    }
  }
}

/// A text field stand-in: the text, a cursor, and the edits a proxy supports.
struct Buffer {
  var text = ""
  var cursor = 0  // UTF-16 offset

  var index: String.Index { String.Index(utf16Offset: cursor, in: text) }

  var context: TextContext {
    TextContext(before: String(text[..<index]), after: String(text[index...]))
  }

  /// Text with a visible cursor; control bytes shown as ^X so terminal mode is readable.
  var display: String {
    let show: (String) -> String = { s in
      s.unicodeScalars.map { u in
        switch u.value {
        case 0x1B: "^["
        case 0x7F: "^?"
        case 0x0D: "^M\n"
        case 0..<0x20 where u != "\n" && u != "\t": "^" + String(UnicodeScalar(u.value + 64)!)
        default: String(u)
        }
      }.joined()
    }
    return show(context.before) + "▏" + show(context.after)
  }

  mutating func apply(_ e: Edit) {
    switch e {
    case .insert(let s):
      text.insert(contentsOf: s, at: index)
      cursor += s.utf16.count
    case .deleteBackward(let n):
      for _ in 0..<n where cursor > 0 {
        let end = index
        let start = text.index(before: end)
        cursor -= text[start..<end].utf16.count
        text.removeSubrange(start..<end)
      }
    case .deleteForward(let s):
      let end =
        text.utf16.index(index, offsetBy: s.utf16.count, limitedBy: text.endIndex) ?? text.endIndex
      text.removeSubrange(index..<end)
    case .move(let n):
      cursor = min(max(0, cursor + n), text.utf16.count)
    case .copy, .cut, .paste, .nextKeyboard, .dismiss, .toggleTerminal, .undo, .redo, .line:
      break
    }
  }
}

struct SetupView: View {
  var body: some View {
    NavigationStack {
      List {
        Section("Turn it on") {
          Text("Settings > General > Keyboard > Keyboards > Add New Keyboard > Totem")
          Text(
            "Tap Totem there and enable Allow Full Access. Without it the keyboard runs the bundled config and cannot copy or paste."
          )
          Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
          }
        }
        Section("What works") {
          Text(
            "Letters, symbols, tab, enter, space, backspace, delete, tap-hold, one-shot, chords, caps-word, fork, switch, macros, rpt."
          )
          Text(
            "Word and line delete, arrows, home and end are emulated from the text around the cursor."
          )
          Text(
            "Cmd+C, Cmd+X, Cmd+V copy, cut and paste. Cmd+Z and Shift+Cmd+Z undo and redo what this keyboard typed."
          )
          Text(
            "Drag the backspace thumb left to pick characters to delete (drag back to give them back, lift to delete); drag the esc thumb to move the cursor."
          )
          Text(
            "The >_ key switches to terminal mode: Ctrl and Alt chords, esc, arrows and F1 to F12 go out as control codes and escape sequences (Blink and other SSH apps)."
          )
          Text(
            "The top left key is esc in terminal mode and opens an emoji layer in text mode; its top left key goes back. iOS lets a keyboard open no other keyboard, so the system emoji picker stays behind the globe."
          )
        }
        Section("What iOS does not allow") {
          Text(
            "Other Cmd shortcuts, selecting text (Shift+arrows), media and brightness keys. They keep their place and draw dimmed."
          )
          Text(
            "Custom keyboards are replaced by the system one in password fields, and disappear while a hardware keyboard is attached."
          )
        }
      }
      .navigationTitle("Setup")
    }
  }
}
