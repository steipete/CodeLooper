import SwiftUI

public struct DSToggle: View {
    @Binding private var isOn: Bool
    private let label: String
    private let description: String?
    private let descriptionLineSpacing: CGFloat?
    
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
            
            if let description = description {
                Text(description)
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
                    .lineSpacing(descriptionLineSpacing ?? 0)
                    .padding(.trailing, 60) // Account for toggle width
            }
        }
    }
}