import SwiftUI

/// A styled toggle switch component with label and description support.
///
/// DSToggle provides a consistent boolean input control with:
/// - Clear labeling and descriptive text
/// - Standardized toggle switch styling
/// - Optional description text with custom spacing
/// - Accessibility support for screen readers
///
/// ## Usage
///
/// ```swift
/// DSToggle("Enable notifications", isOn: $isEnabled)
///     .description("Receive updates when new events occur")
/// ```
public struct DSToggle: View {
    // MARK: Lifecycle

    public init(
        _ label: String,
        isOn: Binding<Bool>,
        description: String? = nil,
        descriptionLineSpacing: CGFloat? = nil
    ) {
        self.label = label
        self._isOn = isOn
        self.description = description
        self.descriptionLineSpacing = descriptionLineSpacing
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.text)
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .fixedSize()
            }

            if let description {
                Text(description)
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
                    .lineSpacing(descriptionLineSpacing ?? 0)
                    .padding(.trailing, 60) // Account for toggle width
            }
        }
    }

    // MARK: Private

    @Binding private var isOn: Bool

    private let label: String
    private let description: String?
    private let descriptionLineSpacing: CGFloat?
}
