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
        // Add any dependencies AXpector might need. E.g., AXorcist
        // For now, assuming it might need AXorcist, like the main app uses it.
        .package(path: "../AXorcist"), // Corrected and uncommented
        .package(path: "../DesignSystem")
        // If AXpector is fully standalone or uses other things, adjust this.
    ],
    targets: [
        .target(
            name: "AXpector",
            dependencies: [
                .product(name: "AXorcist", package: "AXorcist"), // Uncommented
                .product(name: "DesignSystem", package: "DesignSystem")
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