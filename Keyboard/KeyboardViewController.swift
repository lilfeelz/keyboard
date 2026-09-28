import SwiftUI
import TotemCore
import TotemUI
import UIKit

final class KeyboardViewController: UIInputViewController {
    private var controller: KeyboardController!
    private var height: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        let saved = UserDefaults.standard.string(forKey: "mode")
        controller = KeyboardController(
            config: currentConfig(), mode: saved.map { $0 == "terminal" ? .terminal : .text })
        controller.perform = { [weak self] in self?.apply($0) }
        controller.context = { [weak self] in
            let p = self?.textDocumentProxy
            return TextContext(
                before: p?.documentContextBeforeInput ?? "", after: p?.documentContextAfterInput ?? "")
        }
        controller.onModeChange = { UserDefaults.standard.set($0 == .terminal ? "terminal" : "text", forKey: "mode") }

        let host = UIHostingController(rootView: KeyboardView(controller: controller))
        host.view.backgroundColor = UIColor(Theme.bg)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        host.didMove(toParent: self)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        height = view.heightAnchor.constraint(equalToConstant: keyboardHeight)
        height.priority = .init(999)
        height.isActive = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        controller.load(currentConfig())
        controller.resetHistory()
        height.constant = keyboardHeight
    }

    override func textDidChange(_ textInput: (any UITextInput)?) {
        controller.contextChanged()
    }

    override func selectionDidChange(_ textInput: (any UITextInput)?) {
        controller.contextChanged()
    }

    private var keyboardHeight: CGFloat {
        let o = controller.config.options
        return traitCollection.userInterfaceIdiom == .pad ? o.heightTablet : o.heightPhone
    }

    /// The app's saved config when Full Access lets us see the app group.
    private func currentConfig() -> Config {
        hasFullAccess ? ConfigStore.load().config : .default
    }

    private func apply(_ e: Edit) {
        let proxy = textDocumentProxy
        switch e {
        case .insert(let s):
            proxy.insertText(s)
        case .deleteBackward(let n):
            for _ in 0..<n { proxy.deleteBackward() }
        case .deleteForward(let s):
            proxy.adjustTextPosition(byCharacterOffset: s.utf16.count)
            for _ in 0..<s.count { proxy.deleteBackward() }
        case .move(let n):
            proxy.adjustTextPosition(byCharacterOffset: n)
        case .copy:
            if hasFullAccess, let s = proxy.selectedText { UIPasteboard.general.string = s }
        case .cut:
            if hasFullAccess, let s = proxy.selectedText, !s.isEmpty {
                UIPasteboard.general.string = s
                proxy.deleteBackward()
            }
        case .paste:
            if hasFullAccess, let s = UIPasteboard.general.string { proxy.insertText(s) }
        case .nextKeyboard:
            advanceToNextInputMode()
        case .dismiss:
            dismissKeyboard()
        case .toggleTerminal, .undo, .redo, .line:
            break  // handled by the controller
        }
    }
}
