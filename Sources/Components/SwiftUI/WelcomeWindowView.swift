import AppKit
import Combine
import Diagnostics
import OSLog
import SwiftUI

/**
    Welcome window adapter for the new SwiftUI lifecycle.
    This wrapper helps manage the welcome window using pure SwiftUI APIs.
*/
struct WelcomeWindowView: View {
    private let logger = Logger(category: .onboarding)

    // Services provided by AppDelegate
    private let loginItemManager: LoginItemManager

    // Access the app-wide environment
    @EnvironmentObject private var appEnvironment: AppEnvironment

    // State for the welcome window visibility
    @State private var isShowing = true

    // Store Combine cancellables
    @State private var cancellables = Set<AnyCancellable>()

    // Public initializer
    init(loginItemManager: LoginItemManager) {
        self.loginItemManager = loginItemManager
    }

    var body: some View {
        if isShowing {
            // Re-use the existing WelcomeView but with modern SwiftUI window management
            let viewModel = createViewModel()

            WelcomeView(viewModel: viewModel)
                .onDisappear {
                    isShowing = false
                    // Update the environment when the view disappears
                    appEnvironment.showWelcomeScreen = false
                }
                .frame(
                    width: 700,
                    height: 700
                )
                // Listen for dismiss notifications
                .onReceive(NotificationCenter.default.publisher(for: .dismissWelcomeWindow)) { _ in
                    withAnimation {
                        isShowing = false
                        // Update the environment
                        appEnvironment.showWelcomeScreen = false
                    }
                }
            // Welcome view handles its own state management
        }
    }

    private func createViewModel() -> WelcomeViewModel {
        let viewModel = WelcomeViewModel(
            loginItemManager: loginItemManager,
            windowManager: nil // SwiftUI-based approach doesn't have direct WindowManager access
        ) { [self] in
            logger.info("Welcome flow completed, closing window")

            // Use Task with MainActor to ensure thread safety
            Task { @MainActor in
                isShowing = false

                // Update the app environment
                appEnvironment.showWelcomeScreen = false

                // Post notification to highlight menu bar icon
                NotificationCenter.default.post(
                    name: .highlightMenuBarIcon,
                    object: nil
                )
            }
        }

        // Use SwiftUI's onChange to respond to login state changes
        // This pattern avoids view reloads as it's more efficient
        // than using Combine publishers in the view lifecycle
        return viewModel
    }
}

// Custom SwiftUI scene type for welcome window
struct WelcomeScene: Scene {
    var loginItemManager: LoginItemManager

    // Environment object to pass to the view
    @EnvironmentObject var appEnvironment: AppEnvironment

    var body: some Scene {
        Window("Welcome to CodeLooper", id: "welcome") {
            WelcomeWindowView(
                loginItemManager: loginItemManager
            )
            // Pass the environment to the view
            .environmentObject(appEnvironment)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(SwiftUI.WindowResizability.contentSize)
        .defaultPosition(.center)
    }
}

#Preview {
    // Use mocked services for preview
    WelcomeWindowView(
        loginItemManager: LoginItemManager.shared
    )
    .environmentObject(AppEnvironment())
}
