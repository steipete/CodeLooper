import Defaults
import DesignSystem
import SwiftUI

/// A card component for displaying intervention rule information and controls.
struct RuleCard<Rule>: View where Rule: Identifiable {
    // MARK: - Properties
    
    let rule: Rule
    let name: String
    let description: String
    let isEnabled: Bool
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
                        Text(name)
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)
                        
                        Text(description)
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    DSToggle("", isOn: .constant(isEnabled))
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
                    
                    if isEnabled {
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
                
            }
        }
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}



