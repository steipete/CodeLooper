// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "KeyboardShortcuts",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "KeyboardShortcuts",
            targets: [
                "KeyboardShortcuts",
            ]
        ),
    ],
    targets: [
        .target(
            name: "KeyboardShortcuts"
        ),
        .testTarget(
            name: "KeyboardShortcutsTests",
            dependencies: [
                "KeyboardShortcuts",
            ]
        ),
    ]
)
