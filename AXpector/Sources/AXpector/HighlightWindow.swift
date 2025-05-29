import Cocoa

/// Transparent overlay window for highlighting accessibility elements on screen.
///
/// HighlightWindow provides:
/// - Transparent, click-through overlay functionality
/// - High window level to appear above application content
/// - Multi-space visibility for consistent highlighting
/// - Mouse event pass-through for uninterrupted interaction
/// - Configurable positioning and sizing for element boundaries
///
/// Used by AXpector to visually indicate selected accessibility elements
/// by drawing colored borders around their screen positions.
class HighlightWindow: NSWindow {
    // MARK: Lifecycle

    override init(
        contentRect: NSRect,
        styleMask _: NSWindow.StyleMask,
        backing _: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: [.borderless], backing: .buffered, defer: flag)

        self.isOpaque = false
        self.backgroundColor = .clear // Make window background transparent
        self.level = .statusBar // Keep it above most other windows, but below menus/Dock
        self.ignoresMouseEvents = true // Pass mouse events through
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary] // Show on all spaces
    }

    // MARK: Internal

    // Clicks through the window
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
