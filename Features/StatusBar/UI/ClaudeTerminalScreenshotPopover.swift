import AppKit
import AXorcist
import DesignSystem
import Diagnostics
@preconcurrency import ScreenCaptureKit
import SwiftUI

struct ClaudeTerminalScreenshotPopover: View {
    let instance: ClaudeInstance
    
    @State private var screenshotImage: NSImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    // Removed WindowScreenshotService - will use ScreenCaptureKit directly
    
    private let logger = Logger(category: .ui)
    
    var body: some View {
        VStack(spacing: Spacing.medium) {
            // Header
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(ColorPalette.accent)
                Text("Terminal Screenshot")
                    .font(Typography.callout(.semibold))
                Spacer()
            }
            
            // Screenshot content
            Group {
                if isLoading {
                    VStack(spacing: Spacing.small) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Capturing terminal window...")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .frame(width: 400, height: 300)
                } else if let image = screenshotImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 600, maxHeight: 400)
                        .cornerRadius(8)
                        .shadow(radius: 2)
                } else if let error = errorMessage {
                    VStack(spacing: Spacing.small) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(ColorPalette.warning)
                        Text("Failed to capture screenshot")
                            .font(Typography.callout(.medium))
                        Text(error)
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(width: 400, height: 300)
                } else {
                    VStack(spacing: Spacing.small) {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(ColorPalette.textSecondary)
                        Text("No screenshot available")
                            .font(Typography.callout(.medium))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .frame(width: 400, height: 300)
                }
            }
            
            // Instance info
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                HStack {
                    Text("Folder:")
                        .font(Typography.caption1(.medium))
                        .foregroundColor(ColorPalette.textSecondary)
                    Text(instance.folderName)
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.text)
                    Spacer()
                }
                
                HStack {
                    Text("TTY:")
                        .font(Typography.caption1(.medium))
                        .foregroundColor(ColorPalette.textSecondary)
                    Text(instance.ttyPath)
                        .font(Typography.caption2())
                        .foregroundColor(ColorPalette.textTertiary)
                        .textSelection(.enabled)
                    Spacer()
                }
                
                HStack {
                    Text("PID:")
                        .font(Typography.caption1(.medium))
                        .foregroundColor(ColorPalette.textSecondary)
                    Text(String(instance.pid))
                        .font(Typography.caption2())
                        .foregroundColor(ColorPalette.textTertiary)
                    Spacer()
                }
            }
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.xSmall)
            .background(ColorPalette.backgroundTertiary)
            .cornerRadius(6)
            
            // Action buttons
            HStack(spacing: Spacing.medium) {
                DSButton("Refresh", style: .secondary, size: .small) {
                    captureScreenshot()
                }
                .disabled(isLoading)
                
                if screenshotImage != nil {
                    DSButton("Save to Desktop", style: .primary, size: .small) {
                        saveImageToDesktop()
                    }
                }
            }
        }
        .padding(Spacing.large)
        .frame(minWidth: 500, maxWidth: 700)
        .withDesignSystem()
        .onAppear {
            captureScreenshot()
        }
    }
    
    private func captureScreenshot() {
        isLoading = true
        errorMessage = nil
        screenshotImage = nil
        
        Task {
            logger.info("Starting screenshot capture for Claude instance: \(instance.folderName) (PID: \(instance.pid), TTY: \(instance.ttyPath))")
            
            // First, find the terminal window using TTY mapping
            if let terminalWindow = await findTerminalWindow() {
                logger.info("Found terminal window via TTY mapping")
                await captureWindowScreenshot(terminalWindow)
                return
            }
            
            logger.warning("Could not find terminal window for TTY: \(instance.ttyPath)")
            
            // Try alternative approach: find any terminal window with Claude in title
            if let fallbackWindow = await findTerminalWindowByTitle() {
                logger.info("Found terminal window using title-based search")
                await captureWindowScreenshot(fallbackWindow)
                return
            }
            
            // If we couldn't find a window, show error
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Could not find terminal window for this Claude instance. TTY: \(instance.ttyPath)"
            }
        }
    }
    
    private func captureWindowScreenshot(_ terminalWindow: Element) async {
        do {
            // Find the SCWindow for this terminal window
            let scWindow = await findSCWindow(for: terminalWindow)
            
            if scWindow == nil {
                logger.warning("Could not find SCWindow for terminal window")
            }
            
            // Capture the screenshot using ScreenCaptureKit directly
            let image: NSImage?
            if let scWindow = scWindow {
                image = try await captureScreenshot(of: scWindow)
            } else {
                image = nil
            }
            
            await MainActor.run {
                self.screenshotImage = image
                self.isLoading = false
                
                if image == nil {
                    self.errorMessage = "Could not capture window. The window may be minimized or hidden."
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                logger.error("Screenshot capture error: \(error)")
            }
        }
    }
    
    @MainActor
    private func findTerminalWindow() async -> Element? {
        // Use TTYWindowMappingService to find the window
        if !instance.ttyPath.isEmpty {
            return TTYWindowMappingService.shared.findWindowForTTY(instance.ttyPath)
        }
        return nil
    }
    
    @MainActor
    private func findTerminalWindowByTitle() async -> Element? {
        logger.info("Attempting to find terminal window by title containing: \(instance.folderName)")
        
        let terminalBundleIDs = [
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "com.github.wez.wezterm",
            "dev.warp.Warp-Stable",
            "net.kovidgoyal.kitty",
            "co.zeit.hyper",
            "com.mitchellh.ghostty"
        ]
        
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier,
                  terminalBundleIDs.contains(bundleID) else { continue }
            
            logger.debug("Checking terminal app: \(bundleID)")
            
            guard let appElement = Element.application(for: app.processIdentifier),
                  let windows = appElement.windows() else { continue }
            
            for window in windows {
                if let title = window.title()?.lowercased() {
                    // Check if title contains the folder name or "claude"
                    if title.contains(instance.folderName.lowercased()) ||
                       title.contains("claude") {
                        logger.info("Found window with matching title: '\(title)'")
                        return window
                    }
                }
            }
        }
        
        // If no match found, try to get the focused terminal window
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier,
                  terminalBundleIDs.contains(bundleID),
                  app.isActive else { continue }
            
            if let appElement = Element.application(for: app.processIdentifier),
               let focusedWindow = appElement.focusedWindow() {
                logger.info("Using focused window from active terminal app: \(bundleID)")
                return focusedWindow
            }
        }
        
        return nil
    }
    
    private func findSCWindow(for element: Element) async -> SCWindow? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            // Get window ID from the element using WindowInfoHelper
            let windowID = await MainActor.run {
                WindowInfoHelper.getWindowID(from: element)
            }
            
            guard let windowID else {
                logger.warning("Could not get window ID from element")
                return nil
            }
            
            // Find matching SCWindow
            return content.windows.first { window in
                window.windowID == windowID
            }
        } catch {
            logger.error("Failed to get shareable content: \(error)")
            return nil
        }
    }
    
    private func captureScreenshot(of window: SCWindow) async throws -> NSImage? {
        let configuration = SCStreamConfiguration()
        configuration.width = Int(window.frame.width)
        configuration.height = Int(window.frame.height)
        configuration.scalesToFit = true
        configuration.showsCursor = false
        
        let filter = SCContentFilter(desktopIndependentWindow: window)
        
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
    
    private func saveImageToDesktop() {
        guard let image = screenshotImage else { return }
        
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let timestamp = DateFormatter().apply { formatter in
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        }.string(from: Date())
        let filename = "CodeLooper_Terminal_\(instance.folderName)_\(timestamp).png"
        let fileURL = desktopURL.appendingPathComponent(filename)
        
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapRep.representation(using: .png, properties: [:]) {
            
            do {
                try pngData.write(to: fileURL)
                logger.info("Screenshot saved to: \(fileURL.path)")
                
                // Show in Finder
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            } catch {
                logger.error("Failed to save screenshot: \(error)")
                self.errorMessage = "Failed to save screenshot: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Extension for DateFormatter

private extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}

