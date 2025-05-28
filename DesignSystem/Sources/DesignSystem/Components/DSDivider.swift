import SwiftUI

public struct DSDivider: View {
    // MARK: Lifecycle

    public init(
        orientation: Orientation = .horizontal,
        thickness: CGFloat = Layout.BorderWidth.regular,
        color: Color = ColorPalette.border
    ) {
        self.orientation = orientation
        self.thickness = thickness
        self.color = color
    }

    // MARK: Public

    public enum Orientation {
        case horizontal
        case vertical
    }

    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(
                width: orientation == .horizontal ? nil : thickness,
                height: orientation == .vertical ? nil : thickness
            )
    }

    // MARK: Private

    private let orientation: Orientation
    private let thickness: CGFloat
    private let color: Color
}
