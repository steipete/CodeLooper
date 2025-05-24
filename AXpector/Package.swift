// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AXpector",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AXpector",
            targets: ["AXpector"]
        )
    ],
    dependencies: [
        // Add any dependencies AXpector might have, e.g., AXorcist
        // For now, assuming it might need AXorcist, like the main app uses it.
        // If AXpector is fully standalone or uses other things, adjust this.
        // .package(path: "../AXorcist") // Example if it needs AXorcist
    ],
    targets: [
        .target(
            name: "AXpector",
            dependencies: [
                // .product(name: "AXorcist", package: "AXorcist") // Example
            ],
            path: "Sources/AXpector"
        )
        // If AXpector had tests:
        // .testTarget(
        //     name: "AXpectorTests",
        //     dependencies: ["AXpector"]
        // )
    ]
) 