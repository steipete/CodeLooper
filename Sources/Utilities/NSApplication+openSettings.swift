//
//  NSApplication+openSettings.swift
//  Based on: https://gist.github.com/stephancasas/887fdcc4e287ff498f74e6a71449a8b0
//

import SwiftUI

private let kAppMenuInternalIdentifier  = "app"
private let kSettingsLocalizedStringKey = "Settings\\U2026"

extension NSApplication {
    
    /// Open the application settings/preferences window.
    /// This implementation targets macOS 14+ and uses the internal SwiftUI menu system.
    func openSettings() {
        // macOS 14+ Sonoma approach - access the internal SwiftUI Settings menu item
        if let internalItemAction = NSApp.mainMenu?.item(
            withInternalIdentifier: kAppMenuInternalIdentifier
        )?.submenu?.item(
            withLocalizedTitle: kSettingsLocalizedStringKey
        )?.internalItemAction {
            internalItemAction()
            return
        }
        
        // Fallback: try the delegate approach
        guard let delegate = NSApp.delegate else { return }
        let selector = Selector(("showSettingsWindow:"))
        if delegate.responds(to: selector) {
            delegate.perform(selector, with: nil, with: nil)
        }
    }
    
}

// MARK: - NSMenuItem (Private)

extension NSMenuItem {
    
    /// An internal SwiftUI menu item identifier that should be a public property on `NSMenuItem`.
    var internalIdentifier: String? {
        guard let id = Mirror.firstChild(
            withLabel: "id", in: self
        )?.value else {
            return nil
        }
        
        return "\(id)"
    }
    
    /// A callback which is associated directly with this `NSMenuItem`.
    var internalItemAction: (() -> Void)? {
        guard 
            let platformItemAction = Mirror.firstChild(
                withLabel: "platformItemAction", in: self)?.value,
            let typeErasedCallback = Mirror.firstChild(
                in: platformItemAction)?.value
        else {
            return nil
        }
            
        return Mirror.firstChild(
            in: typeErasedCallback
        )?.value as? () -> Void
    }
    
}

// MARK: - NSMenu (Private)

extension NSMenu {
    
    /// Get the first `NSMenuItem` whose internal identifier string matches the given value.
    func item(withInternalIdentifier identifier: String) -> NSMenuItem? {
        self.items.first(where: {
            $0.internalIdentifier?.elementsEqual(identifier) ?? false
        })
    }
    
    /// Get the first `NSMenuItem` whose title is equivalent to the localized string referenced
    /// by the given localized string key in the localization table identified by the given table name
    /// from the bundle located at the given bundle path.
    func item(
        withLocalizedTitle localizedTitleKey: String,
        inTable tableName: String = "MenuCommands",
        fromBundle bundlePath: String = "/System/Library/Frameworks/AppKit.framework"
    ) -> NSMenuItem? {
        guard let localizationResource = Bundle(path: bundlePath) else {
            return nil
        }
        
        return self.item(withTitle: NSLocalizedString(
            localizedTitleKey,
            tableName: tableName,
            bundle: localizationResource,
            comment: ""))
    }
    
}

// MARK: - Mirror (Helper)

fileprivate extension Mirror {
    
    /// The unconditional first child of the reflection subject.
    var firstChild: Child? { self.children.first }
    
    /// The first child of the reflection subject whose label matches the given string.
    func firstChild(withLabel label: String) -> Child? {
        self.children.first(where: {
            $0.label?.elementsEqual(label) ?? false
        })
    }
    
    /// The unconditional first child of the given subject.
    static func firstChild(in subject: Any) -> Child? {
        Mirror(reflecting: subject).firstChild
    }
    
    /// The first child of the given subject whose label matches the given string.
    static func firstChild(
        withLabel label: String, in subject: Any
    ) -> Child? {
        Mirror(reflecting: subject).firstChild(withLabel: label)
    }
    
}
