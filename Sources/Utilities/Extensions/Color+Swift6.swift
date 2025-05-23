import Foundation
import SwiftUI

// MARK: - Swift 6 Color Sendable Support

// In Swift 6, Color is automatically Sendable
// No need for explicit Sendable conformance
// So we remove the @unchecked Sendable extension

// MARK: - Color Extensions for Conversion

// Extend SwiftUI Color to have better conversion to NSColor
extension Color {
    func toNSColor() -> NSColor {
        // This is a simplified conversion just returning system colors
        if self == .green {
            NSColor.systemGreen
        } else if self == .red {
            NSColor.systemRed
        } else if self == .blue {
            NSColor.systemBlue
        } else if self == .orange {
            NSColor.systemOrange
        } else if self == .primary {
            NSColor.labelColor
        } else if self == .secondary {
            NSColor.secondaryLabelColor
        } else {
            NSColor.controlAccentColor
        }
    }
}
