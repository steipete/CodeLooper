import ProjectDescription

let dependencies = Package.Dependencies(
    swiftPackageManager: SwiftPackageManagerDependencies(
        [
            .remote(url: "https://github.com/sindresorhus/Defaults", requirement: .upToNextMajor(from: "7.3.1")),
            .remote(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", requirement: .upToNextMajor(from: "4.2.2")),
            .remote(url: "https://github.com/sindresorhus/LaunchAtLogin", requirement: .upToNextMajor(from: "5.0.2")),
            .remote(url: "https://github.com/siteline/SwiftUI-Introspect.git", requirement: .upToNextMajor(from: "0.12.0")),
            .remote(url: "https://github.com/apple/swift-log.git", requirement: .upToNextMajor(from: "1.6.3")),
            .remote(url: "https://github.com/sindresorhus/KeyboardShortcuts", requirement: .upToNextMajor(from: "2.0.0")),
        ],
        baseSettings: .settings(
            configurations: [
                .debug(name: "Debug"),
                .release(name: "Release")
            ]
        )
    ),
    platforms: [.macOS]
)