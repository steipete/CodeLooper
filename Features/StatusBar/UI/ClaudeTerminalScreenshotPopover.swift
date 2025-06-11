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
    @StateObject private var screenshotAnalyzer = CursorScreenshotAnalyzer()
    
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
            do {
                // First, find the terminal window using TTY mapping
                guard let terminalWindow = await findTerminalWindow() else {
                    await MainActor.run {
                        self.isLoading = false
                        self.errorMessage = "Could not find terminal window for this Claude instance"
                    }
                    return
                }
                
                // Find the SCWindow for this terminal window
                let scWindow = await findSCWindow(for: terminalWindow)
                
                // Capture the screenshot
                let image = try await screenshotAnalyzer.captureCursorWindow(targetSCWindow: scWindow)
                
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
                    logger.error("Failed to capture screenshot for Claude instance \(instance.id): \(error)")
                }
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

