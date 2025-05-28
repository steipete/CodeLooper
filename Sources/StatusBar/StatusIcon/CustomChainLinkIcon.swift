import Defaults
import Diagnostics
import SwiftUI

/// A SwiftUI view that displays your custom chain link icon with animated shape drawing
struct CustomChainLinkIcon: View {
    @Default(.isGlobalMonitoringEnabled) private var isWatchingEnabled
    let size: CGFloat

    @State private var animationProgress: CGFloat = 0
    private let animationSpeed: CGFloat = 0.3
    private let logger = Logger(category: .statusBar)

    var body: some View {
        ZStack {
            // Debug background to see the full frame
            Rectangle()
                .fill(Color.yellow.opacity(0.1))
                .frame(width: size, height: size)

            // Animated first chain link
            AnimatedChainLink1Shape(animationProgress: animationProgress)
                .stroke(menuBarTintColor, style: StrokeStyle(
                    lineWidth: max(2, size / 10),
                    lineCap: .round,
                    lineJoin: .round
                ))
                .frame(width: size, height: size)

            // Animated second chain link (with delay)
            AnimatedChainLink2Shape(animationProgress: max(0, animationProgress - 0.3))
                .stroke(menuBarTintColor.opacity(animationProgress > 0.3 ? 1.0 : 0.5), style: StrokeStyle(
                    lineWidth: max(2, size / 10),
                    lineCap: .round,
                    lineJoin: .round
                ))
                .frame(width: size, height: size)

            // Debug: Show coordinate bounds
            if size > 64 {
                VStack {
                    HStack {
                        Text("100x100")
                            .font(.caption2)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: size, height: size)
            }
        }
        .onAppear {
            if isWatchingEnabled {
                startAnimation()
            }
        }
        .onChange(of: isWatchingEnabled) { _, newValue in
            logger.info("Custom chain link animation state changed: \(newValue)")
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
        withAnimation(.easeInOut(duration: 2.0 / animationSpeed).repeatForever(autoreverses: true)) {
            animationProgress = 1.0
        }
    }

    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.5)) {
            animationProgress = 0
        }
    }
}

// MARK: - Animated First Chain Link Shape

private struct AnimatedChainLink1Shape: Shape {
    var animationProgress: CGFloat

    var animatableData: CGFloat {
        get { animationProgress }
        set { animationProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaleX = rect.width / 100.0 // Your Lottie is 100x100
        let scaleY = rect.height / 100.0

        // Convert your Lottie coordinates to SwiftUI path
        let allPoints: [(CGFloat, CGFloat)] = [
            (42.96875, 34.5703125), (42.1875, 33.7890625), (41.40625, 33.0078125), (40.625, 32.32421875),
            (39.84375, 31.73828125), (39.0625, 31.34765625), (38.28125, 30.859375), (37.5, 30.46875),
            (36.71875, 30.078125), (35.9375, 29.8828125), (35.15625, 29.58984375), (34.375, 29.39453125),
            (33.59375, 29.39453125), (32.8125, 29.19921875), (32.03125, 29.1015625), (31.25, 29.00390625),
            (30.46875, 29.00390625), (29.6875, 29.1015625), (28.90625, 29.19921875), (28.125, 29.296875),
            (27.34375, 29.4921875), (26.5625, 29.58984375), (25.78125, 29.78515625), (25.0, 30.078125),
            (24.21875, 30.46875), (23.4375, 30.76171875), (22.65625, 31.25), (21.875, 31.73828125),
            (21.09375, 32.32421875), (20.3125, 32.91015625), (19.53125, 33.59375), (18.75, 34.375),
            (18.06640625, 35.15625), (17.3828125, 35.9375), (16.796875, 36.71875), (16.30859375, 37.5),
            (15.72265625, 38.28125), (15.234375, 39.0625), (14.94140625, 39.84375), (14.55078125, 40.625),
            (14.16015625, 41.40625), (13.96484375, 42.1875), (13.671875, 42.96875), (13.4765625, 43.75),
            (13.18359375, 44.53125), (13.0859375, 45.3125), (12.98828125, 46.09375), (12.890625, 46.875),
            (12.79296875, 47.65625), (12.6953125, 48.4375), (12.6953125, 49.21875), (12.59765625, 50.0),
            (12.6953125, 50.78125), (12.79296875, 51.5625), (12.79296875, 52.34375), (12.890625, 53.125),
            (12.98828125, 53.90625), (13.0859375, 54.6875), (13.28125, 55.46875), (13.4765625, 56.25),
            (13.671875, 57.03125), (13.96484375, 57.8125), (14.2578125, 58.59375), (14.55078125, 59.375),
            (14.94140625, 60.15625), (15.33203125, 60.9375), (15.72265625, 61.71875), (16.2109375, 62.5),
            (16.796875, 63.28125), (17.3828125, 64.0625), (17.96875, 64.84375), (18.65234375, 65.625),
            (19.3359375, 66.40625), (20.1171875, 66.9921875), (20.8984375, 67.7734375), (21.6796875, 68.359375),
            (22.4609375, 68.84765625), (23.2421875, 69.3359375), (24.0234375, 69.82421875), (24.8046875, 70.21484375),
            (25.5859375, 70.5078125), (26.3671875, 70.80078125), (27.1484375, 70.99609375), (27.9296875, 71.19140625),
            (28.7109375, 71.38671875), (29.4921875, 71.484375), (30.2734375, 71.58203125), (31.0546875, 71.6796875),
            (31.8359375, 71.77734375), (32.6171875, 71.77734375), (33.3984375, 71.6796875), (34.1796875, 71.6796875),
            (34.9609375, 71.58203125), (35.7421875, 71.484375), (36.5234375, 71.38671875), (37.3046875, 71.09375),
            (38.0859375, 70.8984375), (38.8671875, 70.60546875), (39.6484375, 70.3125), (40.4296875, 70.01953125),
            (41.2109375, 69.53125), (41.9921875, 69.140625), (42.7734375, 68.65234375), (43.5546875, 68.1640625),
            (44.3359375, 67.48046875), (45.1171875, 66.69921875), (45.8984375, 66.015625), (46.6796875, 65.33203125),
            (47.4609375, 64.55078125), (48.14453125, 63.76953125), (48.92578125, 62.98828125), (
                49.70703125,
                62.3046875
            ),
            (50.390625, 61.5234375), (51.171875, 60.7421875), (51.953125, 59.9609375), (52.734375, 59.1796875),
            (53.515625, 58.3984375), (54.296875, 57.6171875), (55.078125, 56.8359375), (55.859375, 56.0546875),
            (56.640625, 55.2734375), (57.421875, 54.4921875), (58.203125, 53.7109375), (58.984375, 52.9296875),
        ]

        // Calculate how many points to include based on animation progress
        let pointCount = Int(CGFloat(allPoints.count) * animationProgress)
        let points = Array(allPoints.prefix(pointCount))

        // Add partial final segment if needed
        if pointCount < allPoints.count, animationProgress > 0 {
            let remainder = (CGFloat(allPoints.count) * animationProgress) - CGFloat(pointCount)
            if remainder > 0, pointCount > 0 {
                let currentPoint = allPoints[pointCount - 1]
                let nextPoint = allPoints[pointCount]
                let interpolatedPoint = (
                    currentPoint.0 + (nextPoint.0 - currentPoint.0) * remainder,
                    currentPoint.1 + (nextPoint.1 - currentPoint.1) * remainder
                )
                let finalPoints = points + [interpolatedPoint]

                // Scale and add points to path
                for (index, point) in finalPoints.enumerated() {
                    let scaledPoint = CGPoint(x: point.0 * scaleX, y: point.1 * scaleY)
                    if index == 0 {
                        path.move(to: scaledPoint)
                    } else {
                        path.addLine(to: scaledPoint)
                    }
                }
                return path
            }
        }

        // Scale and add points to path
        for (index, point) in points.enumerated() {
            let scaledPoint = CGPoint(x: point.0 * scaleX, y: point.1 * scaleY)
            if index == 0 {
                path.move(to: scaledPoint)
            } else {
                path.addLine(to: scaledPoint)
            }
        }

        return path
    }
}

// MARK: - Animated Second Chain Link Shape

private struct AnimatedChainLink2Shape: Shape {
    var animationProgress: CGFloat

    var animatableData: CGFloat {
        get { animationProgress }
        set { animationProgress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scaleX = rect.width / 100.0 // Your Lottie is 100x100
        let scaleY = rect.height / 100.0

        // Convert your second chain link coordinates
        let allPoints: [(CGFloat, CGFloat)] = [
            (42.1875, 50.9765625), (42.1875, 50.1953125), (42.3828125, 49.4140625), (43.1640625, 48.6328125),
            (43.84765625, 47.8515625), (44.62890625, 47.0703125), (45.41015625, 46.2890625), (46.19140625, 45.5078125),
            (46.97265625, 44.7265625), (47.75390625, 43.9453125), (48.53515625, 43.1640625), (49.31640625, 42.3828125),
            (50.09765625, 41.69921875), (50.78125, 40.91796875), (51.5625, 40.234375), (52.24609375, 39.453125),
            (53.02734375, 38.76953125), (53.7109375, 37.98828125), (54.4921875, 37.20703125), (55.2734375, 36.42578125),
            (56.0546875, 35.64453125), (56.73828125, 34.86328125), (57.51953125, 34.08203125), (
                58.30078125,
                33.3984375
            ),
            (59.08203125, 32.71484375), (59.86328125, 32.03125), (60.64453125, 31.4453125), (61.42578125, 30.95703125),
            (62.20703125, 30.6640625), (62.98828125, 30.2734375), (63.76953125, 29.98046875), (64.55078125, 29.6875),
            (65.33203125, 29.4921875), (66.11328125, 29.39453125), (66.89453125, 29.296875), (67.67578125, 29.19921875),
            (68.45703125, 29.1015625), (69.23828125, 29.00390625), (70.01953125, 29.1015625), (
                70.80078125,
                29.19921875
            ),
            (71.58203125, 29.296875), (72.36328125, 29.39453125), (73.14453125, 29.58984375), (
                73.92578125,
                29.78515625
            ),
            (74.70703125, 30.078125), (75.48828125, 30.37109375), (76.26953125, 30.76171875), (
                77.05078125,
                31.15234375
            ),
            (77.83203125, 31.640625), (78.61328125, 32.12890625), (79.39453125, 32.71484375), (
                80.17578125,
                33.30078125
            ),
            (80.95703125, 34.08203125), (81.640625, 34.86328125), (82.32421875, 35.64453125), (
                82.91015625,
                36.42578125
            ),
            (83.49609375, 37.20703125), (83.984375, 37.98828125), (84.47265625, 38.76953125), (84.9609375, 39.55078125),
            (85.25390625, 40.33203125), (85.64453125, 41.11328125), (85.9375, 41.89453125), (86.23046875, 42.67578125),
            (86.42578125, 43.45703125), (86.71875, 44.23828125), (86.81640625, 45.01953125), (87.01171875, 45.80078125),
            (87.109375, 46.58203125), (87.20703125, 47.36328125), (87.20703125, 48.14453125), (87.3046875, 48.92578125),
            (87.40234375, 49.70703125), (87.3046875, 50.48828125), (87.3046875, 51.26953125), (
                87.20703125,
                52.05078125
            ),
            (87.109375, 52.83203125), (87.01171875, 53.61328125), (86.9140625, 54.39453125), (86.71875, 55.17578125),
            (86.62109375, 55.95703125), (86.328125, 56.73828125), (86.1328125, 57.51953125), (85.83984375, 58.30078125),
            (85.546875, 59.08203125), (85.25390625, 59.86328125), (84.86328125, 60.64453125), (84.375, 61.42578125),
            (83.984375, 62.20703125), (83.49609375, 62.98828125), (82.91015625, 63.76953125), (82.421875, 64.55078125),
            (81.640625, 65.33203125), (80.95703125, 66.11328125), (80.17578125, 66.89453125), (79.39453125, 67.578125),
            (78.61328125, 68.1640625), (77.83203125, 68.75), (77.05078125, 69.23828125), (76.26953125, 69.7265625),
            (75.48828125, 70.1171875), (74.70703125, 70.41015625), (73.92578125, 70.703125), (73.14453125, 70.99609375),
            (72.36328125, 71.09375), (71.58203125, 71.19140625), (70.80078125, 71.38671875), (70.01953125, 71.38671875),
            (69.23828125, 71.58203125), (68.45703125, 71.58203125), (67.67578125, 71.484375), (
                66.89453125,
                71.38671875
            ),
            (66.11328125, 71.2890625), (65.33203125, 71.09375), (64.55078125, 70.99609375), (63.76953125, 70.80078125),
            (62.98828125, 70.5078125), (62.20703125, 70.21484375), (61.42578125, 69.82421875), (
                60.64453125,
                69.3359375
            ),
            (59.86328125, 68.84765625), (59.08203125, 68.26171875), (58.30078125, 67.67578125), (
                57.51953125,
                67.08984375
            ),
            (56.73828125, 67.08984375),
        ]

        // Calculate how many points to include based on animation progress
        let pointCount = Int(CGFloat(allPoints.count) * max(0, animationProgress))
        let points = Array(allPoints.prefix(pointCount))

        // Add partial final segment if needed
        if pointCount < allPoints.count, animationProgress > 0 {
            let remainder = (CGFloat(allPoints.count) * animationProgress) - CGFloat(pointCount)
            if remainder > 0, pointCount > 0 {
                let currentPoint = allPoints[pointCount - 1]
                let nextPoint = allPoints[pointCount]
                let interpolatedPoint = (
                    currentPoint.0 + (nextPoint.0 - currentPoint.0) * remainder,
                    currentPoint.1 + (nextPoint.1 - currentPoint.1) * remainder
                )
                let finalPoints = points + [interpolatedPoint]

                // Scale and add points to path
                for (index, point) in finalPoints.enumerated() {
                    let scaledPoint = CGPoint(x: point.0 * scaleX, y: point.1 * scaleY)
                    if index == 0 {
                        path.move(to: scaledPoint)
                    } else {
                        path.addLine(to: scaledPoint)
                    }
                }
                return path
            }
        }

        // Scale and add points to path
        for (index, point) in points.enumerated() {
            let scaledPoint = CGPoint(x: point.0 * scaleX, y: point.1 * scaleY)
            if index == 0 {
                path.move(to: scaledPoint)
            } else {
                path.addLine(to: scaledPoint)
            }
        }

        return path
    }
}
