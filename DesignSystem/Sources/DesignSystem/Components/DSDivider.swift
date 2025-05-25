import SwiftUI

public struct DSDivider: View {
    public enum Orientation {
        case horizontal
        case vertical
    }
    
    private let orientation: Orientation
    private let thickness: CGFloat
    private let color: Color
    
    public init(
        orientation: Orientation = .horizontal,
        thickness: CGFloat = Layout.BorderWidth.regular,
        color: Color = ColorPalette.border
    ) {
        self.orientation = orientation
        self.thickness = thickness
        self.color = color
    }
    
    public var body: some View {
        Rectangle()
            .fill(color)
            .frame(
                width: orientation == .horizontal ? nil : thickness,
                height: orientation == .vertical ? nil : thickness
            )
    }
}