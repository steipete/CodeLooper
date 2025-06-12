import AppKit
import Diagnostics
import Foundation
@preconcurrency import ScreenCaptureKit

/// A generic window screenshot service that can capture any window
@MainActor
public final class WindowScreenshotService: Loggable {
    private let imageScaleFactor: CGFloat = 1.0
    
    public init() {}
    
    /// Captures a screenshot of a specific window
    /// - Parameters:
    ///   - scWindow: The SCWindow to capture. If nil, captures the frontmost window
    ///   - bundleIdentifier: Optional bundle identifier to find a specific app's window
    ///   - windowTitle: Optional window title to match (partial match supported)
    /// - Returns: The captured image or nil if capture failed
    public func captureWindow(
        targetSCWindow: SCWindow? = nil,
        bundleIdentifier: String? = nil,
        windowTitle: String? = nil
    ) async throws -> NSImage? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        var windowToCapture: SCWindow? = targetSCWindow
        
        // If no specific window provided, try to find one based on criteria
        if windowToCapture == nil {
            if let bundleIdentifier = bundleIdentifier {
                windowToCapture = content.windows.first { window in
                    window.owningApplication?.bundleIdentifier == bundleIdentifier
                }
            } else if let windowTitle = windowTitle {
                windowToCapture = content.windows.first { window in
                    if let title = window.title?.lowercased() {
                        return title.contains(windowTitle.lowercased())
                    }
                    return false
                }
            }
        }
        
        guard let finalWindowToCapture = windowToCapture else {
            logger.info("No suitable window found for capture with criteria - bundleID: \(bundleIdentifier ?? "nil"), title: \(windowTitle ?? "nil")")
            return nil
        }
        
        let scaledWidth = Int(finalWindowToCapture.frame.width * imageScaleFactor)
        let scaledHeight = Int(finalWindowToCapture.frame.height * imageScaleFactor)
        
        let configuration = SCStreamConfiguration()
        configuration.width = scaledWidth
        configuration.height = scaledHeight
        configuration.scalesToFit = true
        configuration.showsCursor = false
        
        let filter = SCContentFilter(desktopIndependentWindow: finalWindowToCapture)
        
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        
        let nsImage = NSImage(cgImage: image, size: NSSize(
            width: scaledWidth,
            height: scaledHeight
        ))
        
        return nsImage
    }
    
    /// Captures a screenshot of a terminal window
    /// - Parameters:
    ///   - terminalApp: The terminal application bundle identifier
    ///   - windowTitle: Optional window title to match
    /// - Returns: The captured image or nil if capture failed
    public func captureTerminalWindow(
        terminalApp: String? = nil,
        windowTitle: String? = nil
    ) async throws -> NSImage? {
        // List of common terminal applications
        let terminalBundleIDs = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "com.github.wez.wezterm",
            "dev.warp.Warp-Stable",
            "net.kovidgoyal.kitty",
            "co.zeit.hyper",
            "com.mitchellh.ghostty"
        ]
        
        if let terminalApp = terminalApp {
            return try await captureWindow(bundleIdentifier: terminalApp, windowTitle: windowTitle)
        }
        
        // Try each terminal app until we find one with a matching window
        for bundleID in terminalBundleIDs {
            if let image = try await captureWindow(bundleIdentifier: bundleID, windowTitle: windowTitle) {
                logger.info("Successfully captured terminal window from \(bundleID)")
                return image
            }
        }
        
        logger.warning("No terminal window found matching criteria")
        return nil
    }
}