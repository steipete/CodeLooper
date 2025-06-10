import SwiftUI

/// Shared status indicators view that can be used in both menu bar and popover
public struct StatusIndicators: View {
    let runningCount: Int
    let notRunningCount: Int
    let isCompact: Bool
    
    public init(runningCount: Int, notRunningCount: Int, isCompact: Bool = false) {
        self.runningCount = runningCount
        self.notRunningCount = notRunningCount
        self.isCompact = isCompact
    }
    
    public var body: some View {
        HStack(spacing: isCompact ? 3 : 4) {
            if runningCount > 0 {
                StatusBadge(
                    count: runningCount,
                    icon: "play.fill",
                    color: Color(red: 0.3, green: 0.65, blue: 0.3),
                    isCompact: isCompact
                )
            }
            
            if notRunningCount > 0 {
                StatusBadge(
                    count: notRunningCount,
                    icon: "stop.fill",
                    color: Color(red: 0.7, green: 0.35, blue: 0.35),
                    isCompact: isCompact
                )
            }
            
            // Show idle state only in menu bar
            if isCompact && runningCount == 0 && notRunningCount == 0 {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6, weight: .medium))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
    }
}

/// Individual status badge component
public struct StatusBadge: View {
    let count: Int
    let icon: String
    let color: Color
    let isCompact: Bool
    
    @State private var isHovered = false
    
    public init(count: Int, icon: String, color: Color, isCompact: Bool = false) {
        self.count = count
        self.icon = icon
        self.color = color
        self.isCompact = isCompact
    }
    
    public var body: some View {
        if isCompact {
            // Compact version for menu bar
            compactBadge
        } else {
            // Full version for popover
            fullBadge
        }
    }
    
    private var compactBadge: some View {
        HStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 16, height: 16)
                
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("\(count)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 2)
    }
    
    private var fullBadge: some View {
        HStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(color.opacity(isHovered ? 1.0 : 0.85))
                    .frame(width: 16, height: 16)
                
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text("\(count)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(color.opacity(0.2), lineWidth: 0.5)
                )
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(icon == "play.fill" ? "\(count) instance\(count == 1 ? "" : "s") running" : "\(count) instance\(count == 1 ? "" : "s") stopped")
    }
}

#Preview("Status Indicators - Full") {
    VStack(spacing: 20) {
        StatusIndicators(runningCount: 7, notRunningCount: 4)
        StatusIndicators(runningCount: 3, notRunningCount: 0)
        StatusIndicators(runningCount: 0, notRunningCount: 2)
    }
    .padding()
}

#Preview("Status Indicators - Compact") {
    VStack(spacing: 20) {
        StatusIndicators(runningCount: 7, notRunningCount: 4, isCompact: true)
        StatusIndicators(runningCount: 3, notRunningCount: 0, isCompact: true)
        StatusIndicators(runningCount: 0, notRunningCount: 2, isCompact: true)
        StatusIndicators(runningCount: 0, notRunningCount: 0, isCompact: true)
    }
    .padding()
    .scaleEffect(2) // Make it bigger for preview
}