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
        .package(path: "LocalPackages/KeyboardShortcuts"),
        // Logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.3"),
        // User experience - launch at login
        // Keychain access
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", .upToNextMajor(from: "4.2.2")),
        // Accessibility utilities
        .package(path: "AXorcist"),
        .package(path: "AXpector"),
        // Design System
        .package(path: "DesignSystem"),
        // Markdown conversion
        .package(url: "https://github.com/steipete/Demark", .upToNextMajor(from: "1.0.0")),
        // Auto-updater
        .package(url: "https://github.com/sparkle-project/Sparkle.git", .upToNextMajor(from: "2.7.0")),
        // MenuBarExtra enhancements
        .package(url: "https://github.com/orchetect/MenuBarExtraAccess.git", .upToNextMajor(from: "1.2.1")),
        // AI and image analysis dependencies
        .package(url: "https://github.com/MacPaw/OpenAI", .upToNextMajor(from: "0.4.3")),
        .package(path: "../ollama-swift"),
        // HTTP server
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.5.0"),
        // Development-only dependencies
        .package(url: "https://github.com/cpisciotta/xcbeautify", from: "2.28.0"),
        // Testing
        // Temporarily disabled due to swift-syntax version conflict with Defaults
        // .package(url: "https://github.com/swiftlang/swift-testing", from: "0.12.0"),
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
                .product(name: "Demark", package: "Demark"),
                .product(name: "Hummingbird", package: "hummingbird"),
            ],
            path: ".",
            exclude: [
                "Core/Diagnostics",
                "App/Info.plist",
                "App/Resources/Assets.xcassets",
                "App/Resources/Entitlements",
                "CodeLooper.xcodeproj",
                "CodeLooper.xcworkspace",
                "Project.swift",
                "Tuist",
                "Derived",
                "scripts",
                "docs",
                "assets",
                "Sources",
                "CodeLooper",
                "AXorcist",
                "AXpector",
                "DesignSystem",
                "Tests",
                "LocalPackages",
                "README.md",
                "LICENSE",
                "CHANGELOG.md",
                "CHANGELOG.html",
                "CLAUDE.md",
                "RELEASE.md",
                "appcast.xml",
                "appcast-prerelease.xml",
                "project.yml",
                "Tuist.swift",
                "build.sh",
                "build-and-notarize.sh",
                "clean-and-regenerate.sh",
                "run-swiftformat.sh",
                "run-swiftlint.sh",
                "test-runner.sh",
                "lint.sh",
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
                // .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"]),
                .unsafeFlags([
                    "-warn-concurrency",
                    "-enable-actor-data-race-checks",
                ], .when(configuration: .debug)),
            ]
        ),
    ]
)
