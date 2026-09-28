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
    @State private var text = ConfigStore.source() ?? Config.defaultSource
    @State private var saved = ConfigStore.source() ?? Config.defaultSource
    @State private var confirmReset = false

    private var result: Result<Config, Error> {
        Result { try Config.parse(text) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(.system(size: 13, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .scrollContentBackground(.hidden)
                    .background(Theme.bg)
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
                    Button("Save") {
                        try? ConfigStore.save(text)
                        saved = text
                    }
                    .disabled(text == saved || (try? result.get()) == nil)
                }
            }
            .confirmationDialog("Replace the config with the bundled default?", isPresented: $confirmReset) {
                Button("Replace", role: .destructive) { text = Config.defaultSource }
            }
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
            if text != saved { Text("unsaved").foregroundStyle(Theme.muted) }
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
    @State private var controller = KeyboardController(config: ConfigStore.load().config)

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
            let end = text.utf16.index(index, offsetBy: s.utf16.count)
            text.removeSubrange(index..<end)
        case .move(let n):
            cursor = min(max(0, cursor + n), text.utf16.count)
        case .copy, .cut, .paste, .nextKeyboard, .dismiss, .toggleTerminal, .undo, .redo:
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
                    Text("Tap Totem there and enable Allow Full Access. Without it the keyboard runs the bundled config and cannot copy or paste.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                Section("What works") {
                    Text("Letters, symbols, tab, enter, space, backspace, delete, tap-hold, one-shot, chords, caps-word, fork, switch, macros, rpt.")
                    Text("Word and line delete, arrows, home and end are emulated from the text around the cursor.")
                    Text("Cmd+C, Cmd+X, Cmd+V copy, cut and paste. Cmd+Z and Shift+Cmd+Z undo and redo what this keyboard typed.")
                    Text("Drag the backspace thumb left to pick words to delete (drag back to give them back, lift to delete); drag the esc thumb to move the cursor.")
                    Text("The >_ key switches to terminal mode: Ctrl and Alt chords, esc, arrows and F1 to F12 go out as control codes and escape sequences (Blink and other SSH apps).")
                }
                Section("What iOS does not allow") {
                    Text("Other Cmd shortcuts, selecting text (Shift+arrows), media and brightness keys. They keep their place and draw dimmed.")
                    Text("Custom keyboards are replaced by the system one in password fields, and disappear while a hardware keyboard is attached.")
                }
            }
            .navigationTitle("Setup")
        }
    }
}
