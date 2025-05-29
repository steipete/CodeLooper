import AppKit

/// A view that allows window dragging from its area by being transparent to events
class DraggableView: NSView {
    override var mouseDownCanMoveWindow: Bool {
        true
    }

    override func hitTest(_: NSPoint) -> NSView? {
        // Return nil to make this view transparent to mouse events
        // This allows the window to handle the drag
        nil
    }
}