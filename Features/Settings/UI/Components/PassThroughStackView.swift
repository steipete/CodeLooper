import AppKit

/// A stack view that passes through all mouse events to its parent
class PassThroughStackView: NSStackView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func hitTest(_: NSPoint) -> NSView? {
        // Return nil to make this view transparent to mouse events
        nil
    }
}