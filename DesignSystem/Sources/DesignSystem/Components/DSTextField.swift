import SwiftUI

public struct DSTextField: View {
    // MARK: Lifecycle

    public init(
        _ placeholder: String,
        text: Binding<String>,
        icon: Image? = nil,
        helperText: String? = nil,
        errorText: String? = nil,
        showClearButton: Bool = false
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.helperText = helperText
        self.errorText = errorText
        self.showClearButton = showClearButton
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            HStack(spacing: Spacing.xSmall) {
                if let icon {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: Layout.Dimensions.iconSmall, height: Layout.Dimensions.iconSmall)
                        .foregroundColor(iconColor)
                }

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(Typography.body())
                    .focused($textFieldFocused)
                    .onChange(of: textFieldFocused) { _, newValue in
                        isFocused = newValue
                    }

                if showClearButton, !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, Spacing.xSmall)
            .background(ColorPalette.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.medium)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
            )

            if let message = errorText ?? helperText {
                Text(message)
                    .font(Typography.caption1())
                    .foregroundColor(errorText != nil ? ColorPalette.error : ColorPalette.textSecondary)
                    .padding(.horizontal, Spacing.xxSmall)
            }
        }
    }

    // MARK: Private

    @Binding private var text: String
    @State private var isFocused = false
    @FocusState private var textFieldFocused: Bool

    private let placeholder: String
    private let icon: Image?
    private let helperText: String?
    private let errorText: String?
    private let showClearButton: Bool

    private var iconColor: Color {
        if errorText != nil {
            return ColorPalette.error
        }
        return isFocused ? ColorPalette.primary : ColorPalette.textSecondary
    }

    private var borderColor: Color {
        if errorText != nil {
            return ColorPalette.error
        }
        return isFocused ? ColorPalette.primary : ColorPalette.border
    }

    private var borderWidth: CGFloat {
        isFocused || errorText != nil ? Layout.BorderWidth.medium : Layout.BorderWidth.regular
    }
}
