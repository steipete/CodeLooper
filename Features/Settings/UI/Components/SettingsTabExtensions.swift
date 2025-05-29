extension SettingsTab {
    var title: String {
        switch self {
        case .general: "General"
        case .supervision: "Supervision"
        case .ruleSets: "Rules"
        case .externalMCPs: "Extensions"
        case .ai: "AI"
        case .advanced: "Advanced"
        case .debug: "Debug"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .supervision: "eye"
        case .ruleSets: "checklist"
        case .externalMCPs: "puzzlepiece.extension"
        case .ai: "brain"
        case .advanced: "wrench.and.screwdriver"
        case .debug: "ladybug"
        }
    }
}