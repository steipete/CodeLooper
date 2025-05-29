import SwiftUI

// MARK: - Shimmer Effect Component

/// A loading placeholder view with animated shimmer effect.
///
/// DSShimmer creates a rectangular placeholder with a shimmering animation
/// commonly used to indicate loading content. The shimmer effect consists
/// of a diagonal gradient that moves across the view, creating a visual
/// indication that content is being loaded.
///
/// Example usage:
/// ```swift
/// DSShimmer(width: 200, height: 20, cornerRadius: 8)
/// ```
public struct DSShimmer: View {
    // MARK: Lifecycle

    public init(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 4) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    // MARK: Public

    public let width: CGFloat
    public let height: CGFloat
    public let cornerRadius: CGFloat

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(MaterialPalette.cardBackground)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Shimmer ViewModifier

/// A view modifier that applies an animated shimmer effect to any view.
///
/// The Shimmer modifier overlays a moving gradient on the content view,
/// creating a shimmering animation effect. The gradient moves diagonally
/// from top-left to bottom-right with a 30-degree rotation angle.
///
/// The animation repeats indefinitely with a duration of 1.2 seconds,
/// providing a smooth loading indication effect.
public struct Shimmer: ViewModifier {
    // MARK: Public

    public func body(content: Content) -> some View {
        content
            .overlay {
                Rectangle()
                    .fill(.linearGradient(
                        colors: [.clear, .white.opacity(0.4), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
            }
            .clipped()
            .task {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }

    // MARK: Private

    @State private var phase = 0.0
}

public extension View {
    func shimmer() -> some View {
        modifier(Shimmer())
    }
}
