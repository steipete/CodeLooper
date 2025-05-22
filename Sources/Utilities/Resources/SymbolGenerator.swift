import AppKit
import Foundation

// Simple utility to generate a symbol.png file for the menu bar
// Run with: swift SymbolGenerator.swift

// Main entry point - removed @main attribute to avoid conflict
// Use this script separately if needed
enum SymbolGenerator {
    static func main() {
        // Create proper size for menu bar (22x22 is standard)
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)

        image.lockFocus()

        // Enable antialiasing for smooth rendering
        if let context = NSGraphicsContext.current {
            context.shouldAntialias = true
            context.imageInterpolation = .high
        }

        // Draw a circle with a high contrast color
        let circlePath = NSBezierPath(ovalIn: NSRect(
            x: 1,
            y: 1,
            width: size.width - 2,
            height: size.height - 2
        ))

        // Use black for high contrast when in template mode
        NSColor.black.setFill()
        circlePath.fill()

        // Draw the letter "F" for FriendshipAI in the center with white
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let textRect = NSRect(
            x: 0,
            y: size.height / 2 - 8,
            width: size.width,
            height: 16
        )

        "F".draw(in: textRect, withAttributes: attributes)

        image.unlockFocus()

        // Set template mode for proper menu bar appearance
        image.isTemplate = true

        // Save the image
        if let tiffData = image.tiffRepresentation,
           let bitmapRep = NSBitmapImageRep(data: tiffData) {
            // Get base directory path using FileManager
            let fileManager = FileManager.default
            let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            let resourcesDirURL = currentDirectoryURL.appendingPathComponent("Resources", isDirectory: true)

            do {
                // Create Resources directory if it doesn't exist
                if !fileManager.fileExists(atPath: resourcesDirURL.path) {
                    try fileManager.createDirectory(at: resourcesDirURL, withIntermediateDirectories: true)
                }

                // Standard symbol (for general use)
                if let standardPNGData = bitmapRep.representation(using: .png, properties: [:]) {
                    let standardPath = resourcesDirURL.appendingPathComponent("symbol.png")
                    try standardPNGData.write(to: standardPath)
                    print("Successfully created symbol.png at \(standardPath.path)")
                }

                // Create a dark mode version with adjusted properties
                let darkImage = adjustImageForDarkMode(image)
                if let darkTiffData = darkImage.tiffRepresentation,
                   let darkRep = NSBitmapImageRep(data: darkTiffData),
                   let darkPNGData = darkRep.representation(using: .png, properties: [:]) {
                    let darkPath = resourcesDirURL.appendingPathComponent("symbol-dark.png")
                    try darkPNGData.write(to: darkPath)
                    print("Successfully created symbol-dark.png at \(darkPath.path)")
                }

                // Create a light mode version with adjusted properties
                let lightImage = adjustImageForLightMode(image)
                if let lightTiffData = lightImage.tiffRepresentation,
                   let lightRep = NSBitmapImageRep(data: lightTiffData),
                   let lightPNGData = lightRep.representation(using: .png, properties: [:]) {
                    let lightPath = resourcesDirURL.appendingPathComponent("symbol-light.png")
                    try lightPNGData.write(to: lightPath)
                    print("Successfully created symbol-light.png at \(lightPath.path)")
                }
            } catch {
                print("Error saving images: \(error.localizedDescription)")
            }
        }
    }

    /// Adjusts an image for dark mode appearance
    private static func adjustImageForDarkMode(_ image: NSImage) -> NSImage {
        // Create a copy of the image to modify
        let darkImage = NSImage(size: image.size)

        darkImage.lockFocus()
        // Draw with a slight brightness adjustment
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let context = NSGraphicsContext.current?.cgContext
            context?.setAlpha(1.0) // Full opacity
            context?.setShadow(offset: CGSize(width: 0, height: 0), blur: 0, color: nil)

            let rect = CGRect(origin: .zero, size: image.size)
            context?.draw(cgImage, in: rect)

            // For dark mode, possibly add a subtle glow or adjust color
            // This is a placeholder for actual image adjustments
        }
        darkImage.unlockFocus()

        return darkImage
    }

    /// Adjusts an image for light mode appearance
    private static func adjustImageForLightMode(_ image: NSImage) -> NSImage {
        // Create a copy of the image to modify
        let lightImage = NSImage(size: image.size)

        lightImage.lockFocus()
        // Draw with a slight brightness adjustment
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let context = NSGraphicsContext.current?.cgContext
            context?.setAlpha(1.0) // Full opacity

            let rect = CGRect(origin: .zero, size: image.size)
            context?.draw(cgImage, in: rect)

            // For light mode, consider adding a subtle shadow or adjusting color
            // This is a placeholder for actual image adjustments
        }
        lightImage.unlockFocus()

        return lightImage
    }
}
