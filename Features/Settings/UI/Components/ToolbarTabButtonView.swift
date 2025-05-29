import Combine
import DesignSystem
import SwiftUI

struct ToolbarTabButtonView: View {
    // MARK: Internal

    let tab: SettingsTab
    let selectedTab: CurrentValueSubject<SettingsTab, Never>

    var body: some View {
        Button(action: {
            selectedTab.send(tab)
        }, label: {
            VStack(spacing: 2) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(height: 18)

                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(textColor)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )
            .overlay(
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
            )
        })
        .buttonStyle(.plain)
        .opacity(isWindowKey ? 1.0 : 0.6)
        .onHover { hovering in
            isHovered = hovering
        }
        .onReceive(selectedTab) { newTab in
            isSelected = newTab == tab
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if let window = notification.object as? NSWindow {
                // Check if this is our settings window
                if window.identifier == NSUserInterfaceItemIdentifier("settings") {
                    isWindowKey = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if let window = notification.object as? NSWindow {
                // Check if this is our settings window
                if window.identifier == NSUserInterfaceItemIdentifier("settings") {
                    isWindowKey = false
                }
            }
        }
    }

    // MARK: Private

    @State private var isSelected = false
    @State private var isHovered = false
    @State private var isWindowKey = true

    private var iconColor: Color {
        if isSelected {
            Color(NSColor.controlAccentColor)
        } else if isHovered {
            Color(NSColor.labelColor)
        } else {
            Color(NSColor.secondaryLabelColor)
        }
    }

    private var textColor: Color {
        if isSelected {
            Color(NSColor.labelColor)
        } else if isHovered {
            Color(NSColor.labelColor)
        } else {
            Color(NSColor.secondaryLabelColor)
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            Color(NSColor.controlAccentColor).opacity(0.15)
        } else if isHovered {
            Color(NSColor.controlBackgroundColor)
        } else {
            Color.clear
        }
    }

    private var borderColor: Color {
        if isSelected {
            Color(NSColor.controlAccentColor).opacity(0.3)
        } else {
            Color.clear
        }
    }

    private var borderWidth: CGFloat {
        isSelected ? 1 : 0
    }
}
