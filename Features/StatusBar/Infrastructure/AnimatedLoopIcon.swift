import Defaults
import Diagnostics
import SwiftUI

/// A SwiftUI view that displays an animated reverse 8 loop icon for the menu bar
struct AnimatedLoopIcon: View {
    @Default(.isGlobalMonitoringEnabled) private var isWatchingEnabled
    let size: CGFloat
    
    @State private var animationProgress: CGFloat = 0
    private let logger = Logger(category: .statusBar)
    
    var body: some View {
        ZStack {
            // Main animated reverse 8 loop
            Reverse8LoopShape(animationProgress: animationProgress)
                .stroke(
                    menuBarTintColor,
                    style: StrokeStyle(
                        lineWidth: max(1.5, size / 10),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: size, height: size)
        }
        .onAppear {
            if isWatchingEnabled {
                startAnimation()
            }
        }
        .onChange(of: isWatchingEnabled) { _, newValue in
            logger.info("Animated loop icon state changed: \(newValue)")
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private var menuBarTintColor: Color {
        Color.primary
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
            animationProgress = 1.0
        }
    }
    
    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.5)) {
            animationProgress = 0
        }
    }
}

// MARK: - Reverse 8 Loop Shape

private struct Reverse8LoopShape: Shape {
    var animationProgress: CGFloat
    
    var animatableData: CGFloat {
        get { animationProgress }
        set { animationProgress = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let scale = min(rect.width, rect.height) * 0.4
        
        // Generate all points for the figure-8 (lemniscate) first
        let totalSteps = 720 // Higher resolution for smoother curves
        var allPoints: [CGPoint] = []
        
        for i in 0..<totalSteps {
            let t = CGFloat(i) / CGFloat(totalSteps) * 4 * .pi // Full cycle
            
            // Parametric equations for a figure-8 (lemniscate of Bernoulli)
            // x = a * cos(t) / (1 + sin²(t))
            // y = a * sin(t) * cos(t) / (1 + sin²(t))
            
            let sinT = sin(t)
            let cosT = cos(t)
            let denominator = 1 + sinT * sinT
            
            let x = center.x + scale * cosT / denominator
            let y = center.y + scale * sinT * cosT / denominator
            
            allPoints.append(CGPoint(x: x, y: y))
        }
        
        // Determine how many points to show based on animation progress
        let visiblePointCount = max(1, Int(CGFloat(allPoints.count) * animationProgress))
        let visiblePoints = Array(allPoints.prefix(visiblePointCount))
        
        // Create the path with smooth curves
        if let firstPoint = visiblePoints.first {
            path.move(to: firstPoint)
            
            // Use quadratic curves for smoother appearance
            for i in 1..<visiblePoints.count {
                let currentPoint = visiblePoints[i]
                if i == 1 {
                    path.addLine(to: currentPoint)
                } else {
                    let previousPoint = visiblePoints[i - 1]
                    let controlPoint = CGPoint(
                        x: (previousPoint.x + currentPoint.x) / 2,
                        y: (previousPoint.y + currentPoint.y) / 2
                    )
                    path.addQuadCurve(to: currentPoint, control: controlPoint)
                }
            }
        }
        
        return path
    }
}

// MARK: - NSView wrapper for the animated icon

@MainActor
class AnimatedLoopIconHostingView: NSView {
    // MARK: Lifecycle
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupHostingView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupHostingView()
    }
    
    // MARK: Private
    
    private var hostingView: NSHostingView<AnimatedLoopIcon>?
    
    private func setupHostingView() {
        let iconView = AnimatedLoopIcon(size: 16)
        let hosting = NSHostingView(rootView: iconView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(hosting)
        
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        
        self.hostingView = hosting
    }
}