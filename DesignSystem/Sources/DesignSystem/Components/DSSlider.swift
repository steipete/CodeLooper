import SwiftUI

public struct DSSlider: View {
    // MARK: Lifecycle

    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0 ... 1,
        step: Double? = nil,
        label: String? = nil,
        showValue: Bool = false,
        valueFormatter: @escaping (Double) -> String = { String(format: "%.1f", $0) }
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.label = label
        self.showValue = showValue
        self.valueFormatter = valueFormatter
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxSmall) {
            if let label {
                HStack {
                    Text(label)
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.text)

                    if showValue {
                        Spacer()
                        Text(valueFormatter(value))
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
            }

            if let step {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
        }
    }

    // MARK: Private

    @Binding private var value: Double

    private let range: ClosedRange<Double>
    private let step: Double?
    private let label: String?
    private let showValue: Bool
    private let valueFormatter: (Double) -> String
}
