import AppKit

/// A text field that passes through mouse events and dims when window is inactive
@MainActor
class PassThroughTextField: NSTextField {
    // MARK: Lifecycle

    deinit {
        // Cleanup will happen when window is removed
    }

    // MARK: Internal

    override var mouseDownCanMoveWindow: Bool {
        true
    }

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

    override func hitTest(_: NSPoint) -> NSView? {
        nil
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
