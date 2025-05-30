// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CodeLooper",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "CodeLooper", targets: ["CodeLooper"]),
    ],
    dependencies: [
        // Core UI and settings
        .package(url: "https://github.com/sindresorhus/Defaults", .upToNextMajor(from: "9.0.3")),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "1.3.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", .upToNextMajor(from: "2.3.0")),
        // Logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.3"),
        // User experience - launch at login
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin", .upToNextMajor(from: "5.0.2")),
        // Keychain access
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", .upToNextMajor(from: "4.2.2")),
        // Accessibility utilities
        .package(path: "AXorcist"),
        .package(path: "AXpector"),
        // Design System
        .package(path: "DesignSystem"),
        // Markdown conversion
        .package(path: "/Users/steipete/Projects/Demark"),
        // Auto-updater
        .package(url: "https://github.com/sparkle-project/Sparkle.git", .upToNextMajor(from: "2.7.0")),
        // MenuBarExtra enhancements
        .package(url: "https://github.com/orchetect/MenuBarExtraAccess.git", .upToNextMajor(from: "1.2.1")),
        // AI and image analysis dependencies
        .package(url: "https://github.com/MacPaw/OpenAI", .upToNextMajor(from: "0.4.3")),
        .package(url: "https://github.com/loopwork-ai/ollama-swift", .upToNextMajor(from: "1.4.0")),
        // Animation library
        .package(url: "https://github.com/airbnb/lottie-ios", .upToNextMajor(from: "4.5.2")),
        // Development-only dependencies
        .package(url: "https://github.com/cpisciotta/xcbeautify", from: "2.28.0"),
    ],
    targets: [
        .target(
            name: "Diagnostics",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                "Defaults",
            ],
            path: "Core/Diagnostics"
        ),
        .executableTarget(
            name: "CodeLooper",
            dependencies: [
                "Defaults",
                "LaunchAtLogin",
                "KeyboardShortcuts",
                "KeychainAccess",
                "Diagnostics",
                .product(name: "SwiftUIIntrospect", package: "SwiftUI-Introspect"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AXorcist", package: "AXorcist"),
                .product(name: "AXpector", package: "AXpector"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "DesignSystem", package: "DesignSystem"),
                .product(name: "MenuBarExtraAccess", package: "MenuBarExtraAccess"),
                .product(name: "OpenAI", package: "OpenAI"),
                .product(name: "Ollama", package: "ollama-swift"),
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "Demark", package: "Demark"),
            ],
            path: ".",
            exclude: [
                "Core/Diagnostics",
                "App/Info.plist",
                "App/Resources/Assets.xcassets",
                "App/Resources/Entitlements",
                "App/Resources/Localization",
                "CodeLooper.xcodeproj",
                "CodeLooper.xcworkspace",
                "Project.swift",
                "Tuist",
                "Derived",
                "build",
                "binary",
                "scripts",
                "docs",
                "assets",
                "Resources",
                "Sources",
                "CodeLooper",
                "AXorcist",
                "AXpector",
                "DesignSystem",
                "Tests",
                "TestResults.xcresult",
            ],
            sources: ["App", "Core", "Features"],
            resources: [
                .copy("Resources"),
            ],
            swiftSettings: [
                // Using complete concurrency checking for Swift 6 compatibility.
                // Ensure that all code complies with Swift 6 concurrency rules, including:
                // - Proper use of actors, async/await, and other concurrency primitives.
                // - Avoiding data races and unsynchronized access to shared mutable state.
                // - Updating dependencies to their latest versions for compatibility.
                .unsafeFlags(["-strict-concurrency=complete"]),

                // Extra runtime checking in Debug builds only
                .unsafeFlags([
                    "-warn-concurrency",
                    "-enable-actor-data-race-checks",
                ], .when(configuration: .debug)),
            ]
        ),
        .testTarget(
            name: "CodeLooperTests",
            dependencies: [
                "CodeLooper",
                "Diagnostics",
            ],
            path: "Tests",
            resources: [
                .copy("Resources"),
            ]
        ),
    ]
)
