import Foundation
import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case supervision = "Supervision"
    case ruleSets = "Rule Sets"
    case externalMCPs = "External MCPs"
    case advanced = "Advanced"
    case log = "Log"
    case developer = "Developer"
    case cursorInputWatcher = "Cursor Input Watcher"
    case about = "About"

    public var id: String { self.rawValue }

    public var systemImageName: String {
        switch self {
        case .general: return "gearshape"
        case .supervision: return "eye"
        case .ruleSets: return "list.bullet.rectangle"
        case .externalMCPs: return "puzzlepiece.extension"
        case .advanced: return "slider.horizontal.3"
        case .log: return "doc.text"
        case .developer: return "hammer"
        case .cursorInputWatcher: return "eyeglass"
        case .about: return "info.circle"
        }
    }
} 