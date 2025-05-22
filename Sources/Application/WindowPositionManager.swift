import Cocoa
import Foundation

/// Manages window positions and provides AppleScript support for window control
@objc(WindowPositionManager)
@MainActor
final class WindowPositionManager: NSObject {
    // MARK: - Singleton

    @MainActor static let shared = WindowPositionManager()

    // MARK: - Properties

    private var savedWindowPositions: [String: NSRect] = [:]
    private let windowPositionsKey = "savedWindowPositions"

    // MARK: - Initialization

    override private init() {
        super.init()
        loadSavedPositions()
    }

    // MARK: - Public Methods

    /// Move a window to a specific position
    /// - Parameters:
    ///   - window: The window to move
    ///   - position: The new position (x, y coordinates)
    @objc
    func moveWindow(_ window: NSWindow?, to position: NSPoint) {
        guard let window = window else { return }

        let newFrame = NSRect(
            origin: position,
            size: window.frame.size
        )

        window.setFrame(newFrame, display: true, animate: true)
    }

    /// Resize a window
    /// - Parameters:
    ///   - window: The window to resize
    ///   - size: The new size (width, height)
    @objc
    func resizeWindow(_ window: NSWindow?, to size: NSSize) {
        guard let window = window else { return }

        let newFrame = NSRect(
            origin: window.frame.origin,
            size: size
        )

        window.setFrame(newFrame, display: true, animate: true)
    }

    /// Move and resize a window
    /// - Parameters:
    ///   - window: The window to move and resize
    ///   - frame: The new frame (x, y, width, height)
    @objc
    func setWindowFrame(_ window: NSWindow?, to frame: NSRect) {
        guard let window = window else { return }
        window.setFrame(frame, display: true, animate: true)
    }

    /// Center a window on screen
    /// - Parameter window: The window to center
    @objc
    func centerWindow(_ window: NSWindow?) {
        guard let window = window else { return }
        window.center()
    }

    /// Save current position of a window
    /// - Parameters:
    ///   - window: The window to save position for
    ///   - identifier: Unique identifier for the window
    func saveWindowPosition(_ window: NSWindow?, identifier: String) {
        guard let window = window else { return }
        savedWindowPositions[identifier] = window.frame
        saveToDisk()
    }

    /// Restore saved position of a window
    /// - Parameters:
    ///   - window: The window to restore position for
    ///   - identifier: Unique identifier for the window
    @discardableResult
    func restoreWindowPosition(_ window: NSWindow?, identifier: String) -> Bool {
        guard let window = window, let savedFrame = savedWindowPositions[identifier] else {
            return false
        }

        window.setFrame(savedFrame, display: true, animate: true)
        return true
    }

    // MARK: - Private Methods

    private func saveToDisk() {
        // Convert NSRect to Dictionary for serialization
        let encodablePositions = savedWindowPositions.mapValues { rect -> [String: CGFloat] in
            return [
                "x": rect.origin.x,
                "y": rect.origin.y,
                "width": rect.size.width,
                "height": rect.size.height
            ]
        }

        UserDefaults.standard.set(encodablePositions, forKey: windowPositionsKey)
    }

    private func loadSavedPositions() {
        guard let savedData = UserDefaults.standard.dictionary(forKey: windowPositionsKey)
            as? [String: [String: CGFloat]]
        else {
            return
        }

        savedWindowPositions = savedData.compactMapValues { dict -> NSRect? in
            guard let xPos = dict["x"],
                let yPos = dict["y"],
                let width = dict["width"],
                let height = dict["height"]
            else {
                return nil
            }

            return NSRect(x: xPos, y: yPos, width: width, height: height)
        }
    }
}

// MARK: - AppleScript Support

extension WindowPositionManager {
    /// Get the main application window (welcome window or settings window)
    @objc
    func mainWindow() -> NSWindow? {
        // First check for welcome window
        if let welcomeWindow = NSApp.windows.first(where: {
            $0.title.contains("Welcome") || $0.title.contains("Friendship")
        }) {
            return welcomeWindow
        }

        // Then check for settings window
        return NSApp.windows.first { $0.title.contains("Settings") || $0.title.contains("Preferences") }
    }

    /// AppleScript command to move window to position
    @objc(moveWindowToX:y:)
    func moveWindowToPosition(_ xPos: NSNumber, _ yPos: NSNumber) {
        let position = NSPoint(x: xPos.doubleValue, y: yPos.doubleValue)
        moveWindow(mainWindow(), to: position)
    }

    /// AppleScript command to resize window
    @objc(resizeWindowToWidth:height:)
    func resizeWindowToSize(_ width: NSNumber, _ height: NSNumber) {
        let size = NSSize(width: width.doubleValue, height: height.doubleValue)
        resizeWindow(mainWindow(), to: size)
    }

    /// AppleScript command to center window
    @objc(centerWindow)
    func centerWindowFromScript() {
        centerWindow(mainWindow())
    }

    /// AppleScript command to save window position
    @objc(saveWindowPositionWithName:)
    func saveWindowPositionWithName(_ name: String) {
        saveWindowPosition(mainWindow(), identifier: name)
    }

    /// AppleScript command to restore window position
    @objc(restoreWindowPositionWithName:)
    func restoreWindowPositionWithName(_ name: String) {
        _ = restoreWindowPosition(mainWindow(), identifier: name)
    }
}
