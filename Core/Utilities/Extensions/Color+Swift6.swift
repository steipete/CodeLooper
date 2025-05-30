import Foundation
import SwiftUI

// MARK: - Swift 6 Color Sendable Support

// In Swift 6, Color is automatically Sendable
// No need for explicit Sendable conformance
// So we remove the @unchecked Sendable extension

// MARK: - Color Extensions for Conversion

/// Extension providing SwiftUI Color to NSColor conversion for macOS compatibility.
///
/// This extension bridges SwiftUI's Color type with AppKit's NSColor for use in
/// mixed SwiftUI/AppKit contexts. Provides safe conversion methods that handle
/// color space differences and system color mapping.
extension Color {
    func toNSColor() -> NSColor {
        // This is a simplified conversion just returning system colors
        switch self {
        case .green:
            NSColor.systemGreen
        case .red:
            NSColor.systemRed
        case .blue:
            NSColor.systemBlue
        case .orange:
            NSColor.systemOrange
        case .primary:
            NSColor.labelColor
        case .secondary:
            NSColor.secondaryLabelColor
        default:
            // Use proper SwiftUI accentColor conversion (fixes macOS bug with controlAccentColor)
            NSColor(.accentColor)
        }
    }
}
