import AppKit

/// An image view that passes through all mouse events and dims when window is inactive
@MainActor
class PassThroughImageView: NSImageView {
    // MARK: Lifecycle

    deinit {
        // Cleanup will happen when window is removed
    }

    // MARK: Internal

    override var mouseDownCanMoveWindow: Bool {
        true // Allow window dragging from the icon
    }

    var onClick: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Remove previous observers
        if let observer = becomeKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            becomeKeyObserver = nil
        }
        if let observer = resignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            resignKeyObserver = nil
        }

        // Set initial state
        updateAppearance()

        // Observe window focus changes
        if let window {
            becomeKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updateAppearance()
                }
            }

            resignKeyObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updateAppearance()
                }
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        // Call onClick if it's a single click
        onClick?()
        // Pass the event to super to allow window dragging
        super.mouseDown(with: event)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Return self to capture mouse events
        let boundsCheck = self.bounds.contains(self.convert(point, from: superview))
        return boundsCheck ? self : nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    // MARK: Private

    private var becomeKeyObserver: NSObjectProtocol?
    private var resignKeyObserver: NSObjectProtocol?

    private func updateAppearance() {
        if let window, window.isKeyWindow {
            self.alphaValue = 1.0
        } else {
            self.alphaValue = 0.6 // Dimmed when not focused
        }
    }
}
