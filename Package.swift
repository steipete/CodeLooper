// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "CodeLooper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodeLooper-Mac", targets: ["CodeLooper"])
    ],
    dependencies: [
        // Core UI and settings
        .package(url: "https://github.com/sindresorhus/Defaults", .upToNextMajor(from: "9.0.2")),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect.git", from: "1.3.0"),
        // Logging
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.3"),
        // User experience - launch at login
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin", .upToNextMajor(from: "5.0.0")),
        // Accessibility utilities
        .package(path: "AXorcist"),
        // Auto-updater
        .package(url: "https://github.com/sparkle-project/Sparkle.git", .upToNextMajor(from: "2.0.0")),
        // Development-only dependencies
        .package(url: "https://github.com/cpisciotta/xcbeautify", from: "2.28.0")
    ],
    targets: [
        .executableTarget(
            name: "CodeLooper",
            dependencies: [
                "Defaults",
                "LaunchAtLogin",
                .product(name: "SwiftUIIntrospect", package: "SwiftUI-Introspect"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "AXorcistLib", package: "AXorcist"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources",
            resources: [
                .process("Utilities/Resources")
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
                  "-enable-actor-data-race-checks"
                ], .when(configuration: .debug))
            ]
        )
    ]
)