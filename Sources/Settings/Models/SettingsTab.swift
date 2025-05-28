import Foundation
import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case supervision = "Supervision"
    case ruleSets = "Rule Sets"
    case externalMCPs = "External MCPs"
    case ai = "AI"
    case advanced = "Advanced"
    case log = "Log"
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
        case .log: "doc.text"
        case .debug: "ladybug"
        }
    }
}
