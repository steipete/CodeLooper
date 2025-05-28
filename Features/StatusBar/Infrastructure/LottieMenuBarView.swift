import Defaults
import Diagnostics
import Lottie
import SwiftUI

/// A SwiftUI view that displays a Lottie animation for the menu bar icon
struct LottieMenuBarView: View {
    @Default(.isGlobalMonitoringEnabled) private var isWatchingEnabled
    @State private var animationLoaded = false

    private let animationSpeed: CGFloat = 0.3 // Slow animation
    private let logger = Logger(category: .statusBar)

    var body: some View {
        Group {
            if let animation = loadAnimation() {
                LottieView(animation: animation)
                    .playing(loopMode: isWatchingEnabled ? .loop : .playOnce)
                    .animationSpeed(animationSpeed)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .colorMultiply(menuBarTintColor)
                    .clipped()
                    .onAppear {
                        logger.info("Lottie animation view appeared with size 16x16, watching: \(isWatchingEnabled)")
                        animationLoaded = true
                    }
            } else {
                // Fallback view when Lottie fails to load
                Image(systemName: "link")
                    .renderingMode(.template)
                    .foregroundColor(menuBarTintColor)
                    .frame(width: 16, height: 16)
                    .onAppear {
                        logger.error("Failed to load Lottie animation, using fallback SF Symbol")
                    }
            }
        }
        .onChange(of: isWatchingEnabled) { oldValue, newValue in
            logger.info("Watching state changed from \(oldValue) to \(newValue)")
        }
    }

    private var menuBarTintColor: Color {
        Color.primary
    }

    private func loadAnimation() -> LottieAnimation? {
        logger.info("Attempting to load Lottie animation: chain_link_lottie")

        // Try loading from bundle
        if let animation = LottieAnimation.named("chain_link_lottie") {
            logger.info("Successfully loaded Lottie animation from bundle")
            return animation
        }

        // Try loading from main bundle explicitly
        if let path = Bundle.main.path(forResource: "chain_link_lottie", ofType: "json"),
           let animation = LottieAnimation.filepath(path)
        {
            logger.info("Successfully loaded Lottie animation from explicit path: \(path)")
            return animation
        }

        // Try loading from Resources folder
        if let url = Bundle.main.url(forResource: "chain_link_lottie", withExtension: "json"),
           let animation = LottieAnimation.asset("chain_link_lottie")
        {
            logger.info("Successfully loaded Lottie animation from Resources URL: \(url)")
            return animation
        }

        logger.error("Failed to load Lottie animation from any location")
        logger.error("Bundle paths: \(Bundle.main.bundlePath)")
        logger.error("Resource paths: \(Bundle.main.resourcePath ?? "none")")

        return nil
    }
}

/// NSView wrapper for the Lottie animation to use in NSStatusItem
@MainActor
class LottieMenuBarHostingView: NSView {
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

    private var hostingView: NSHostingView<LottieMenuBarView>?

    private func setupHostingView() {
        let lottieView = LottieMenuBarView()
        let hosting = NSHostingView(rootView: lottieView)
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
