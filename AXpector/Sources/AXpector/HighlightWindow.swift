import Cocoa

class HighlightWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: flag)

        self.isOpaque = false
        self.backgroundColor = .clear // Make window background transparent
        self.level = .statusBar // Keep it above most other windows, but below menus/Dock
        self.ignoresMouseEvents = true // Pass mouse events through
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Show on all spaces
    }

    // Clicks through the window
    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
} 