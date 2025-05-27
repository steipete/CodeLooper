import AppKit
import Foundation

// Simple utility to generate a symbol.png file for the menu bar
// Run with: swift SymbolGenerator.swift

// Use this script separately if needed
enum SymbolGenerator {
    // MARK: Internal

    static func main() {
        let image = createSymbolImage()
        saveSymbolImages(image)
    }

    // MARK: Private

    /// Creates the main symbol image with proper menu bar sizing and styling
    private static func createSymbolImage() -> NSImage {
        // Create proper size for menu bar (22x22 is standard)
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)

        image.lockFocus()

        configureRenderingContext()
        drawCircleBackground(size: size)
        drawCenterText(size: size)

        image.unlockFocus()

        // Set template mode for proper menu bar appearance
        image.isTemplate = true

        return image
    }

    /// Configures the graphics context for optimal rendering
    private static func configureRenderingContext() {
        if let context = NSGraphicsContext.current {
            context.shouldAntialias = true
            context.imageInterpolation = .high
        }
    }

    /// Draws the circular background for the symbol
    private static func drawCircleBackground(size: NSSize) {
        let circlePath = NSBezierPath(ovalIn: NSRect(
            x: 1,
            y: 1,
            width: size.width - 2,
            height: size.height - 2
        ))

        // Use black for high contrast when in template mode
        NSColor.black.setFill()
        circlePath.fill()
    }

    /// Draws the "C" letter in the center of the symbol
    private static func drawCenterText(size: NSSize) {
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

        "C".draw(in: textRect, withAttributes: attributes)
    }

    /// Saves the symbol image in multiple variants (standard, dark, light)
    private static func saveSymbolImages(_ image: NSImage) {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData)
        else {
            print("Error: Failed to create image representation")
            return
        }

        let resourcesDirURL = getResourcesDirectoryURL()

        do {
            try createResourcesDirectoryIfNeeded(at: resourcesDirURL)
            try saveStandardSymbol(bitmapRep, to: resourcesDirURL)
            try saveDarkModeSymbol(image, to: resourcesDirURL)
            try saveLightModeSymbol(image, to: resourcesDirURL)
        } catch {
            print("Error saving images: \(error.localizedDescription)")
        }
    }

    /// Returns the URL for the Resources directory
    private static func getResourcesDirectoryURL() -> URL {
        let fileManager = FileManager.default
        let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        return currentDirectoryURL.appendingPathComponent("Resources", isDirectory: true)
    }

    /// Creates the Resources directory if it doesn't exist
    private static func createResourcesDirectoryIfNeeded(at url: URL) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Saves the standard symbol image
    private static func saveStandardSymbol(_ bitmapRep: NSBitmapImageRep, to resourcesURL: URL) throws {
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw NSError(
                domain: "SymbolGenerator",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"]
            )
        }

        let standardPath = resourcesURL.appendingPathComponent("symbol.png")
        try pngData.write(to: standardPath)
        print("Successfully created symbol.png at \(standardPath.path)")
    }

    /// Saves the dark mode variant of the symbol
    private static func saveDarkModeSymbol(_ image: NSImage, to resourcesURL: URL) throws {
        let darkImage = adjustImageForDarkMode(image)
        try saveImageVariant(darkImage, fileName: "symbol-dark.png", to: resourcesURL)
    }

    /// Saves the light mode variant of the symbol
    private static func saveLightModeSymbol(_ image: NSImage, to resourcesURL: URL) throws {
        let lightImage = adjustImageForLightMode(image)
        try saveImageVariant(lightImage, fileName: "symbol-light.png", to: resourcesURL)
    }

    /// Helper method to save an image variant
    private static func saveImageVariant(_ image: NSImage, fileName: String, to resourcesURL: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:])
        else {
            throw NSError(
                domain: "SymbolGenerator",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create \(fileName) data"]
            )
        }

        let filePath = resourcesURL.appendingPathComponent(fileName)
        try pngData.write(to: filePath)
        print("Successfully created \(fileName) at \(filePath.path)")
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
