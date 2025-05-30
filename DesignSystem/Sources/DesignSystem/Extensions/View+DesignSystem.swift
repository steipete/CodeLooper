import SwiftUI

public extension View {
    // MARK: - Padding Helpers

    func paddingDS(_ edges: Edge.Set = .all, _ size: CGFloat) -> some View {
        self.padding(edges, size)
    }

    func paddingDS(_ size: CGFloat) -> some View {
        self.padding(size)
    }

    // MARK: - Corner Radius Helpers

    func cornerRadiusDS(_ radius: CGFloat, antialiased _: Bool = true) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    // MARK: - Border Helpers

    func borderDS(
        _ color: Color = ColorPalette.border,
        width: CGFloat = Layout.BorderWidth.regular,
        cornerRadius: CGFloat = 0
    ) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(color, lineWidth: width)
        )
    }

    // MARK: - Animation Helpers

    func animateDS(_ duration: Double = Layout.Animation.normal) -> some View {
        self.animation(.easeInOut(duration: duration), value: UUID())
    }

    func springAnimateDS(
        response: Double = Layout.Animation.springResponse,
        dampingFraction: Double = Layout.Animation.springDamping
    ) -> some View {
        self.animation(.spring(response: response, dampingFraction: dampingFraction), value: UUID())
    }

    // MARK: - Conditional Modifiers

    @ViewBuilder
    func `if`(
        _ condition: Bool,
        transform: (Self) -> some View
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func ifLet<Value>(
        _ optional: Value?,
        transform: (Self, Value) -> some View
    ) -> some View {
        if let value = optional {
            transform(self, value)
        } else {
            self
        }
    }

    // MARK: - Brand Tinting

    /// Applies CodeLooper brand tinting to the view
    @ViewBuilder
    func withCodeLooperTint() -> some View {
        self.tint(ColorPalette.loopTint)
    }

    /// Applies CodeLooper brand accent color as foreground
    @ViewBuilder
    func withBrandAccent() -> some View {
        self.foregroundColor(ColorPalette.loopTint)
    }
}
