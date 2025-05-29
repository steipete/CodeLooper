import AppKit
import Foundation

/// Utility for processing images for AI analysis and other operations.
///
/// ImageProcessor provides standardized image conversion and optimization
/// functionality used across the application, particularly for AI analysis
/// services that require specific image formats and compression settings.
///
/// ## Topics
///
/// ### Image Conversion
/// - ``convertToJPEG(_:compressionFactor:)``
/// - ``convertToBase64(_:compressionFactor:)``
/// - ``optimizeForAI(_:)``
///
/// ### Error Handling
/// - ``ImageProcessingError``
public enum ImageProcessor {
    /// Errors that can occur during image processing
    public enum ImageProcessingError: Error, LocalizedError {
        case invalidImage
        case conversionFailed
        case compressionFailed
        case dataCorrupted

        // MARK: Public

        public var errorDescription: String? {
            switch self {
            case .invalidImage:
                "The provided image is invalid or corrupted"
            case .conversionFailed:
                "Failed to convert image to required format"
            case .compressionFailed:
                "Failed to compress image data"
            case .dataCorrupted:
                "Image data appears to be corrupted"
            }
        }
    }

    /// Standard compression factor for AI analysis (balances quality vs size)
    public static let aiAnalysisCompressionFactor: CGFloat = 0.8

    /// Converts an NSImage to JPEG data with specified compression
    /// - Parameters:
    ///   - image: The source image to convert
    ///   - compressionFactor: JPEG compression factor (0.0 = maximum compression, 1.0 = no compression)
    /// - Returns: JPEG data representation of the image
    /// - Throws: ImageProcessingError if conversion fails
    public static func convertToJPEG(
        _ image: NSImage,
        compressionFactor: CGFloat = aiAnalysisCompressionFactor
    ) throws -> Data {
        // Get TIFF representation first
        guard let tiffData = image.tiffRepresentation else {
            throw ImageProcessingError.invalidImage
        }

        // Create bitmap representation
        guard let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw ImageProcessingError.conversionFailed
        }

        // Convert to JPEG with compression
        guard let jpegData = bitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionFactor]
        ) else {
            throw ImageProcessingError.compressionFailed
        }

        return jpegData
    }

    /// Converts an NSImage to base64-encoded JPEG string
    /// - Parameters:
    ///   - image: The source image to convert
    ///   - compressionFactor: JPEG compression factor
    /// - Returns: Base64-encoded JPEG string
    /// - Throws: ImageProcessingError if conversion fails
    public static func convertToBase64(
        _ image: NSImage,
        compressionFactor: CGFloat = aiAnalysisCompressionFactor
    ) throws -> String {
        let jpegData = try convertToJPEG(image, compressionFactor: compressionFactor)
        return jpegData.base64EncodedString()
    }

    /// Optimizes an image specifically for AI analysis
    /// - Parameter image: The source image to optimize
    /// - Returns: Optimized JPEG data suitable for AI analysis
    /// - Throws: ImageProcessingError if optimization fails
    public static func optimizeForAI(_ image: NSImage) throws -> Data {
        try convertToJPEG(image, compressionFactor: aiAnalysisCompressionFactor)
    }

    /// Validates that image data is not corrupted
    /// - Parameter data: Image data to validate
    /// - Returns: True if data appears valid
    public static func validateImageData(_ data: Data) -> Bool {
        // Basic validation - check if data is not empty and has minimum size
        guard data.count > 100 else { return false }

        // Try to create an image from the data
        guard NSImage(data: data) != nil else { return false }

        return true
    }

    /// Gets image dimensions without fully loading the image
    /// - Parameter data: Image data to analyze
    /// - Returns: Image size or nil if cannot be determined
    public static func getImageSize(from data: Data) -> NSSize? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight as String] as? NSNumber
        else {
            return nil
        }

        return NSSize(width: width.doubleValue, height: height.doubleValue)
    }
}
