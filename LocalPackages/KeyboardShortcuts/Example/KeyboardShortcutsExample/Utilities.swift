import SwiftUI

@MainActor
final class CallbackMenuItem: NSMenuItem {
    // MARK: Lifecycle

    init(
        _ title: String,
        key: String = "",
        keyModifiers: NSEvent.ModifierFlags? = nil,
        isEnabled: Bool = true,
        isChecked: Bool = false,
        isHidden: Bool = false,
        action: @escaping () -> Void
    ) {
        self.callback = action
        super.init(title: title, action: #selector(action(_:)), keyEquivalent: key)
        self.target = self
        self.isEnabled = isEnabled
        self.isChecked = isChecked
        self.isHidden = isHidden

        if let keyModifiers {
            self.keyEquivalentModifierMask = keyModifiers
        }
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        // swiftlint:disable:next fatal_error_message
        fatalError()
    }

    // MARK: Internal

    static func validate(_ callback: @escaping (NSMenuItem) -> Bool) {
        validateCallback = callback
    }

    // MARK: Private

    private static var validateCallback: ((NSMenuItem) -> Bool)?

    private let callback: () -> Void

    @objc
    private func action(_: NSMenuItem) {
        callback()
    }
}

extension CallbackMenuItem: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        Self.validateCallback?(menuItem) ?? true
    }
}

extension NSMenuItem {
    convenience init(
        _ title: String,
        action: Selector? = nil,
        key: String = "",
        keyModifiers: NSEvent.ModifierFlags? = nil,
        data: Any? = nil,
        isEnabled: Bool = true,
        isChecked: Bool = false,
        isHidden: Bool = false
    ) {
        self.init(title: title, action: action, keyEquivalent: key)
        self.representedObject = data
        self.isEnabled = isEnabled
        self.isChecked = isChecked
        self.isHidden = isHidden

        if let keyModifiers {
            self.keyEquivalentModifierMask = keyModifiers
        }
    }

    var isChecked: Bool {
        get { state == .on }
        set {
            state = newValue ? .on : .off
        }
    }
}

extension NSMenu {
    @MainActor
    @discardableResult
    func addCallbackItem(
        _ title: String,
        key: String = "",
        keyModifiers: NSEvent.ModifierFlags? = nil,
        isEnabled: Bool = true,
        isChecked: Bool = false,
        isHidden: Bool = false,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let menuItem = CallbackMenuItem(
            title,
            key: key,
            keyModifiers: keyModifiers,
            isEnabled: isEnabled,
            isChecked: isChecked,
            isHidden: isHidden,
            action: action
        )
        addItem(menuItem)
        return menuItem
    }
}
