import SwiftUI

// MARK: - Shimmer Effect Component

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
            .fill(ColorPalette.backgroundSecondary)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Shimmer ViewModifier

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
