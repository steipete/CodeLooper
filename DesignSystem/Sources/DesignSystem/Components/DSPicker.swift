import SwiftUI

public struct DSPicker<Value: Hashable>: View {
    @Binding private var selection: Value
    private let label: String
    private let options: [(Value, String)]
    
    public init(
        _ label: String,
        selection: Binding<Value>,
        options: [(Value, String)]
    ) {
        self.label = label
        self._selection = selection
        self.options = options
    }
    
    public var body: some View {
        HStack {
            Text(label)
                .font(Typography.body())
                .foregroundColor(ColorPalette.text)
            
            Spacer()
            
            Picker("", selection: $selection) {
                ForEach(options, id: \.0) { value, label in
                    Text(label).tag(value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
        }
    }
}

// Convenience initializer for enum types
public extension DSPicker where Value: CaseIterable & RawRepresentable, Value.RawValue == String {
    init(
        _ label: String,
        selection: Binding<Value>
    ) {
        self.init(
            label,
            selection: selection,
            options: Value.allCases.map { ($0, $0.rawValue) }
        )
    }
}