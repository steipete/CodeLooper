import AppKit
import Diagnostics
import Foundation
import OSLog

/// Class responsible for animating the status bar icon
@MainActor
class IconAnimator {
    // MARK: Lifecycle

    // MARK: - Initialization

    init(statusItem: NSStatusItem?, frames: [NSImage] = [], interval: TimeInterval = 0.25) {
        self.statusItem = statusItem
        self.frames = frames
        animationInterval = interval

        logger.info("IconAnimator initialized with \(frames.count) frames at \(interval)s interval")
    }

    // MARK: Internal

    /// Check if animation is currently running
    var isCurrentlyAnimating: Bool {
        isAnimating && animationTimer != nil
    }

    // MARK: - Helper Methods

    /// Create animation frames for the syncing state
    /// - Parameters:
    ///   - baseImage: Base image to use for animation
    ///   - count: Number of frames to generate
    ///   - dotColor: Custom color for the animation dots. If nil, will automatically use appropriate color for current
    /// appearance
    /// - Returns: Array of animation frames
    static func createSyncingAnimationFrames(
        baseImage: NSImage,
        count: Int = 8,
        dotColor: NSColor? = nil
    ) -> [NSImage] {
        var frames: [NSImage] = []
        let size = baseImage.size

        // Ensure we have a valid base image with the right size
        if baseImage.size.width < 1 || baseImage.size.height < 1 {
            let logger = Logger(category: .statusBar)
            logger.error("Invalid base image size: \(String(describing: baseImage.size))")
            return [baseImage] // Return just the base image to avoid crashes
        }

        // Generate animation frames
        for frameIndex in 0 ..< count {
            // Create a new image copy for this frame
            let frame = NSImage(size: size)
            frame.lockFocus()

            // Draw base image (the app icon)
            baseImage.draw(
                in: NSRect(origin: .zero, size: size),
                from: NSRect(origin: .zero, size: baseImage.size),
                operation: .sourceOver,
                fraction: 1.0
            )

            // Draw progress indicator (e.g., dots around edge)
            let context = NSGraphicsContext.current?.cgContext
            context?.saveGState()

            // Calculate angle for this frame
            let angle = 2.0 * Double.pi * Double(frameIndex) / Double(count)

            // Draw a dot or indicator at this angle - keep dots near the edge
            let radius = min(size.width, size.height) / 2.5
            let xPos = size.width / 2 + cos(angle) * radius
            let yPos = size.height / 2 + sin(angle) * radius
            let dotSize: CGFloat = 2.5 // Slightly smaller dots

            // Make sure the dot color contrasts with the app icon
            if let customDotColor = dotColor {
                customDotColor.setFill()
            } else if NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                NSColor.white.setFill() // White dots in dark mode
            } else {
                NSColor.black.setFill() // Black dots in light mode
            }

            let dotRect = NSRect(
                x: xPos - dotSize / 2,
                y: yPos - dotSize / 2,
                width: dotSize,
                height: dotSize
            )
            context?.fillEllipse(in: dotRect)

            context?.restoreGState()
            frame.unlockFocus()

            // Add to frames array
            frames.append(frame)
        }

        return frames
    }

    /// Create animation frames that alternate between two images
    /// - Parameters:
    ///   - image1: First image
    ///   - image2: Second image
    /// - Returns: Array of animation frames
    static func createAlternatingFrames(image1: NSImage, image2: NSImage) -> [NSImage] {
        [image1, image2]
    }

    // MARK: - Animation Control

    /// Start animating with the given frames
    /// - Parameters:
    ///   - newFrames: Animation frames (optional, uses existing frames if nil)
    ///   - interval: Animation interval in seconds (optional, uses existing interval if nil)
    ///   - tooltipFormat: Format string for tooltip, can include %d for frame number
    ///   - completion: Handler called when animation is stopped
    func startAnimating(
        frames newFrames: [NSImage]? = nil,
        interval: TimeInterval? = nil,
        tooltipFormat: String? = nil,
        completion: (() -> Void)? = nil
    ) {
        guard let button = statusItem?.button else {
            logger.error("Cannot start animation: statusItem button is nil")
            return
        }

        // Store original state to restore later
        originalImage = button.image
        originalTooltip = button.toolTip

        // Update frames and interval if provided
        if let newFrames, !newFrames.isEmpty {
            frames = newFrames
        }

        if let interval {
            animationInterval = interval
        }

        // Store completion handler
        completionHandler = completion

        // Validate we have frames to animate
        guard !frames.isEmpty else {
            logger.error("Cannot start animation: no frames provided")
            return
        }

        // Stop any existing animation
        stopAnimating(executeCompletion: false)

        // Reset frame index
        currentFrameIndex = 0

        // Create and start animation timer
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: animationInterval,
            repeats: true
        ) { [weak self] _ in
            // Use Task to ensure we respect the MainActor isolation
            Task { @MainActor in
                guard let self else { return }
                self.advanceFrame(tooltipFormat: tooltipFormat)
            }
        }

        // Show the first frame and mark as animating
        advanceFrame(tooltipFormat: tooltipFormat)
        isAnimating = true
        logger.info("Started icon animation with \(self.frames.count) frames")
    }

    /// Stop the animation and restore original state
    /// - Parameter executeCompletion: Whether to execute the completion handler
    func stopAnimating(executeCompletion: Bool = true) {
        guard isAnimating else { return }

        // Invalidate and clear timer
        animationTimer?.invalidate()
        animationTimer = nil

        // Restore original state
        if let button = statusItem?.button {
            button.image = originalImage
            button.toolTip = originalTooltip
        }

        isAnimating = false
        logger.info("Stopped icon animation")

        // Execute completion handler if requested
        if executeCompletion, let completionHandler {
            completionHandler()
            self.completionHandler = nil
        }
    }

    /// Clean up resources
    func cleanup() {
        stopAnimating()
        frames = []
        originalImage = nil
        originalTooltip = nil
    }

    // MARK: Private

    /// Logger for this class
    private let logger = Logger(category: .statusBar)

    /// Weak reference to status item to avoid reference cycles
    private weak var statusItem: NSStatusItem?

    /// Animation frames
    private var frames: [NSImage] = []

    /// Current frame index
    private var currentFrameIndex: Int = 0

    /// Animation timer
    private var animationTimer: Timer?

    /// Animation interval in seconds
    private var animationInterval: TimeInterval = 0.25

    /// Whether animation is running
    private var isAnimating: Bool = false

    /// Original image to restore when animation stops
    private var originalImage: NSImage?

    /// Original tooltip to restore when animation stops
    private var originalTooltip: String?

    /// Completion handler called when animation is stopped
    private var completionHandler: (() -> Void)?

    /// Advance to the next animation frame
    /// - Parameter tooltipFormat: Format string for tooltip, can include %d for frame number
    private func advanceFrame(tooltipFormat: String? = nil) {
        guard let button = statusItem?.button, !frames.isEmpty else { return }

        // Get the current frame and update the button image
        let frame = frames[currentFrameIndex]
        button.image = frame

        // Update tooltip if format provided
        if let format = tooltipFormat {
            let progress = Int(Double(currentFrameIndex + 1) / Double(frames.count) * 100)
            button.toolTip = String(format: format, progress)
        }

        // Advance to next frame, wrapping around to start if needed
        currentFrameIndex = (currentFrameIndex + 1) % frames.count
    }
}
