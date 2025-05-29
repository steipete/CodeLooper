import SwiftUI

public struct DSSection<Content: View>: View {
    // MARK: Lifecycle

    public init(
        _ title: String? = nil,
        description: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.description = description
        self.content = content
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if let title {
                VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                    Text(title)
                        .font(Typography.headline())
                        .foregroundColor(ColorPalette.text)

                    if let description {
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

    // MARK: Private

    private let title: String?
    private let description: String?
    private let content: () -> Content
}

// Convenience for settings-style sections
public struct DSSettingsSection<Content: View>: View {
    // MARK: Lifecycle

    public init(
        _ title: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(Typography.caption1(.semibold))
                    .foregroundColor(ColorPalette.sectionHeader)
                    .textCase(.uppercase)
                    .padding(.bottom, Spacing.xSmall)
                    .background(Color.clear) // Ensure transparent background
            }

            DSCard(style: .filled) {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    content()
                }
            }
        }
    }

    // MARK: Private

    private let title: String?
    private let content: () -> Content
}
