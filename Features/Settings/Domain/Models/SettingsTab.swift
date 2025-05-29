import Foundation
import SwiftUI

/// Defines the available tabs in the settings window.
///
/// Each tab represents a distinct configuration area:
/// - general: Basic app preferences and behavior
/// - supervision: Cursor monitoring configuration
/// - ruleSets: Intervention rule management
/// - externalMCPs: Model Context Protocol integrations
/// - ai: AI provider settings
/// - advanced: Power user options
/// - debug: Diagnostic tools and logs
public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case supervision = "Supervision"
    case ruleSets = "Rule Sets"
    case externalMCPs = "External MCPs"
    case ai = "AI"
    case advanced = "Advanced"
    case debug = "Debug"

    // MARK: Public

    public var id: String { self.rawValue }

    public var systemImageName: String {
        switch self {
        case .general: "gearshape"
        case .supervision: "eye"
        case .ruleSets: "list.bullet.rectangle"
        case .externalMCPs: "puzzlepiece.extension"
        case .ai: "brain"
        case .advanced: "slider.horizontal.3"
        case .debug: "ladybug"
        }
    }
}
