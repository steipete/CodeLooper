import Defaults
import DesignSystem
import SwiftUI

/// A card component for displaying intervention rule information and controls.
struct RuleCard: View {
    // MARK: - Properties
    
    let rule: InterventionRule
    let isSelected: Bool
    let executionCount: Int
    let onSelect: () -> Void
    let onToggle: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                // Header with title and toggle
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                        Text(rule.displayName)
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)
                        
                        Text(rule.description)
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    DSToggle("", isOn: .constant(rule.isEnabled))
                        .onTapGesture {
                            onToggle()
                        }
                        .labelsHidden()
                }
                
                // Execution count and status
                HStack {
                    HStack(spacing: Spacing.xxxSmall) {
                        Image(systemName: "number.circle.fill")
                            .foregroundColor(ColorPalette.primary)
                        
                        Text("Executed \(executionCount) times")
                            .font(Typography.caption2())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    Spacer()
                    
                    if rule.isEnabled {
                        HStack(spacing: Spacing.xxxSmall) {
                            Circle()
                                .fill(ColorPalette.success)
                                .frame(width: 6, height: 6)
                            
                            Text("Active")
                                .font(Typography.caption2())
                                .foregroundColor(ColorPalette.success)
                        }
                    } else {
                        HStack(spacing: Spacing.xxxSmall) {
                            Circle()
                                .fill(ColorPalette.textSecondary)
                                .frame(width: 6, height: 6)
                            
                            Text("Disabled")
                                .font(Typography.caption2())
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                    }
                }
                
                // Configuration details (if selected)
                if isSelected {
                    Divider()
                    
                    RuleConfigurationView(rule: rule)
                }
            }
        }
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

/// Configuration view for rule details
private struct RuleConfigurationView: View {
    let rule: InterventionRule
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            Text("Configuration")
                .font(Typography.subheadline(.medium))
                .foregroundColor(ColorPalette.text)
            
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                ForEach(rule.configurationItems, id: \.key) { item in
                    HStack {
                        Text(item.key)
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                        
                        Spacer()
                        
                        Text(item.value)
                            .font(Typography.caption1(.medium))
                            .foregroundColor(ColorPalette.text)
                    }
                }
            }
            .padding(.leading, Spacing.small)
        }
    }
}

// MARK: - Supporting Types

struct InterventionRule: Identifiable {
    let id = UUID()
    let name: String
    let displayName: String
    let description: String
    let isEnabled: Bool
    let configurationItems: [(key: String, value: String)]
    
    static let stopAfter25Loops = InterventionRule(
        name: "StopAfter25LoopsRule",
        displayName: "Stop After 25 Loops", 
        description: "Prevents infinite loops by stopping execution after 25 iterations",
        isEnabled: true,
        configurationItems: [
            ("Max Iterations", "25"),
            ("Sound Enabled", "Yes"),
            ("Notifications", "Warning at 20")
        ]
    )
    
    static let connectionErrorRecovery = InterventionRule(
        name: "ConnectionErrorRecovery",
        displayName: "Connection Error Recovery",
        description: "Automatically attempts to recover from connection errors",
        isEnabled: false,
        configurationItems: [
            ("Max Retry Attempts", "3"),
            ("Retry Delay", "2 seconds"),
            ("Auto Resume", "Yes")
        ]
    )
    
    static let fileConflictResolver = InterventionRule(
        name: "FileConflictResolver", 
        displayName: "File Conflict Resolver",
        description: "Resolves file conflicts that prevent saving",
        isEnabled: false,
        configurationItems: [
            ("Auto Backup", "Yes"),
            ("Conflict Strategy", "Keep Both"),
            ("Notify User", "Always")
        ]
    )
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.medium) {
        RuleCard(
            rule: .stopAfter25Loops,
            isSelected: false,
            executionCount: 12,
            onSelect: {},
            onToggle: {}
        )
        
        RuleCard(
            rule: .connectionErrorRecovery,
            isSelected: true,
            executionCount: 5,
            onSelect: {},
            onToggle: {}
        )
    }
    .padding()
}