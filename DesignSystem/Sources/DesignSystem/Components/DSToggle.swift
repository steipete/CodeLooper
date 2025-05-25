import SwiftUI

public struct DSToggle: View {
    @Binding private var isOn: Bool
    private let label: String
    private let description: String?
    
    public init(
        _ label: String,
        isOn: Binding<Bool>,
        description: String? = nil
    ) {
        self.label = label
        self._isOn = isOn
        self.description = description
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
                    .padding(.trailing, 60) // Account for toggle width
            }
        }
    }
}