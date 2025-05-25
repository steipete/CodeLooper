import SwiftUI

public struct DSSection<Content: View>: View {
    private let title: String?
    private let description: String?
    private let content: () -> Content
    
    public init(
        _ title: String? = nil,
        description: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.description = description
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if let title = title {
                VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                    Text(title)
                        .font(Typography.headline())
                        .foregroundColor(ColorPalette.text)
                    
                    if let description = description {
                        Text(description)
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
                .padding(.bottom, Spacing.xxSmall)
            }
            
            VStack(alignment: .leading, spacing: Spacing.medium) {
                content()
            }
        }
        .padding(.vertical, Spacing.small)
    }
}

// Convenience for settings-style sections
public struct DSSettingsSection<Content: View>: View {
    private let title: String?
    private let content: () -> Content
    
    public init(
        _ title: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = title {
                Text(title)
                    .font(Typography.caption1(.semibold))
                    .foregroundColor(ColorPalette.textSecondary)
                    .textCase(.uppercase)
                    .padding(.bottom, Spacing.xSmall)
            }
            
            DSCard(style: .filled) {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    content()
                }
            }
        }
    }
}